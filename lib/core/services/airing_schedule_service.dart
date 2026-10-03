import 'package:flutter/foundation.dart';
import '../models/anime_list_item.dart';
import 'hive_service.dart';
import 'jikan_service.dart';

class AiringCountdownInfo {
  final bool isAiring;
  final bool isFinished;
  final bool isAiringToday;
  final int? nextEpisode;
  final int? latestAiredEpisode;
  final int? watchDelta;
  final String? countdownText;
  final DateTime? nextAirTime;
  final Duration? timeRemaining;

  const AiringCountdownInfo({
    required this.isAiring,
    this.isFinished = false,
    this.isAiringToday = false,
    this.nextEpisode,
    this.latestAiredEpisode,
    this.watchDelta,
    this.countdownText,
    this.nextAirTime,
    this.timeRemaining,
  });

  String? get deltaDisplay {
    if (watchDelta == null) return null;
    if (watchDelta! > 0) return '+$watchDelta';
    if (watchDelta == 0) return '0';
    return '$watchDelta';
  }

  static const AiringCountdownInfo none = AiringCountdownInfo(isAiring: false, isFinished: false);
  static const AiringCountdownInfo finished = AiringCountdownInfo(
    isAiring: false,
    isFinished: true,
    countdownText: 'Finished Airing',
  );
}

class AiringScheduleService {
  /// Cache of animeId -> broadcast details { 'day': 'Mondays', 'time': '23:00', 'status': 'Currently Airing', 'episodes': 12, 'aired_from': '...' }
  static final Map<int, Map<String, dynamic>> _broadcastCache = {};
  static final Map<int, int> _lastKnownAiredMap = {};
  static DateTime? _lastCacheBuild;

  /// Force invalidate cache so it re-reads freshly updated metadata
  static void invalidateCache() {
    _lastCacheBuild = null;
    _broadcastCache.clear();
  }

  /// Warm up cache from season and cached anime details
  static void warmUpCache({bool force = false}) {
    final now = DateTime.now();
    if (!force && _lastCacheBuild != null && now.difference(_lastCacheBuild!).inMinutes < 15) {
      return;
    }
    _lastCacheBuild = now;

    try {
      final seasonList = HiveService.getCachedSeasonAllPages();
      if (seasonList != null) {
        for (final item in seasonList) {
          final id = item['mal_id'] as int? ?? 0;
          if (id > 0) {
            _broadcastCache[id] = {
              'day': item['broadcast']?['day']?.toString(),
              'time': item['broadcast']?['time']?.toString(),
              'status': item['status']?.toString(),
              'episodes': item['episodes'],
              'aired_from': item['aired']?['from']?.toString(),
            };
          }
        }
      }
    } catch (_) {}
  }

  static final Map<int, DateTime> _lastAutoCheckTimes = {};
  static bool _isCheckingEpisodes = false;

