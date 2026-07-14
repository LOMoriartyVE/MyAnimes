import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/anime_model.dart';
import '../models/anime_list_item.dart';
import 'mal_auth_service.dart';

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
      await item.save();
      onDataChanged?.call();
      _syncListItemToMal(item);
    }
  }

  static Future<void> updateEpisodeProgress(int animeId, int progress) async {
    final item = getListItem(animeId);
    if (item != null) {
      item.episodeProgress = progress;
      item.isMalSynced = false;
      await item.save();
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
          if (success && item.isMalSynced != true) {
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
          if (success && item.isMalSynced != true) {
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

  static String get witanimeDomain => _settingsBox.get('witanimeDomain', defaultValue: 'witanime.you') as String;
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

  static Future<void> healListItemsMetadata() async {
    final items = getAllListItems();
    for (var item in items) {
      if (item.type == null || item.studios == null || item.year == null) {
        var cached = getCachedAnimeDetail(item.animeId);
        if (cached == null) {
          cached = getCachedMangaDetail(item.animeId);
        }
        if (cached != null) {
          try {
            final anime = AnimeModel.fromJson(cached);
            final newItem = AnimeListItem(
              animeId: item.animeId,
              title: item.title,
              image: item.image,
              score: item.score,
              genres: item.genres,
              category: item.category,
              addedAt: item.addedAt,
              userRating: item.userRating,
              episodes: item.episodes,
              episodeProgress: item.episodeProgress,
              type: anime.type,
              studios: anime.studios,
              year: anime.year,
              rank: anime.rank,
              popularity: anime.popularity,
              season: anime.season,
            );
            await _listBox.put(item.animeId, newItem);
          } catch (_) {}
        }
      }
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

  static List<Map<String, dynamic>>? _getListCache(String key) {
    if (!_isCacheValid(key)) return null;
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

  static List<Map<String, dynamic>>? getCachedSeasonAllPages() {
    final key = 'season_all_${_currentSeasonKey()}';
    return _getListCache(key);
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

  // ── Season single-page cache (kept for compatibility) ──

  static Future<void> cacheSeasonData(String key, List<Map<String, dynamic>> data) async {
    await _putCache('season_$key', data, ttl: const Duration(hours: 24));
  }

  static List<Map<String, dynamic>>? getCachedSeasonData(String key) {
    return _getListCache('season_$key');
  }

  static bool isSeasonCacheValid() {
    return _isCacheValid('season_${_currentSeasonKey()}');
  }

  // ── Genres ──

  static Future<void> cacheGenres(List<Map<String, dynamic>> data) async {
    await _putCache('genres', data, ttl: const Duration(days: 30));
  }

  static List<Map<String, dynamic>>? getCachedGenres() {
    return _getListCache('genres');
  }

  // ── Top Anime (TTL: 4 hours) ──

  static Future<void> cacheTopAnime(List<Map<String, dynamic>> data) async {
    await _putCache('top_anime', data, ttl: const Duration(hours: 4));
  }

  static List<Map<String, dynamic>>? getCachedTopAnime() {
    return _getListCache('top_anime');
  }

  static bool isTopAnimeCacheValid() => _isCacheValid('top_anime');

  // Legacy methods kept for backward compat
  static Future<void> cacheTopData(List<Map<String, dynamic>> data) => cacheTopAnime(data);
  static List<Map<String, dynamic>>? getCachedTopData() => getCachedTopAnime();
  static bool isTopCacheValid() => isTopAnimeCacheValid();

  // ── Top Manga (TTL: 4 hours) ──

  static Future<void> cacheTopManga(List<Map<String, dynamic>> data) async {
    await _putCache('top_manga', data, ttl: const Duration(hours: 4));
  }

  static List<Map<String, dynamic>>? getCachedTopManga() {
    return _getListCache('top_manga');
  }

  static bool isTopMangaCacheValid() => _isCacheValid('top_manga');

  // ── Top Reviews (TTL: 6 hours) ──

  static Future<void> cacheTopReviews(List<Map<String, dynamic>> data) async {
    await _putCache('top_reviews', data, ttl: const Duration(hours: 6));
  }

  static List<Map<String, dynamic>>? getCachedTopReviews() {
    return _getListCache('top_reviews');
  }

  static bool isTopReviewsCacheValid() => _isCacheValid('top_reviews');

  // ── Upcoming Anime (TTL: 4 hours) ──

  static Future<void> cacheUpcoming(List<Map<String, dynamic>> data) async {
    await _putCache('upcoming_anime', data, ttl: const Duration(hours: 4));
  }

  static List<Map<String, dynamic>>? getCachedUpcoming() {
    return _getListCache('upcoming_anime');
  }

  static bool isUpcomingCacheValid() => _isCacheValid('upcoming_anime');

  // ── Anime Detail Cache (TTL: 12 hours per anime) ──

  static Future<void> cacheAnimeDetail(int animeId, Map<String, dynamic> data) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ttl = const Duration(hours: 12).inMilliseconds;
    await _animeDetailCacheBox.put('anime_${animeId}_data', json.encode(data));
    await _animeDetailCacheBox.put('anime_${animeId}_ts', now);
    await _animeDetailCacheBox.put('anime_${animeId}_ttl', ttl);
  }

  static Map<String, dynamic>? getCachedAnimeDetail(int animeId) {
    final ts  = _animeDetailCacheBox.get('anime_${animeId}_ts');
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
}
