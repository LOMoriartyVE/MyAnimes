import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/anime_model.dart';
import '../models/anime_list_item.dart';
import 'mal_auth_service.dart';
import 'jikan_service.dart';
import 'airing_schedule_service.dart';

/// Hive-backed local storage service.
/// Manages: anime list, settings, season/detail/manga caches (with TTL).
///
/// IMPORTANT: On MyAnimeList, anime IDs and manga IDs are separate namespaces.
/// The same numeric ID can exist both as an anime AND as a manga — they are
/// stored in distinct boxes to prevent collisions.
class HiveService {
  static const String _listBoxName      = 'anime_list';
  static const String _settingsBoxName  = 'settings';
  static const String _cacheBoxName     = 'cache';
  // Separate detail caches — avoids ID collisions between anime and manga
  static const String _animeDetailBox   = 'anime_detail_cache';
  static const String _mangaDetailBox   = 'manga_detail_cache';
  static const String _downloadsBoxName = 'completed_downloads';

  static late Box<AnimeListItem> _listBox;
  static late Box<dynamic>       _settingsBox;
  static late Box<dynamic>       _cacheBox;
  static late Box<dynamic>       _animeDetailCacheBox;
  static late Box<dynamic>       _mangaDetailCacheBox;
  static late Box<dynamic>       _downloadsBox;

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Initialize Hive and open all boxes.
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(AnimeModelAdapter());
    Hive.registerAdapter(AnimeListItemAdapter());
    Hive.registerAdapter(AnimeCategoryAdapter());
    Hive.registerAdapter(UserRatingAdapter());