  /// Automatically fetches updated episode release data from the main API (MAL / Jikan, NOT WitAnime)
  /// every ~2 hours from the last aired time to detect whether an episode has officially released.
  static Future<void> autoCheckAiringEpisodesForList(
    List<AnimeListItem> items, {
    VoidCallback? onUpdate,
  }) async {
    if (_isCheckingEpisodes) return;
    _isCheckingEpisodes = true;

    try {
      final now = nowInTargetTimezone();
      final candidates = <AnimeListItem>[];

      for (final item in items) {
        // Only check watching shows or plan to watch
        if (item.category != AnimeCategory.watching && item.category != AnimeCategory.planned) {
          continue;
        }

        final lastCheck = _lastAutoCheckTimes[item.animeId];
        // Enforce a minimum interval of 2 hours between checks for each anime
        if (lastCheck != null && now.difference(lastCheck).inHours < 2) {
          continue;
        }

        final info = getCountdown(item.animeId, episodeProgress: item.episodeProgress);
        if (info.isAiring) {
          if (info.nextAirTime != null) {
            final lastAirTime = info.nextAirTime!.subtract(const Duration(days: 7));
            final elapsedSinceLastAir = now.difference(lastAirTime);
            // Episode aired at least 2 hours ago
            if (elapsedSinceLastAir >= const Duration(hours: 2)) {
              candidates.add(item);
            }
          } else {
            // Airing show without exact broadcast time, check every ~2 hours
            candidates.add(item);
          }
        }
      }

      if (candidates.isEmpty) return;

      bool anyUpdated = false;
      for (final candidate in candidates) {
        try {
          _lastAutoCheckTimes[candidate.animeId] = DateTime.now();

          // Fetch from MAIN API (MAL / Jikan) - NOT WitAnime
          final animeObj = await JikanService.getAnimeById(candidate.animeId);
          await HiveService.cacheAnimeDetail(candidate.animeId, animeObj.toJson());

          // Update broadcast cache
          _broadcastCache[candidate.animeId] = {
            'day': animeObj.broadcastDay,
            'time': animeObj.broadcastTime,
            'status': animeObj.status,
            'episodes': animeObj.episodes,
            'aired_from': animeObj.airedFrom,
          };

          // Update item metadata if episodes or status changed
          final existing = HiveService.getListItem(candidate.animeId);
          if (existing != null) {
            final shouldUpdateEpisodes = animeObj.episodes != '?' &&
                animeObj.episodes.isNotEmpty &&
                animeObj.episodes != existing.episodes;
            if (shouldUpdateEpisodes || existing.type == null || existing.studios == null) {
              final updated = AnimeListItem(
                animeId: existing.animeId,
                title: existing.title,
                image: existing.image,
                score: existing.score,
                genres: existing.genres,
                category: existing.category,
                addedAt: existing.addedAt,
                userRating: existing.userRating,
                episodes: shouldUpdateEpisodes ? animeObj.episodes : existing.episodes,
                episodeProgress: existing.episodeProgress,
                type: existing.type ?? animeObj.type,
                studios: existing.studios ?? animeObj.studios,
                year: existing.year ?? animeObj.year,
                rank: existing.rank ?? animeObj.rank,
                popularity: existing.popularity ?? animeObj.popularity,
                season: existing.season ?? animeObj.season,
                isMalSynced: existing.isMalSynced,
                personalNotes: existing.personalNotes,
                tags: existing.tags,
              );
              await HiveService.addToList(updated);
            }
          }

          anyUpdated = true;
          onUpdate?.call();
        } catch (e) {
          debugPrint('Error auto-checking anime ${candidate.animeId}: $e');
        }
      }

      if (anyUpdated) {
        onUpdate?.call();
      }
    } finally {
      _isCheckingEpisodes = false;
    }
  }

