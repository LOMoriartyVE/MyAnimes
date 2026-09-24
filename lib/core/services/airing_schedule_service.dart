import 'package:flutter/foundation.dart';
import 'hive_service.dart';

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
          latestAiredEpisode = aired;
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
    final int watchDelta = latestAiredEpisode != null ? (episodeProgress - latestAiredEpisode) : 0;

    // Check if anime is finished airing
    final bool isShowFinished = isExplicitlyFinished ||
        (totalEpisodes != null && totalEpisodes > 0 && latestAiredEpisode != null && latestAiredEpisode >= totalEpisodes);

    if (isShowFinished) {
      return AiringCountdownInfo(
        isAiring: false,
        isFinished: true,
        latestAiredEpisode: latestAiredEpisode ?? totalEpisodes,
        watchDelta: watchDelta,
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

    final now = DateTime.now();
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

  /// Converts JST broadcast day & time string to next local DateTime
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

      // Convert from JST back to local DateTime
      final nextUtc = nextJst.subtract(const Duration(hours: 9));
      return nextUtc.toLocal();
    } catch (e) {
      debugPrint("Error parsing broadcast: $e");
      return null;
    }
  }
}