    try {
      _listBox             = await Hive.openBox<AnimeListItem>(_listBoxName);
      _settingsBox         = await Hive.openBox(_settingsBoxName);
      _cacheBox            = await Hive.openBox(_cacheBoxName);
      _animeDetailCacheBox = await Hive.openBox(_animeDetailBox);
      _mangaDetailCacheBox = await Hive.openBox(_mangaDetailBox);
      _downloadsBox        = await Hive.openBox(_downloadsBoxName);
    } catch (e) {
      // If schema mismatch during dev, delete boxes and retry
      await Hive.deleteBoxFromDisk(_listBoxName);
      await Hive.deleteBoxFromDisk(_settingsBoxName);
      await Hive.deleteBoxFromDisk(_cacheBoxName);
      await Hive.deleteBoxFromDisk(_animeDetailBox);
      await Hive.deleteBoxFromDisk(_mangaDetailBox);
      await Hive.deleteBoxFromDisk(_downloadsBoxName);
      _listBox             = await Hive.openBox<AnimeListItem>(_listBoxName);
      _settingsBox         = await Hive.openBox(_settingsBoxName);
      _cacheBox            = await Hive.openBox(_cacheBoxName);
      _animeDetailCacheBox = await Hive.openBox(_animeDetailBox);
      _mangaDetailCacheBox = await Hive.openBox(_mangaDetailBox);
      _downloadsBox        = await Hive.openBox(_downloadsBoxName);
    }
    _initialized = true;
  }

  // ── Completed Downloads ──

  static List<Map<String, dynamic>> getCompletedDownloads() {
    return _downloadsBox.values.map((v) => Map<String, dynamic>.from(v)).toList();
  }

  static Future<void> addCompletedDownload(Map<String, dynamic> downloadMap) async {
    await _downloadsBox.put(downloadMap['id'], downloadMap);
  }

  static Future<void> deleteCompletedDownload(String id) async {
    await _downloadsBox.delete(id);
  }

  // ── Anime List ──

  static List<AnimeListItem> getAllListItems() {
    return _listBox.values.toList();
  }

  static List<AnimeListItem> getByCategory(AnimeCategory category) {
    return _listBox.values.where((item) => item.category == category).toList();
  }

  static AnimeListItem? getListItem(int animeId) {
    try {
      return _listBox.values.firstWhere((item) => item.animeId == animeId);
    } catch (_) {
      return null;
    }
  }

  static ValueListenable<Box<AnimeListItem>> get listBoxListenable => _listBox.listenable();
  static ValueListenable<Box<dynamic>> get cacheBoxListenable => _cacheBox.listenable();

  static void Function()? onDataChanged;

  static bool isInList(int animeId) {
    return _listBox.values.any((item) => item.animeId == animeId);
  }

  static Future<void> clearAllListItems() async {
    await _listBox.clear();
    onDataChanged?.call();
  }

  static Future<void> saveListItemDirectly(AnimeListItem item) async {
    await _listBox.put(item.animeId, item);
    onDataChanged?.call();
  }

  static Future<void> addToList(AnimeListItem item) async {
    if (MalAuthService.instance.isLoggedIn) {
      item.isMalSynced = true;
    }
    // Use animeId as key for easy lookup
    await _listBox.put(item.animeId, item);
    onDataChanged?.call();
    _syncListItemToMal(item);
  }

  static Future<void> removeFromList(int animeId) async {
    final item = getListItem(animeId);
    final type = item?.type;
    await _listBox.delete(animeId);
    onDataChanged?.call();
    _deleteFromMal(animeId, type);
  }

  static Future<void> updateCategory(int animeId, AnimeCategory category) async {
    final item = getListItem(animeId);
    if (item != null) {
      item.category = category;
      // Automatically max out episode progress if marking as completed
      if (category == AnimeCategory.completed) {
        int maxEps = int.tryParse(item.episodes) ?? 0;
        if (maxEps > 0) {
          item.episodeProgress = maxEps;
        }
      }
      item.isMalSynced = false;
      await item.save();
      onDataChanged?.call();
      _syncListItemToMal(item);
    }
  }

  static Future<void> updateUserRating(int animeId, UserRating rating) async {
    final item = getListItem(animeId);
    if (item != null) {
      item.userRating = rating;
      item.isMalSynced = false;
      try {
        await item.save();
      } catch (_) {}
      await _listBox.put(item.animeId, item);
      onDataChanged?.call();
      _syncListItemToMal(item);
    }
  }

  static Future<void> updatePersonalNotes(int animeId, String notes) async {
    final item = getListItem(animeId);
    if (item != null) {
      item.personalNotes = notes.trim().isEmpty ? null : notes.trim();
      try {
        await item.save();
      } catch (_) {}
      await _listBox.put(item.animeId, item);
      onDataChanged?.call();
    }
  }

  static Future<void> updateTags(int animeId, List<String> tags) async {
    final item = getListItem(animeId);
    if (item != null) {
      final cleanTags = tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList();
      item.tags = cleanTags.isEmpty ? null : cleanTags;
      try {
        await item.save();
      } catch (_) {}
      await _listBox.put(item.animeId, item);
      onDataChanged?.call();
    }
  }

  static Future<void> updateListItemEpisodes(int animeId, String episodes) async {
    final item = getListItem(animeId);
    if (item != null && item.episodes != episodes && episodes != '?' && episodes.isNotEmpty) {
      item.episodes = episodes;
      try {
        await item.save();
      } catch (_) {}
      await _listBox.put(item.animeId, item);
      onDataChanged?.call();
    }
  }

  static List<String> getAllTags() {
    final tags = <String>{};
    for (final item in _listBox.values) {
      if (item.tags != null) {
        tags.addAll(item.tags!.where((t) => t.trim().isNotEmpty));
      }
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  static const String _episodeLogKey = 'episode_activity_log';

  /// Records episodes watched on a given date (default today).
  static Future<void> logEpisodeActivity(int count, {DateTime? date}) async {
    if (count <= 0) return;
    final d = date ?? DateTime.now();
    final key = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    
    final raw = _settingsBox.get(_episodeLogKey);
    Map<String, dynamic> logs = {};
    if (raw != null) {
      try {
        logs = Map<String, dynamic>.from(json.decode(raw as String));
      } catch (_) {}
    }
    
    final current = (logs[key] as num?)?.toInt() ?? 0;
    logs[key] = current + count;
    await _settingsBox.put(_episodeLogKey, json.encode(logs));
  }

  /// Returns map of "YYYY-MM-DD" -> episodes watched
  static Map<String, int> getEpisodeActivityLogs() {
    final raw = _settingsBox.get(_episodeLogKey);
    if (raw == null) return {};
    try {
      final map = Map<String, dynamic>.from(json.decode(raw as String));
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> updateEpisodeProgress(int animeId, int progress) async {
    final item = getListItem(animeId);
    if (item != null) {
      final delta = progress - item.episodeProgress;
      item.episodeProgress = progress;
      // Do not prematurely set isMalSynced to false if logged in to avoid UI flicker
      if (!MalAuthService.instance.isLoggedIn) {
        item.isMalSynced = false;
      }
      await item.save();
      if (delta > 0) {
        await logEpisodeActivity(delta);
      }
      onDataChanged?.call();
      _syncListItemToMal(item);
    }
  }

  static Future<void> syncFromMal({
    required int animeId,
    required String status,
    required int progress,
    required int score,
    required String title,
    required String image,
    required String episodes,
  }) async {
    AnimeCategory cat = AnimeCategory.planned;
    if (status == 'watching') cat = AnimeCategory.watching;
    if (status == 'completed') cat = AnimeCategory.completed;
    if (status == 'dropped') cat = AnimeCategory.ignored;
    if (status == 'on_hold') cat = AnimeCategory.watching;

    final existing = getListItem(animeId);
    if (existing != null) {
      existing.category = cat;
      existing.episodeProgress = progress;
      if (score > 0) {
        existing.userRating = UserRating(overall: score.toDouble());
      }
      existing.isMalSynced = true;
      await existing.save();
    } else {
      final newItem = AnimeListItem(
        animeId: animeId,
        title: title,
        image: image,
        category: cat,
        episodeProgress: progress,
        episodes: episodes,
        userRating: score > 0 ? UserRating(overall: score.toDouble()) : null,
        isMalSynced: true,
      );
      await _listBox.put(animeId, newItem);
    }
    onDataChanged?.call();
  }

  static bool _isMangaType(String? type) {
    if (type == null) return false;
    final t = type.toUpperCase();
    return t == 'MANGA' || t == 'NOVEL' || t == 'LIGHT_NOVEL' || t == 'LIGHTNOVEL' || t == 'ONESHOT' || t == 'DOUJINSHI' || t == 'MANHWA' || t == 'MANHUA';
  }

  static Future<void> processOfflineQueue() async {
    if (!MalAuthService.instance.isLoggedIn) return;
    final items = _listBox.values.where((item) => item.isMalSynced == false).toList();
    if (items.isEmpty) return;

    final List<Future<void>> syncTasks = items.map((item) async {
      String malStatus = 'plan_to_watch';
      if (item.category == AnimeCategory.watching) {
        malStatus = 'watching';
      } else if (item.category == AnimeCategory.completed) {
        malStatus = 'completed';
      } else if (item.category == AnimeCategory.planned) {
        malStatus = 'plan_to_watch';
      } else if (item.category == AnimeCategory.ignored) {
        malStatus = 'dropped';
      }

      final score = item.userRating?.overall.round();
      final malScore = (score != null && score > 0) ? score : null;

      bool success = false;
      if (_isMangaType(item.type)) {
        success = await MalAuthService.instance.updateMangaProgress(
          item.animeId,
          status: malStatus,
          numChaptersRead: item.episodeProgress,
          score: malScore,
        );
      } else {
        success = await MalAuthService.instance.updateAnimeProgress(
          item.animeId,
          status: malStatus,
          numWatchedEpisodes: item.episodeProgress,
          score: malScore,
        );
      }

      if (success) {
        item.isMalSynced = true;
        await item.save();
      }
    }).toList();

    await Future.wait(syncTasks);
    onDataChanged?.call();
  }

  static void _syncListItemToMal(AnimeListItem item) {
    if (MalAuthService.instance.isLoggedIn) {
      String malStatus = 'plan_to_watch';
      if (item.category == AnimeCategory.watching) {
        malStatus = 'watching';
      } else if (item.category == AnimeCategory.completed) {
        malStatus = 'completed';
      } else if (item.category == AnimeCategory.planned) {
        malStatus = 'plan_to_watch';
      } else if (item.category == AnimeCategory.ignored) {
        malStatus = 'dropped';
      }

      final score = item.userRating?.overall.round();
      final malScore = (score != null && score > 0) ? score : null;

      if (_isMangaType(item.type)) {
        MalAuthService.instance.updateMangaProgress(
          item.animeId,
          status: malStatus,
          numChaptersRead: item.episodeProgress,
          score: malScore,
        ).then((success) {
          if (!success) {
            item.isMalSynced = false;
            item.save();
          } else if (item.isMalSynced != true) {
            item.isMalSynced = true;
            item.save();
          }
        });
      } else {
        MalAuthService.instance.updateAnimeProgress(
          item.animeId,
          status: malStatus,
          numWatchedEpisodes: item.episodeProgress,
          score: malScore,
        ).then((success) {
          if (!success) {
            item.isMalSynced = false;
            item.save();
          } else if (item.isMalSynced != true) {
            item.isMalSynced = true;
            item.save();
          }
        });
      }
    }
  }

  static void _deleteFromMal(int animeId, String? type) {
    if (MalAuthService.instance.isLoggedIn) {
      if (_isMangaType(type)) {
        MalAuthService.instance.deleteMangaFromList(animeId);
      } else {
        MalAuthService.instance.deleteAnimeFromList(animeId);
      }
    }
  }

  // ── Settings ──

  static bool get isDarkMode => _settingsBox.get('darkMode', defaultValue: true) as bool;
  static Future<void> setDarkMode(bool value) => _settingsBox.put('darkMode', value);

  static String get themePack => _settingsBox.get('themePack', defaultValue: 'default_dark') as String;
  static Future<void> setThemePack(String value) async {
    await _settingsBox.put('themePack', value);
    await _settingsBox.put('darkMode', value != 'default_light');
  }

  static String get language => _settingsBox.get('language', defaultValue: 'en') as String;
  static Future<void> setLanguage(String lang) => _settingsBox.put('language', lang);

  static bool get enableNotifications => _settingsBox.get('enableNotif', defaultValue: true) as bool;
  static Future<void> setEnableNotifications(bool value) => _settingsBox.put('enableNotif', value);

  static bool get airingNotifications => _settingsBox.get('airingNotif', defaultValue: true) as bool;
  static Future<void> setAiringNotifications(bool value) => _settingsBox.put('airingNotif', value);

  static bool get newSeasonNotifications => _settingsBox.get('seasonNotif', defaultValue: true) as bool;
  static Future<void> setNewSeasonNotifications(bool value) => _settingsBox.put('seasonNotif', value);

  static String? get localAnimeFolder => _settingsBox.get('localAnimeFolder') as String?;
  static Future<void> setLocalAnimeFolder(String? path) => _settingsBox.put('localAnimeFolder', path);

  static String get witanimeDomain {
    final domain = _settingsBox.get('witanimeDomain', defaultValue: 'witanime.site') as String;
    if (domain == 'witanime.you' || domain.isEmpty) {
      return 'witanime.site';
    }
    return domain;
  }
  static Future<void> setWitanimeDomain(String value) => _settingsBox.put('witanimeDomain', value);

  static String get witmangaDomain => _settingsBox.get('witmangaDomain', defaultValue: 'witmanga.xyz') as String;
  static Future<void> setWitmangaDomain(String value) => _settingsBox.put('witmangaDomain', value);

  static String? get malAccessToken => _settingsBox.get('malAccessToken') as String?;
  static Future<void> setMalAccessToken(String? token) => _settingsBox.put('malAccessToken', token);

  static String? get malRefreshToken => _settingsBox.get('malRefreshToken') as String?;
  static Future<void> setMalRefreshToken(String? token) => _settingsBox.put('malRefreshToken', token);

  static int? get malTokenExpiry => _settingsBox.get('malTokenExpiry') as int?;
  static Future<void> setMalTokenExpiry(int? expiry) => _settingsBox.put('malTokenExpiry', expiry);

  static String? get malUsername => _settingsBox.get('malUsername') as String?;
  static Future<void> setMalUsername(String? username) => _settingsBox.put('malUsername', username);

  static bool hasAlertEnabled(int animeId) => _settingsBox.get('alert_$animeId', defaultValue: false) as bool;
  static Future<void> setAlertEnabled(int animeId, bool enabled) => _settingsBox.put('alert_$animeId', enabled);

  static String get cacheMode => _settingsBox.get('cacheMode', defaultValue: 'default') as String;
  static Future<void> setCacheMode(String value) => _settingsBox.put('cacheMode', value);

  static int get customCacheDurationHours => _settingsBox.get('customCacheDurationHours', defaultValue: 2) as int;
  static Future<void> setCustomCacheDurationHours(int hours) => _settingsBox.put('customCacheDurationHours', hours);

  static String getLastVersionShown() => _settingsBox.get('lastVersionShown', defaultValue: '') as String;
  static Future<void> setLastVersionShown(String version) => _settingsBox.put('lastVersionShown', version);

  /// Fast lookup of all known anime/manga release years across all local Hive caches
  static Map<int, int> getAllCachedAnimeYears() {
    final Map<int, int> result = {};
    int? extract(dynamic v) {
      if (v == null) return null;
      final m = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(v.toString());
      return m != null ? int.tryParse(m.group(1)!) : null;
    }

    // 1. Scan anime detail cache box
    for (final key in _animeDetailCacheBox.keys) {
      if (key is String && key.startsWith('anime_') && key.endsWith('_data')) {
        try {
          final idStr = key.replaceFirst('anime_', '').replaceFirst('_data', '');
          final id = int.tryParse(idStr);
          if (id != null) {
            final raw = _animeDetailCacheBox.get(key);
            if (raw is String) {
              final data = json.decode(raw);
              if (data is Map) {
                final y = extract(data['year']) ??
                          extract(data['aired']?['prop']?['from']?['year']) ??
                          extract(data['aired']?['from']) ??
                          extract(data['aired']?['string']) ??
                          extract(data['season']);
                if (y != null) result[id] = y;
              }
            }
          }
        } catch (_) {}
      }
    }

    // 2. Scan manga detail cache box
    for (final key in _mangaDetailCacheBox.keys) {
      if (key is String && key.startsWith('manga_') && key.endsWith('_data')) {
        try {
          final idStr = key.replaceFirst('manga_', '').replaceFirst('_data', '');
          final id = int.tryParse(idStr);
          if (id != null) {
            final raw = _mangaDetailCacheBox.get(key);
            if (raw is String) {
              final data = json.decode(raw);
              if (data is Map) {
                final y = extract(data['published']?['prop']?['from']?['year']) ??
                          extract(data['published']?['from']) ??
                          extract(data['published']?['string']);
                if (y != null) result[id] = y;
              }
            }
          }
        } catch (_) {}
      }
    }

    // 3. Scan general cache box (top anime, upcoming, seasons, recommendations)
    for (final key in _cacheBox.keys) {
      if (key is String && key.endsWith('_data')) {
        try {
          final raw = _cacheBox.get(key);
          if (raw is String) {
            final decoded = json.decode(raw);
            if (decoded is List) {
              for (final item in decoded) {
                if (item is Map) {
                  final id = item['mal_id'] ?? item['id'];
                  if (id is int && !result.containsKey(id)) {
                    final y = extract(item['year']) ??
                              extract(item['aired']?['prop']?['from']?['year']) ??
                              extract(item['aired']?['from']) ??
                              extract(item['aired']?['string']) ??
                              extract(item['season']) ??
                              extract(item['published']?['prop']?['from']?['year']);
                    if (y != null) result[id] = y;
                  }
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    return result;
  }

  /// Syncs / backfills metadata (year, studios, type) from MAL for all items in the user's list
  static Future<int> backfillMetadataFromMal() async {
    if (!MalAuthService.instance.isLoggedIn) return 0;
    try {
      final malList = await MalAuthService.instance.getUserAnimeList();
      if (malList.isEmpty) return 0;

      int updatedCount = 0;
      for (final item in malList) {
        final node = item['node'] as Map<String, dynamic>?;
        if (node == null) continue;
        final id = node['id'] as int? ?? 0;
        if (id == 0) continue;

        final existing = getListItem(id);
        if (existing != null) {
          String? yearStr = node['start_season']?['year']?.toString();
          if (yearStr == null || yearStr.isEmpty) {
            final startDate = node['start_date']?.toString();
            if (startDate != null) {
              final m = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(startDate);
              if (m != null) yearStr = m.group(1);
            }
          }

          List<String>? studios;
          if (node['studios'] is List) {
            final list = (node['studios'] as List)
                .map((s) => s['name']?.toString() ?? '')
                .where((s) => s.isNotEmpty && s.toLowerCase() != 'unknown' && s.toLowerCase() != 'unknown studio')
                .toList();
            if (list.isNotEmpty) studios = list;
          }

          final mediaType = node['media_type']?.toString().toUpperCase();

          final numEp = node['num_episodes'] as int? ?? 0;
          String updatedEpisodes = existing.episodes;
          bool needUpdate = false;

          if (numEp > 0 && (existing.episodes == '?' || existing.episodes == '0' || existing.episodes.isEmpty)) {
            updatedEpisodes = numEp.toString();
            needUpdate = true;
          }

          if (yearStr != null && (existing.year == null || existing.year == 'Unknown' || existing.year!.isEmpty)) {
            needUpdate = true;
          }
          if (studios != null && studios.isNotEmpty && (existing.studios == null || existing.studios!.isEmpty)) {
            needUpdate = true;
          }
          if (mediaType != null && (existing.type == null || existing.type == 'Unknown' || existing.type!.isEmpty)) {
            needUpdate = true;
          }

          // Warm/update anime detail cache so AiringScheduleService immediately has status, episodes, broadcast & air dates
          final rawStatus = node['status']?.toString();
          String? formattedStatus;
          if (rawStatus != null) {
            if (rawStatus == 'finished_airing') {
              formattedStatus = 'Finished Airing';
            } else if (rawStatus == 'currently_airing') {
              formattedStatus = 'Currently Airing';
            } else if (rawStatus == 'not_yet_aired') {
              formattedStatus = 'Not yet aired';
            } else {
              formattedStatus = rawStatus;
            }
          }
          final startDate = node['start_date']?.toString();
          final broadcast = node['broadcast'] as Map<String, dynamic>?;

          var cachedDetail = getCachedAnimeDetail(id);
          if (cachedDetail == null) {
            cachedDetail = {
              'mal_id': id,
              'title': existing.title,
              'episodes': numEp > 0 ? numEp : (updatedEpisodes != '?' ? int.tryParse(updatedEpisodes) : null),
              'status': formattedStatus,
              'aired': {'from': startDate},
              'broadcast': broadcast != null ? {
                'day': broadcast['day_of_the_week'],
                'time': broadcast['start_time'],
              } : null,
            };
            await cacheAnimeDetail(id, cachedDetail);
          } else {
            bool detailChanged = false;
            if (numEp > 0 && (cachedDetail['episodes'] == null || cachedDetail['episodes'] == 0 || cachedDetail['episodes'] == '?')) {
              cachedDetail['episodes'] = numEp;
              detailChanged = true;
            }
            if (formattedStatus != null && cachedDetail['status'] != formattedStatus) {
              cachedDetail['status'] = formattedStatus;
              detailChanged = true;
            }
            if (startDate != null && (cachedDetail['aired'] == null || cachedDetail['aired']['from'] == null)) {
              cachedDetail['aired'] = {'from': startDate};
              detailChanged = true;
            }
            if (broadcast != null && cachedDetail['broadcast'] == null) {
              cachedDetail['broadcast'] = {
                'day': broadcast['day_of_the_week'],
                'time': broadcast['start_time'],
              };
              detailChanged = true;
            }
            if (detailChanged) {
              await cacheAnimeDetail(id, cachedDetail);
            }
          }

          if (needUpdate) {
            final updatedItem = AnimeListItem(
              animeId: existing.animeId,
              title: existing.title,
              image: existing.image,
              score: existing.score ?? (node['mean'] as num?)?.toDouble(),
              genres: existing.genres.isNotEmpty
                  ? existing.genres
                  : ((node['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? []),
              category: existing.category,
              addedAt: existing.addedAt,
              userRating: existing.userRating,
              episodes: updatedEpisodes,
              episodeProgress: existing.episodeProgress,
              type: mediaType ?? existing.type,
              studios: (studios != null && studios.isNotEmpty) ? studios : existing.studios,
              year: yearStr ?? existing.year,
              rank: existing.rank,
              popularity: existing.popularity,
              season: existing.season ?? node['start_season']?['season']?.toString(),
              isMalSynced: existing.isMalSynced,
            );
            await _listBox.put(id, updatedItem);
            updatedCount++;
          }
        }
      }
      return updatedCount;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> healListItemsMetadata({bool forceNetwork = false}) async {
    await backfillMetadataFromMal();
    final items = getAllListItems();
    final cachedYears = getAllCachedAnimeYears();
    final itemsNeedingNetwork = <AnimeListItem>[];

    for (var item in items) {
      bool needSave = false;
      String? updatedYear = item.year;
      List<String>? updatedStudios = item.studios;
      String? updatedType = item.type;
      String? updatedEpisodes = item.episodes;
      
      if (item.year == null || item.year == 'Unknown' || item.year!.isEmpty) {
        if (cachedYears.containsKey(item.animeId)) {
          updatedYear = cachedYears[item.animeId].toString();
          needSave = true;
        } else {
          // Try season string
          if (item.season != null) {
            final m = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(item.season!);
            if (m != null) {
              updatedYear = m.group(1);
              needSave = true;
            }
          }
          // Try title string
          if (updatedYear == null || updatedYear == 'Unknown') {
            final m = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(item.title);
            if (m != null) {
              updatedYear = m.group(1);
              needSave = true;
            }
          }
        }
      }

      final needsDetailCheck = item.type == null ||
          item.studios == null ||
          updatedYear == null ||
          updatedYear == 'Unknown' ||
          item.episodes == '?' ||
          item.episodes.isEmpty ||
          item.episodes == '0';

      if (needsDetailCheck) {
        var cached = getCachedAnimeDetail(item.animeId);
        if (cached == null) {
          cached = getCachedMangaDetail(item.animeId);
        }
        if (cached != null) {
          try {
            final anime = AnimeModel.fromJson(cached);
            updatedType ??= anime.type;
            if (updatedStudios == null || updatedStudios.isEmpty) {
              final valid = anime.studios.where((s) {
                final t = s.trim().toLowerCase();
                return t.isNotEmpty && t != 'unknown' && t != 'unknown studio' && t != 'none' && t != 'n/a';
              }).toList();
              if (valid.isNotEmpty) {
                updatedStudios = valid;
                needSave = true;
              }
            }
            if (updatedYear == null || updatedYear == 'Unknown' || updatedYear.isEmpty) {
              if (anime.year != 'Unknown' && anime.year.isNotEmpty) {
                updatedYear = anime.year;
                needSave = true;
              }
            }
            if (item.episodes == '?' || item.episodes.isEmpty || item.episodes == '0') {
              if (anime.episodes != '?' && anime.episodes != '0' && anime.episodes.isNotEmpty) {
                updatedEpisodes = anime.episodes;
                needSave = true;
              }
            }
          } catch (_) {}
        }

        // Fallback: check season all pages cache for confirmed episode count
        if (updatedEpisodes == null || updatedEpisodes.isEmpty || updatedEpisodes == '?' || updatedEpisodes == '0') {
          final seasonCache = getCachedSeasonAllPages();
          if (seasonCache != null) {
            for (final s in seasonCache) {
              if (s['mal_id'] == item.animeId) {
                final ep = s['episodes']?.toString();
                if (ep != null && ep != '?' && ep != '0' && ep.isNotEmpty) {
                  updatedEpisodes = ep;
                  needSave = true;
                }
                break;
              }
            }
          }
        }

        // If STILL unknown or missing cached detail, queue for network fetch
        if (updatedEpisodes == null || updatedEpisodes.isEmpty || updatedEpisodes == '?' || updatedEpisodes == '0' || cached == null) {
          itemsNeedingNetwork.add(item);
        }
      }

      if (needSave) {
        final newItem = AnimeListItem(
          animeId: item.animeId,
          title: item.title,
          image: item.image,
          score: item.score,
          genres: item.genres,
          category: item.category,
          addedAt: item.addedAt,
          userRating: item.userRating,
          episodes: updatedEpisodes ?? item.episodes,
          episodeProgress: item.episodeProgress,
          type: updatedType ?? item.type,
          studios: updatedStudios ?? item.studios,
          year: updatedYear ?? item.year,
          rank: item.rank,
          popularity: item.popularity,
          season: item.season,
          isMalSynced: item.isMalSynced,
          personalNotes: item.personalNotes,
          tags: item.tags,
        );
        await _listBox.put(item.animeId, newItem);
      }
    }

    // Resolve missing details via Jikan in the background for priority items
    if (itemsNeedingNetwork.isNotEmpty) {
      final queue = itemsNeedingNetwork
        ..sort((a, b) {
          int priority(AnimeListItem i) => i.category == AnimeCategory.watching ? 0 : (i.category == AnimeCategory.planned ? 1 : 2);
          return priority(a).compareTo(priority(b));
        });

      final toFetch = queue.take(forceNetwork ? 8 : 4).toList();
      for (final item in toFetch) {
        try {
          final animeObj = await JikanService.getAnimeById(item.animeId);
          await cacheAnimeDetail(item.animeId, {
            'mal_id': animeObj.id,
            'title': animeObj.title,
            'episodes': animeObj.episodes != '?' ? animeObj.episodes : null,
            'status': animeObj.status,
            'aired': {'from': animeObj.airedFrom, 'to': animeObj.airedTo},
            'broadcast': {'day': animeObj.broadcastDay, 'time': animeObj.broadcastTime},
            'studios': animeObj.studios.map((s) => {'name': s}).toList(),
            'type': animeObj.type,
            'year': animeObj.year,
          });

          final epStr = animeObj.episodes;
          final validEp = epStr != '?' && epStr != '0' && epStr.isNotEmpty;
          final current = getListItem(item.animeId) ?? item;
          final updated = AnimeListItem(
            animeId: current.animeId,
            title: current.title,
            image: current.image,
            score: current.score ?? animeObj.score,
            genres: current.genres.isNotEmpty ? current.genres : animeObj.genres,
            category: current.category,
            addedAt: current.addedAt,
            userRating: current.userRating,
            episodes: validEp ? epStr : current.episodes,
            episodeProgress: current.episodeProgress,
            type: current.type ?? animeObj.type,
            studios: (current.studios != null && current.studios!.isNotEmpty) ? current.studios : animeObj.studios,
            year: (current.year != null && current.year != 'Unknown' && current.year!.isNotEmpty) ? current.year : animeObj.year,
            rank: current.rank,
            popularity: current.popularity,
            season: current.season,
            isMalSynced: current.isMalSynced,
            personalNotes: current.personalNotes,
            tags: current.tags,
          );
          await _listBox.put(item.animeId, updated);
          await Future.delayed(const Duration(milliseconds: 350));
        } catch (_) {}
      }
      AiringScheduleService.invalidateCache();
      AiringScheduleService.warmUpCache(force: true);
    }
  }

  static String? getWindowsDriveAccessToken() => _settingsBox.get('winAccessToken') as String?;
  static String? getWindowsDriveRefreshToken() => _settingsBox.get('winRefreshToken') as String?;
  static int? getWindowsDriveExpiry() => _settingsBox.get('winTokenExpiry') as int?;
  static String? getWindowsDriveEmail() => _settingsBox.get('winUserEmail') as String?;

  static Future<void> setWindowsDriveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiry,
    required String email,
  }) async {
    await _settingsBox.put('winAccessToken', accessToken);
    await _settingsBox.put('winRefreshToken', refreshToken);
    await _settingsBox.put('winTokenExpiry', expiry);
    await _settingsBox.put('winUserEmail', email);
  }

  static Future<void> clearWindowsDriveTokens() async {
    await _settingsBox.delete('winAccessToken');
    await _settingsBox.delete('winRefreshToken');
    await _settingsBox.delete('winTokenExpiry');
    await _settingsBox.delete('winUserEmail');
  }

  // ── Generic TTL Cache Helpers ──

  static Future<void> _putCache(String key, dynamic data, {Duration ttl = const Duration(hours: 24)}) async {
    await _cacheBox.put('${key}_data', json.encode(data));
    await _cacheBox.put('${key}_ts', DateTime.now().millisecondsSinceEpoch);
    await _cacheBox.put('${key}_ttl', ttl.inMilliseconds);
  }

  static bool _isCacheValid(String key) {
    final ts  = _cacheBox.get('${key}_ts');
    if (ts == null) return false;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts as int);
    
    final mode = cacheMode;
    if (mode == 'never') return true;

    final duration = mode == 'default'
        ? const Duration(hours: 2)
        : Duration(hours: customCacheDurationHours);

    return DateTime.now().difference(cachedAt).inMilliseconds < duration.inMilliseconds;
  }

  static List<Map<String, dynamic>>? _getListCache(String key, {bool allowExpired = true}) {
    if (!allowExpired && !_isCacheValid(key)) return null;
    final raw = _cacheBox.get('${key}_data');
    if (raw == null) return null;
    try {
      final list = json.decode(raw as String) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  // ── Season Cache (all pages, expires when season changes) ──

  static String _currentSeasonKey() {
    final now = DateTime.now();
    final month = now.month;
    String season;
    if (month >= 1 && month <= 3) {
      season = 'winter';
    } else if (month >= 4 && month <= 6) {
      season = 'spring';
    } else if (month >= 7 && month <= 9) {
      season = 'summer';
    } else {
      season = 'fall';
    }
    return '${now.year}_$season';
  }

  static String get currentSeasonKey => _currentSeasonKey();

  /// Cache all-pages season data. TTL = until next season boundary (up to ~3 months).
  static Future<void> cacheSeasonAllPages(List<Map<String, dynamic>> data) async {
    final key = 'season_all_${_currentSeasonKey()}';
    await _putCache(key, data, ttl: const Duration(days: 7));
  }

  static List<Map<String, dynamic>>? getCachedSeasonAllPages({bool allowExpired = true}) {
    final key = 'season_all_${_currentSeasonKey()}';
    return _getListCache(key, allowExpired: allowExpired);
  }

  static bool hasAnySeasonCache() {
    final key = 'season_all_${_currentSeasonKey()}';
    return _cacheBox.containsKey('${key}_ts');
  }

  static List<Map<String, dynamic>>? getSeasonCacheIgnoringTtl() {
    final key = 'season_all_${_currentSeasonKey()}';
    final raw = _cacheBox.get('${key}_data');
    if (raw == null) return null;
    try {
      final list = json.decode(raw as String) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  static bool isSeasonAllPagesCacheValid() {
    return _isCacheValid('season_all_${_currentSeasonKey()}');
  }

  // ── Season single-page cache ──

  static Future<void> cacheSeasonData(String key, List<Map<String, dynamic>> data) async {
    await _putCache('season_$key', data, ttl: const Duration(hours: 24));
  }

  static List<Map<String, dynamic>>? getCachedSeasonData(String key, {bool allowExpired = true}) {
    return _getListCache('season_$key', allowExpired: allowExpired);
  }

  static bool isSeasonCacheValid() {
    return _isCacheValid('season_${_currentSeasonKey()}');
  }

  // ── Genres ──

  static Future<void> cacheGenres(List<Map<String, dynamic>> data) async {
    await _putCache('genres', data, ttl: const Duration(days: 30));
  }

  static List<Map<String, dynamic>>? getCachedGenres({bool allowExpired = true}) {
    return _getListCache('genres', allowExpired: allowExpired);
  }

  // ── Top Anime (TTL: 4 hours) ──

  static Future<void> cacheTopAnime(List<Map<String, dynamic>> data) async {
    await _putCache('top_anime', data, ttl: const Duration(hours: 4));
  }

  static List<Map<String, dynamic>>? getCachedTopAnime({bool allowExpired = true}) {
    return _getListCache('top_anime', allowExpired: allowExpired);
  }

  static bool isTopAnimeCacheValid() => _isCacheValid('top_anime');

  // Legacy methods
  static Future<void> cacheTopData(List<Map<String, dynamic>> data) => cacheTopAnime(data);
  static List<Map<String, dynamic>>? getCachedTopData({bool allowExpired = true}) => getCachedTopAnime(allowExpired: allowExpired);
  static bool isTopCacheValid() => isTopAnimeCacheValid();

  // ── Top Manga (TTL: 4 hours) ──

  static Future<void> cacheTopManga(List<Map<String, dynamic>> data) async {
    await _putCache('top_manga', data, ttl: const Duration(hours: 4));
  }

  static List<Map<String, dynamic>>? getCachedTopManga({bool allowExpired = true}) {
    return _getListCache('top_manga', allowExpired: allowExpired);
  }

  static bool isTopMangaCacheValid() => _isCacheValid('top_manga');

  // ── Top Reviews (TTL: 6 hours) ──

  static Future<void> cacheTopReviews(List<Map<String, dynamic>> data) async {
    await _putCache('top_reviews', data, ttl: const Duration(hours: 6));
  }

  static List<Map<String, dynamic>>? getCachedTopReviews({bool allowExpired = true}) {
    return _getListCache('top_reviews', allowExpired: allowExpired);
  }

  static bool isTopReviewsCacheValid() => _isCacheValid('top_reviews');

  // ── Upcoming Anime (TTL: 4 hours) ──

  static Future<void> cacheUpcoming(List<Map<String, dynamic>> data) async {
    await _putCache('upcoming_anime', data, ttl: const Duration(hours: 4));
  }

  static List<Map<String, dynamic>>? getCachedUpcoming({bool allowExpired = true}) {
    return _getListCache('upcoming_anime', allowExpired: allowExpired);
  }

  static bool isUpcomingCacheValid() => _isCacheValid('upcoming_anime');

  // ── Recommended Anime ──

  static Future<void> cacheRecommended(List<Map<String, dynamic>> data) async {
    await _putCache('recommended_anime', data, ttl: const Duration(hours: 12));
  }

  static List<Map<String, dynamic>>? getCachedRecommended({bool allowExpired = true}) {
    return _getListCache('recommended_anime', allowExpired: allowExpired);
  }

  // ── User Suggestions ──

  static Future<void> cacheUserSuggestions(List<Map<String, dynamic>> data) async {
    await _putCache('user_suggestions', data, ttl: const Duration(hours: 12));
  }

  static List<Map<String, dynamic>>? getCachedUserSuggestions({bool allowExpired = true}) {
    return _getListCache('user_suggestions', allowExpired: allowExpired);
  }

  // ── Extra Anime Details (Cast/Characters, Statistics, Reviews, News, Recommendations) ──

  static Future<void> cacheAnimeExtraDetails(int animeId, String section, dynamic data) async {
    final key = 'extra_${animeId}_$section';
    await _animeDetailCacheBox.put('${key}_data', json.encode(data));
    await _animeDetailCacheBox.put('${key}_ts', DateTime.now().millisecondsSinceEpoch);
  }

  static dynamic getCachedAnimeExtraDetails(int animeId, String section) {
    final raw = _animeDetailCacheBox.get('extra_${animeId}_${section}_data');
    if (raw == null) return null;
    try {
      return json.decode(raw as String);
    } catch (_) {
      return null;
    }
  }

  // ── Anime Detail Cache (TTL: 12 hours per anime) ──

  static Future<void> cacheAnimeDetail(int animeId, Map<String, dynamic> data) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ttl = const Duration(hours: 12).inMilliseconds;
    await _animeDetailCacheBox.put('anime_${animeId}_data', json.encode(data));
    await _animeDetailCacheBox.put('anime_${animeId}_ts', now);
    await _animeDetailCacheBox.put('anime_${animeId}_ttl', ttl);
  }

  static Map<String, dynamic>? getCachedAnimeDetail(int animeId, {bool allowExpired = true}) {
    final ts  = _animeDetailCacheBox.get('anime_${animeId}_ts');
    if (ts == null) return null;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts as int);

    if (!allowExpired) {
      final mode = cacheMode;
      if (mode != 'never') {
        final duration = mode == 'default'
            ? const Duration(hours: 2)
            : Duration(hours: customCacheDurationHours);
        if (DateTime.now().difference(cachedAt).inMilliseconds >= duration.inMilliseconds) {
          return null;
        }
      }
    }

    final raw = _animeDetailCacheBox.get('anime_${animeId}_data');
    if (raw == null) return null;
    try {
      return json.decode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Manga Detail Cache (TTL: 12 hours per manga — SEPARATE from anime!) ──

  static Future<void> cacheMangaDetail(int mangaId, Map<String, dynamic> data) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ttl = const Duration(hours: 12).inMilliseconds;
    await _mangaDetailCacheBox.put('manga_${mangaId}_data', json.encode(data));
    await _mangaDetailCacheBox.put('manga_${mangaId}_ts', now);
    await _mangaDetailCacheBox.put('manga_${mangaId}_ttl', ttl);
  }

  static Map<String, dynamic>? getCachedMangaDetail(int mangaId) {
    final ts  = _mangaDetailCacheBox.get('manga_${mangaId}_ts');
    if (ts == null) return null;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts as int);

    final mode = cacheMode;
    if (mode != 'never') {
      final duration = mode == 'default'
          ? const Duration(hours: 2)
          : Duration(hours: customCacheDurationHours);
      if (DateTime.now().difference(cachedAt).inMilliseconds >= duration.inMilliseconds) {
        return null;
      }
    }

    final raw = _mangaDetailCacheBox.get('manga_${mangaId}_data');
    if (raw == null) return null;
    try {
      return json.decode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Data Import / Export ──

  static String _categoryToString(AnimeCategory c) {
    switch (c) {
      case AnimeCategory.completed: return 'full';
      case AnimeCategory.watching: return 'watching';
      case AnimeCategory.planned: return 'planned';
      case AnimeCategory.ignored: return 'ignored';
    }
  }

  static AnimeCategory _categoryFromString(String s) {
    switch (s.toLowerCase()) {
      case 'full': return AnimeCategory.completed;
      case 'watching': return AnimeCategory.watching;
      case 'ignored': return AnimeCategory.ignored;
      default: return AnimeCategory.planned;
    }
  }

  static Future<String> exportAsJson() async {
    final items = getAllListItems();
    final list = items.map((item) {
      return {
        "name": item.title,
        "myrate": item.userRating?.overall ?? 0.0,
        "watched": _categoryToString(item.category),
        "mal_id": item.animeId,
        "episode_progress": item.episodeProgress,
        "user_rating_details": item.userRating == null ? null : {
          "overall": item.userRating!.overall,
          "story": item.userRating!.story,
          "character": item.userRating!.character,
          "draw": item.userRating!.draw,
          "animation": item.userRating!.animation,
          "music": item.userRating!.music,
          "notes": item.userRating!.notes,
        },
        "content": {
          "data": {
            "mal_id": item.animeId,
            "title_english": item.title,
            "images": {
              "jpg": {
                "large_image_url": item.image
              }
            },
            "score": item.score,
            "genres": item.genres.map((g) => {"name": g}).toList(),
            "episodes": int.tryParse(item.episodes) ?? 0,
          }
        }
      };
    }).toList();
    return json.encode(list);
  }

  static Future<void> importFromJson(String rawJson) async {
    final originalCallback = onDataChanged;
    onDataChanged = null;

    try {
      await _listBox.clear();
      final List<dynamic> list = json.decode(rawJson);
      debugPrint('importFromJson: Found ${list.length} items to import');
      for (final element in list) {
        final map = element as Map<String, dynamic>;
        final rate = map['myrate'] != null ? (map['myrate'] as num).toDouble() : 0.0;
        final watched = map['watched'] as String? ?? 'planned';
        final category = _categoryFromString(watched);

        final contentData = map['content']?['data'];
        if (contentData == null) continue;
        
        final animeModel = AnimeModel.fromJson(contentData as Map<String, dynamic>);
        final item = AnimeListItem.fromAnime(animeModel, category);
        
        // Load episode progress if present
        if (map.containsKey('episode_progress')) {
          item.episodeProgress = map['episode_progress'] as int;
        }
        
        // Load user rating details
        if (map.containsKey('user_rating_details') && map['user_rating_details'] != null) {
          final ratingMap = map['user_rating_details'] as Map<String, dynamic>;
          item.userRating = UserRating(
            overall: (ratingMap['overall'] as num?)?.toDouble() ?? 0.0,
            story: (ratingMap['story'] as num?)?.toDouble() ?? 0.0,
            character: (ratingMap['character'] as num?)?.toDouble() ?? 0.0,
            draw: (ratingMap['draw'] as num?)?.toDouble() ?? 0.0,
            animation: (ratingMap['animation'] as num?)?.toDouble() ?? 0.0,
            music: (ratingMap['music'] as num?)?.toDouble() ?? 0.0,
            notes: ratingMap['notes'] as String? ?? '',
          );
        } else if (rate > 0) {
          item.userRating = UserRating(overall: rate);
        }
        
        await _listBox.put(item.animeId, item);
      }
    } finally {
      onDataChanged = originalCallback;
    }
  }

  // ── Notifications Data Store ──

  static List<Map<String, dynamic>> getNotifications() {
    final raw = _settingsBox.get('notifications');
    if (raw == null) {
      return [
        {
          'id': '1',
          'title': "Frieren: Beyond Journey's End",
          'body': 'Episode 28 is now airing! Watch it now.',
          'type': 'airing',
          'animeId': 52991,
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
          'read': false,
        },
        {
          'id': '2',
          'title': 'New Season Alert',
          'body': 'Summer 2026 Season has officially started. Discover new anime!',
          'type': 'season',
          'timestamp': DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
          'read': false,
        },
        {
          'id': '3',
          'title': 'MAL Sync Completed',
          'body': 'Successfully synchronized your lists with MyAnimeList.',
          'type': 'sync',
          'timestamp': DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch,
          'read': true,
        }
      ];
    }
    try {
      final list = json.decode(raw as String) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveNotifications(List<Map<String, dynamic>> list) async {
    await _settingsBox.put('notifications', json.encode(list));
  }

  // ── MAL User Picture ──

  static String? get malUserPicture => _settingsBox.get('malUserPicture') as String?;
  static Future<void> setMalUserPicture(String? url) => _settingsBox.put('malUserPicture', url);

  // ── MAL Multi-Accounts ──

  static List<Map<String, dynamic>> getMalAccounts() {
    final raw = _settingsBox.get('malAccounts');
    if (raw == null) return [];
    try {
      final list = json.decode(raw as String) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveMalAccounts(List<Map<String, dynamic>> accounts) async {
    await _settingsBox.put('malAccounts', json.encode(accounts));
  }

  // ── My List View Mode (Tile vs Grid) ──
  static bool get isMyListGridView => _settingsBox.get('my_list_grid_view', defaultValue: false) as bool;
  static Future<void> setMyListGridView(bool value) => _settingsBox.put('my_list_grid_view', value);

  // ── Google Drive Auto-Backup ──
  static bool get isGoogleDriveAutoBackupEnabled => _settingsBox.get('gdrive_auto_backup', defaultValue: false) as bool;
  static Future<void> setGoogleDriveAutoBackupEnabled(bool value) => _settingsBox.put('gdrive_auto_backup', value);
}