  /// Calculates next episode broadcast & countdown info for a given anime
  static AiringCountdownInfo getCountdown(int animeId, {int episodeProgress = 0, String? status}) {
    warmUpCache();

    String? broadcastDay;
    String? broadcastTime;
    String? animeStatus = status;
    String? airedFromStr;
    int? totalEpisodes;

    if (_broadcastCache.containsKey(animeId)) {
      final cached = _broadcastCache[animeId]!;
      broadcastDay = cached['day'];
      broadcastTime = cached['time'];
      animeStatus ??= cached['status'];
      totalEpisodes = int.tryParse(cached['episodes']?.toString() ?? '');
      airedFromStr = cached['aired_from'];
    }

    // Fallback: check cached anime detail
    if (broadcastDay == null || broadcastTime == null || airedFromStr == null) {
      final detail = HiveService.getCachedAnimeDetail(animeId);
      if (detail != null) {
        broadcastDay ??= detail['broadcast']?['day']?.toString();
        broadcastTime ??= detail['broadcast']?['time']?.toString();
        animeStatus ??= detail['status']?.toString();
        totalEpisodes ??= int.tryParse(detail['episodes']?.toString() ?? '');
        airedFromStr ??= detail['aired']?['from']?.toString() ?? detail['airedFrom']?.toString();

        _broadcastCache[animeId] = {
          'day': broadcastDay,
          'time': broadcastTime,
          'status': animeStatus,
          'episodes': totalEpisodes,
          'aired_from': airedFromStr,
        };
      }
    }

    final statusLower = animeStatus?.toLowerCase().trim() ?? '';
    final isExplicitlyFinished = statusLower.contains('finished') || statusLower.contains('complete');

    // Calculate how many episodes have officially aired in the world
    int? latestAiredEpisode;
    if (airedFromStr != null) {
      final startDate = DateTime.tryParse(airedFromStr);
      if (startDate != null) {
        final nowUtc = DateTime.now().toUtc();
        final startUtc = startDate.toUtc();
        if (nowUtc.isBefore(startUtc)) {
          latestAiredEpisode = 0;
        } else {
          final days = nowUtc.difference(startUtc).inDays;
          int aired = (days ~/ 7) + 1;
          if (totalEpisodes != null && totalEpisodes > 0 && aired > totalEpisodes) {
            aired = totalEpisodes;
          }
          // If totalEpisodes is null/? and the anime started over 180 days ago,
          // naive days~/7 accumulates enormous false drift (e.g. One Piece produces 1407 due to decades of hiatuses/holidays).
          if ((totalEpisodes == null || totalEpisodes == 0) && days > 180) {
            if (episodeProgress > 0) {
              latestAiredEpisode = episodeProgress;
            } else if (_lastKnownAiredMap.containsKey(animeId)) {
              latestAiredEpisode = _lastKnownAiredMap[animeId];
            } else {
              latestAiredEpisode = null;
            }
          } else {
            latestAiredEpisode = aired;
          }
        }
      }
    }

    // Stable anchor: if airedFrom wasn't available, anchor to the initial observed progress
    if (latestAiredEpisode == null) {
      if (_lastKnownAiredMap.containsKey(animeId)) {
        latestAiredEpisode = _lastKnownAiredMap[animeId];
      } else {
        _lastKnownAiredMap[animeId] = episodeProgress;
        latestAiredEpisode = episodeProgress;
      }
    } else {
      _lastKnownAiredMap[animeId] = latestAiredEpisode;
    }

    // Calculate watch delta (0 = up to date with broadcast, -N = behind, +N = ahead)
    int? watchDelta;
    if (latestAiredEpisode != null) {
      watchDelta = episodeProgress - latestAiredEpisode;
      // If user completed the show (reached totalEpisodes), delta is 0
      if (totalEpisodes != null && totalEpisodes > 0 && episodeProgress >= totalEpisodes) {
        watchDelta = 0;
      }
    }

    // Check if anime is finished airing
    final bool isShowFinished = isExplicitlyFinished ||
        (totalEpisodes != null && totalEpisodes > 0 && latestAiredEpisode != null && latestAiredEpisode >= totalEpisodes);

    if (isShowFinished) {
      final bool userCompleted = (totalEpisodes != null && totalEpisodes > 0 && episodeProgress >= totalEpisodes) ||
          (latestAiredEpisode != null && episodeProgress >= latestAiredEpisode);
      return AiringCountdownInfo(
        isAiring: false,
        isFinished: true,
        latestAiredEpisode: totalEpisodes ?? latestAiredEpisode,
        watchDelta: userCompleted ? 0 : watchDelta,
        countdownText: 'Finished Airing',
      );
    }

    final isCurrentlyAiring = !isExplicitlyFinished &&
        (statusLower.contains('currently airing') || statusLower == 'airing' || (broadcastDay != null && broadcastTime != null));

    if (!isCurrentlyAiring || broadcastDay == null || broadcastTime == null) {
      return isCurrentlyAiring
          ? AiringCountdownInfo(
              isAiring: true,
              latestAiredEpisode: latestAiredEpisode,
              watchDelta: watchDelta,
              countdownText: 'Airing',
            )
          : AiringCountdownInfo.none;
    }

    final nextAirTime = parseJstNextBroadcast(broadcastDay, broadcastTime);
    if (nextAirTime == null) {
      return AiringCountdownInfo(
        isAiring: true,
        latestAiredEpisode: latestAiredEpisode,
        watchDelta: watchDelta,
        countdownText: 'Airing',
      );
    }

    final now = nowInTargetTimezone();
    final remaining = nextAirTime.difference(now);
    final isToday = nextAirTime.year == now.year &&
        nextAirTime.month == now.month &&
        nextAirTime.day == now.day;

    // Next episode airing according to world broadcast (NOT user's progress)
    final nextEpNum = (latestAiredEpisode != null) ? (latestAiredEpisode + 1) : (episodeProgress + 1);
    final epPrefix = totalEpisodes != null && nextEpNum > totalEpisodes
        ? ''
        : 'Ep $nextEpNum';

    String countdownStr;
    if (remaining.inSeconds <= 0) {
      countdownStr = isToday ? '$epPrefix Today' : '$epPrefix Airing Soon';
    } else if (remaining.inMinutes < 60) {
      countdownStr = '$epPrefix in ${remaining.inMinutes}m';
    } else if (remaining.inHours < 24) {
      final m = remaining.inMinutes % 60;
      countdownStr = m > 0 ? '$epPrefix in ${remaining.inHours}h ${m}m' : '$epPrefix in ${remaining.inHours}h';
    } else {
      final days = remaining.inDays;
      final hours = remaining.inHours % 24;
      countdownStr = hours > 0 ? '$epPrefix in ${days}d ${hours}h' : '$epPrefix in ${days}d';
    }

    return AiringCountdownInfo(
      isAiring: true,
      isAiringToday: isToday,
      nextEpisode: nextEpNum,
      latestAiredEpisode: latestAiredEpisode,
      watchDelta: watchDelta,
      countdownText: countdownStr.trim(),
      nextAirTime: nextAirTime,
      timeRemaining: remaining,
    );
  }

  /// Supported global timezones with labels and offsets
  static const Map<String, ({String label, Duration offset})> supportedTimezones = {
    'device': (label: 'Device Time (Auto)', offset: Duration.zero),
    'utc': (label: 'UTC (Coordinated Universal Time)', offset: Duration.zero),
    'jst': (label: 'Tokyo / JST (UTC+9)', offset: Duration(hours: 9)),
    'utc_plus_3': (label: 'Riyadh / Baghdad / AST (UTC+3)', offset: Duration(hours: 3)),
    'utc_plus_2': (label: 'Cairo / Athens / EET (UTC+2)', offset: Duration(hours: 2)),
    'utc_plus_1': (label: 'Berlin / Paris / Rome / CET (UTC+1)', offset: Duration(hours: 1)),
    'gmt': (label: 'London / Dublin / WET (UTC+0)', offset: Duration.zero),
    'utc_plus_4': (label: 'Dubai / GST (UTC+4)', offset: Duration(hours: 4)),
    'utc_plus_5_30': (label: 'India / IST (UTC+5:30)', offset: Duration(hours: 5, minutes: 30)),
    'utc_plus_7': (label: 'Bangkok / Jakarta / ICT (UTC+7)', offset: Duration(hours: 7)),
    'utc_plus_8': (label: 'Singapore / Beijing / SGT (UTC+8)', offset: Duration(hours: 8)),
    'utc_plus_10': (label: 'Sydney / Melbourne / AEST (UTC+10)', offset: Duration(hours: 10)),
    'utc_minus_4': (label: 'Atlantic / Halifax / AST (UTC-4)', offset: Duration(hours: -4)),
    'utc_minus_5': (label: 'New York / Toronto / EST (UTC-5)', offset: Duration(hours: -5)),
    'utc_minus_6': (label: 'Chicago / Mexico City / CST (UTC-6)', offset: Duration(hours: -6)),
    'utc_minus_7': (label: 'Denver / Phoenix / MST (UTC-7)', offset: Duration(hours: -7)),
    'utc_minus_8': (label: 'Los Angeles / Vancouver / PST (UTC-8)', offset: Duration(hours: -8)),
  };

  /// Returns effective timezone offset from user settings
  static Duration getTimezoneOffset() {
    final tz = HiveService.userTimezone;
    if (tz == 'device' || !supportedTimezones.containsKey(tz)) {
      return DateTime.now().timeZoneOffset;
    }
    return supportedTimezones[tz]!.offset;
  }

  /// Returns user-friendly label for current timezone setting
  static String getTimezoneLabel() {
    final tz = HiveService.userTimezone;
    if (tz == 'device' || !supportedTimezones.containsKey(tz)) {
      final offset = DateTime.now().timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final h = offset.inHours.abs().toString().padLeft(2, '0');
      final m = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      return 'Device Time (UTC$sign$h:$m)';
    }
    return supportedTimezones[tz]!.label;
  }

  /// Returns current DateTime anchored to the selected timezone
  static DateTime nowInTargetTimezone() {
    final tz = HiveService.userTimezone;
    if (tz == 'device') {
      return DateTime.now();
    }
    return DateTime.now().toUtc().add(getTimezoneOffset());
  }

  /// Converts a UTC DateTime to target timezone
  static DateTime convertUtcToTargetTimezone(DateTime utc) {
    final tz = HiveService.userTimezone;
    if (tz == 'device') {
      return utc.toLocal();
    }
    return utc.toUtc().add(getTimezoneOffset());
  }

  /// Converts JST broadcast day & time string to next DateTime in target timezone
  static DateTime? parseJstNextBroadcast(String day, String time) {
    try {
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(time);
      if (timeMatch == null) return null;

      int hour = int.parse(timeMatch.group(1)!);
      int minute = int.parse(timeMatch.group(2)!);

      int extraDays = 0;
      if (hour >= 24) {
        hour -= 24;
        extraDays = 1;
      }

      int targetWeekday;
      final lowerDay = day.toLowerCase();
      if (lowerDay.contains('monday')) {
        targetWeekday = DateTime.monday;
      } else if (lowerDay.contains('tuesday')) {
        targetWeekday = DateTime.tuesday;
      } else if (lowerDay.contains('wednesday')) {
        targetWeekday = DateTime.wednesday;
      } else if (lowerDay.contains('thursday')) {
        targetWeekday = DateTime.thursday;
      } else if (lowerDay.contains('friday')) {
        targetWeekday = DateTime.friday;
      } else if (lowerDay.contains('saturday')) {
        targetWeekday = DateTime.saturday;
      } else if (lowerDay.contains('sunday')) {
        targetWeekday = DateTime.sunday;
      } else {
        return null;
      }

      final nowUtc = DateTime.now().toUtc();
      final nowJst = nowUtc.add(const Duration(hours: 9));

      DateTime nextJst = DateTime.utc(nowJst.year, nowJst.month, nowJst.day, hour, minute);
      nextJst = nextJst.add(Duration(days: extraDays));

      while (nextJst.weekday != targetWeekday) {
        nextJst = nextJst.add(const Duration(days: 1));
      }

      // If next broadcast time has already passed today in JST, schedule for next week
      if (nextJst.isBefore(nowJst)) {
        nextJst = nextJst.add(const Duration(days: 7));
      }

      // Convert from JST back to UTC, then translate to user's selected timezone
      final nextUtc = nextJst.subtract(const Duration(hours: 9));
      return convertUtcToTargetTimezone(nextUtc);
    } catch (e) {
      debugPrint("Error parsing broadcast: $e");
      return null;
    }
  }
}
