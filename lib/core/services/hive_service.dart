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
  static const String _appDataBoxName   = 'app_data_items';

  static late Box<AnimeListItem> _listBox;
  static late Box<dynamic>       _settingsBox;
  static late Box<dynamic>       _cacheBox;
  static late Box<dynamic>       _animeDetailCacheBox;
  static late Box<dynamic>       _mangaDetailCacheBox;
  static late Box<dynamic>       _downloadsBox;
  static late Box<dynamic>       _appDataBox;

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Box<AnimeListItem>? get _safeListBox {
    try {
      if (_initialized && _listBox.isOpen) return _listBox;
      if (Hive.isBoxOpen(_listBoxName)) {
        final b = Hive.box<AnimeListItem>(_listBoxName);
        if (b.isOpen) {
          _listBox = b;
          return _listBox;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Box<T>> _openBoxSafely<T>(String name) async {
    try {
      if (Hive.isBoxOpen(name)) {
        final b = Hive.box<T>(name);
        if (b.isOpen) return b;
      }
      return await Hive.openBox<T>(name);
    } catch (e) {
      debugPrint('[HiveService] Failed opening "$name": $e. Attempting clean recovery...');
      try {
        if (Hive.isBoxOpen(name)) {
          final b = Hive.box<T>(name);
          if (b.isOpen) await b.close();
        }
      } catch (_) {}
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (delErr) {
        debugPrint('[HiveService] Could not delete "$name" from disk: $delErr');
      }
      return await Hive.openBox<T>(name);
    }
  }

  /// Initialize Hive and open all boxes safely.
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters safely (avoid duplicate registration errors)
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(AnimeModelAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(AnimeListItemAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(AnimeCategoryAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(UserRatingAdapter());

    // Open each box independently — a corruption in a cache box never breaks user data!
    _listBox             = await _openBoxSafely<AnimeListItem>(_listBoxName);
    _settingsBox         = await _openBoxSafely<dynamic>(_settingsBoxName);
    _cacheBox            = await _openBoxSafely<dynamic>(_cacheBoxName);
    _animeDetailCacheBox = await _openBoxSafely<dynamic>(_animeDetailBox);
    _mangaDetailCacheBox = await _openBoxSafely<dynamic>(_mangaDetailBox);
    _downloadsBox        = await _openBoxSafely<dynamic>(_downloadsBoxName);
    _appDataBox          = await _openBoxSafely<dynamic>(_appDataBoxName);

    // Sanitize and deduplicate _listBox so all entries are keyed by item.animeId
    try {
      if (_listBox.isOpen) {
        final keysToRemove = <dynamic>[];
        final itemsByAnimeId = <int, AnimeListItem>{};
        for (final key in _listBox.keys) {
          final val = _listBox.get(key);
          if (val != null) {
            if (key != val.animeId) {
              keysToRemove.add(key);
            }
            final current = itemsByAnimeId[val.animeId];
            if (current == null) {
              itemsByAnimeId[val.animeId] = val;
            } else {
              final valHasSub = val.userRating?.hasSubRatings == true;
              final curHasSub = current.userRating?.hasSubRatings == true;
              if (valHasSub && !curHasSub) {
                itemsByAnimeId[val.animeId] = val;
              } else if (!valHasSub && curHasSub) {
                // keep current
              } else if ((val.userRating?.overall ?? 0) > 0 && (current.userRating?.overall ?? 0) == 0) {
                itemsByAnimeId[val.animeId] = val;
              } else if (val.addedAt.isAfter(current.addedAt)) {
                if (val.userRating?.hasRating == true || current.userRating?.hasRating != true) {
                  itemsByAnimeId[val.animeId] = val;
                }
              }
            }
          }
        }
        for (final key in keysToRemove) {
          await _listBox.delete(key);
        }
        for (final entry in itemsByAnimeId.entries) {
          await _listBox.put(entry.key, entry.value);
        }
      }
    } catch (e) {
      debugPrint('Error sanitizing _listBox: $e');
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
    try {
      final box = _safeListBox;
      if (box == null || !box.isOpen) return [];
      return box.values.toList();
    } catch (_) {
      return [];
    }
  }

  static List<AnimeListItem> getByCategory(AnimeCategory category) {
    try {
      final box = _safeListBox;
      if (box == null || !box.isOpen) return [];
      return box.values.where((item) => item.category == category).toList();
    } catch (_) {
      return [];
    }
  }

  static int get animeCount {
    try {
      final box = _safeListBox;
      if (box == null || !box.isOpen) return 0;
      return box.values.where((i) => (i.type?.toLowerCase() != 'manga')).length;
    } catch (_) {
      return 0;
    }
  }

  static int get mangaCount {
    try {
      final box = _safeListBox;
      if (box == null || !box.isOpen) return 0;
      return box.values.where((i) => (i.type?.toLowerCase() == 'manga')).length;
    } catch (_) {
      return 0;
    }
  }

  static AnimeListItem? getListItem(int animeId) {
    try {
      final box = _safeListBox;
      if (box == null || !box.isOpen) return null;
      final direct = box.get(animeId);
      if (direct != null && direct.animeId == animeId) return direct;
      return box.values.firstWhere((item) => item.animeId == animeId);
    } catch (_) {
      return null;
    }
  }

  static ValueListenable<Box<AnimeListItem>> get listBoxListenable => _listBox.listenable();
  static ValueListenable<Box<dynamic>> get cacheBoxListenable => _cacheBox.listenable();
  static ValueListenable<Box<dynamic>> get appDataBoxListenable => _appDataBox.listenable();

  static void Function()? onDataChanged;

  static bool isInList(int animeId) {
    try {
      final box = _safeListBox;
      if (box == null || !box.isOpen) return false;
      return box.values.any((item) => item.animeId == animeId);
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearAllListItems() async {
    await _listBox.clear();
    onDataChanged?.call();
  }

  static Future<void> saveListItemDirectly(AnimeListItem item) async {
    await _listBox.put(item.animeId, item);
    if (item.key != null && item.key != item.animeId) {
      try {
        await _listBox.delete(item.key);
      } catch (_) {}
    }
    onDataChanged?.call();
  }

  static Future<void> addToList(AnimeListItem item) async {
    if (MalAuthService.instance.isLoggedIn) {
      item.isMalSynced = true;
    }
    // Use animeId as key for easy lookup
    await _listBox.put(item.animeId, item);
    if (item.key != null && item.key != item.animeId) {
      try {
        await _listBox.delete(item.key);
      } catch (_) {}
    }
    onDataChanged?.call();
    _syncListItemToMal(item);
  }

  static Future<void> removeFromList(int animeId) async {
    final item = getListItem(animeId);
    final type = item?.type;
    if (item != null && item.isInBox && item.key != null && item.key != animeId) {
      try {
        await _listBox.delete(item.key);
      } catch (_) {}
    }
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
      if (item.isInBox) {
        try {
          await item.save();
        } catch (_) {}
      }
      await _listBox.put(item.animeId, item);
      if (item.key != null && item.key != item.animeId) {
        try {
          await _listBox.delete(item.key);
        } catch (_) {}
      }
      onDataChanged?.call();
      _syncListItemToMal(item);
    }
  }

  static Future<void> updateUserRating(int animeId, UserRating rating) async {
    final item = getListItem(animeId);
    if (item != null) {
      item.userRating = rating;
      item.isMalSynced = false;
      if (item.isInBox) {
        try {
          await item.save();
        } catch (_) {}
      }
      await _listBox.put(item.animeId, item);
      if (item.key != null && item.key != item.animeId) {
        try {
          await _listBox.delete(item.key);
        } catch (_) {}
      }
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
        // Protect user's custom and specific sub-ratings:
        // Only set rating from MAL if the user has NOT rated this item locally.
        if (existing.userRating == null || !existing.userRating!.hasRating) {
          existing.userRating = UserRating(overall: score.toDouble());
        }
      }
      existing.isMalSynced = true;
      if (existing.isInBox) {
        try {
          await existing.save();
        } catch (_) {}
      }
      await _listBox.put(animeId, existing);
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
      final malScore = (score != null && score >= 0) ? score : null;

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
      final malScore = (score != null && score >= 0) ? score : null;

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

  static bool get isDarkMode {
    try {
      final box = _safeSettingsBox;
      if (box == null || !box.isOpen) return true;
      return box.get('darkMode', defaultValue: true) as bool;
    } catch (_) {
      return true;
    }
  }
  static Future<void> setDarkMode(bool value) async {
    try {
      await _safeSettingsBox?.put('darkMode', value);
    } catch (_) {}
  }

  static String get themePack {
    try {
      final box = _safeSettingsBox;
      if (box == null || !box.isOpen) return 'default_dark';
      return box.get('themePack', defaultValue: 'default_dark') as String;
    } catch (_) {
      return 'default_dark';
    }
  }
  static Future<void> setThemePack(String value) async {
    try {
      final box = _safeSettingsBox;
      if (box == null || !box.isOpen) return;
      await box.put('themePack', value);
      await box.put('darkMode', value != 'default_light');
    } catch (_) {}
  }

  static String get language {
    try {
      final box = _safeSettingsBox;
      if (box == null || !box.isOpen) return 'en';
      return box.get('language', defaultValue: 'en') as String;
    } catch (_) {
      return 'en';
    }
  }
  static Future<void> setLanguage(String lang) async {
    try {
      await _safeSettingsBox?.put('language', lang);
    } catch (_) {}
  }

  // ── Exclusions ──
  static final ValueNotifier<int> exclusionsRevision = ValueNotifier<int>(0);

  static List<String> get excludedCategories {
    try {
      final box = _safeSettingsBox;
      if (box == null || !box.isOpen) return <String>[];
      final raw = box.get('excludedCategories');
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
      return <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  static Set<String> get excludedCategoriesSet {
    return excludedCategories.map((c) => c.toLowerCase()).toSet();
  }

  static Future<void> setExcludedCategories(List<String> list) async {
    final clean = list.map((e) => e.trim()).where((s) => s.isNotEmpty).toSet().toList()..sort();
    await _settingsBox.put('excludedCategories', clean);
    exclusionsRevision.value++;
    onDataChanged?.call();
  }

  /// Determines if an anime or manga should be excluded based on its genres, rating, or type.
  static bool isExcluded({
    List<dynamic>? genres,
    String? rating,
    String? type,
  }) {
    final excluded = excludedCategoriesSet;
    if (excluded.isEmpty) return false;

    // 1. Check genres
    if (genres != null && genres.isNotEmpty) {
      for (final g in genres) {
        final name = (g is Map ? g['name'] : g)?.toString().trim().toLowerCase();
        if (name != null && name.isNotEmpty) {
          if (excluded.contains(name)) return true;
          for (final ex in excluded) {
            if (name == ex) return true;
            if (ex == 'hentai' && name.contains('hentai')) return true;
            if (ex == 'ecchi' && name.contains('ecchi')) return true;
            if (ex == 'erotica' && (name.contains('eroti') || name == 'erotica')) return true;
            if (ex == 'boys love' && (name.contains('boys love') || name == 'yaoi')) return true;
            if (ex == 'girls love' && (name.contains('girls love') || name == 'yuri')) return true;
          }
        }
      }
    }

    // 2. Check rating
    if (rating != null && rating.isNotEmpty) {
      final r = rating.trim().toLowerCase();
      if (excluded.contains(r)) return true;
      if (excluded.contains('hentai') && (r.contains('rx') || r.contains('hentai'))) return true;
      if (excluded.contains('ecchi') && r.contains('mild nudity')) return true;
      if (excluded.contains('erotica') && (r.contains('rx') || r.contains('erotica'))) return true;
    }

    // 3. Check media type
    if (type != null && type.isNotEmpty) {
      final t = type.trim().toLowerCase();
      if (excluded.contains(t)) return true;
    }

    return false;
  }

  /// Filters out any AnimeModel that matches the user's excluded categories.
  static List<AnimeModel> filterExcludedAnime(List<AnimeModel> list) {
    try {
      if (excludedCategoriesSet.isEmpty) return list;
      return list.where((a) => !isExcluded(genres: a.genres, rating: a.rating, type: a.type)).toList();
    } catch (_) {
      return list;
    }
  }

  /// Filters out any Map data that matches the user's excluded categories.
  static List<Map<String, dynamic>> filterExcludedMaps(List<Map<String, dynamic>> list) {
    try {
      if (excludedCategoriesSet.isEmpty) return list;
      return list.where((m) {
        final genres = m['genres'] as List<dynamic>?;
        final rating = m['rating']?.toString();
        final type = m['type']?.toString();
        return !isExcluded(genres: genres, rating: rating, type: type);
      }).toList();
    } catch (_) {
      return list;
    }
  }

  /// Filters out any AnimeListItem that matches the user's excluded categories.
  static List<AnimeListItem> filterExcludedListItems(List<AnimeListItem> list) {
    try {
      if (excludedCategoriesSet.isEmpty) return list;
      return list.where((item) => !isExcluded(genres: item.genres, type: item.type)).toList();
    } catch (_) {
      return list;
    }
  }

  static bool get enableNotifications {
    try {
      return _safeSettingsBox?.get('enableNotif', defaultValue: true) as bool? ?? true;
    } catch (_) {
      return true;
    }
  }
  static Future<void> setEnableNotifications(bool value) async {
    try {
      await _safeSettingsBox?.put('enableNotif', value);
    } catch (_) {}
  }

  static bool get airingNotifications {
    try {
      return _safeSettingsBox?.get('airingNotif', defaultValue: true) as bool? ?? true;
    } catch (_) {
      return true;
    }
  }
  static Future<void> setAiringNotifications(bool value) async {
    try {
      await _safeSettingsBox?.put('airingNotif', value);
    } catch (_) {}
  }

  static bool get newSeasonNotifications {
    try {
      return _safeSettingsBox?.get('seasonNotif', defaultValue: true) as bool? ?? true;
    } catch (_) {
      return true;
    }
  }
  static Future<void> setNewSeasonNotifications(bool value) async {
    try {
      await _safeSettingsBox?.put('seasonNotif', value);
    } catch (_) {}
  }

  static String? get localAnimeFolder {
    try {
      return _safeSettingsBox?.get('localAnimeFolder') as String?;
    } catch (_) {
      return null;
    }
  }
  static Future<void> setLocalAnimeFolder(String? path) async {
    try {
      await _safeSettingsBox?.put('localAnimeFolder', path);
    } catch (_) {}
  }

  static String get witanimeDomain {
    try {
      final domain = _safeSettingsBox?.get('witanimeDomain', defaultValue: 'witanime.site') as String? ?? 'witanime.site';
      if (domain == 'witanime.you' || domain.isEmpty) {
        return 'witanime.site';
      }
      return domain;
    } catch (_) {
      return 'witanime.site';
    }
  }
  static Future<void> setWitanimeDomain(String value) async {
    try {
      await _safeSettingsBox?.put('witanimeDomain', value);
    } catch (_) {}
  }

  static String get witmangaDomain {
    try {
      return _safeSettingsBox?.get('witmangaDomain', defaultValue: 'witmanga.xyz') as String? ?? 'witmanga.xyz';
    } catch (_) {
      return 'witmanga.xyz';
    }
  }
  static Future<void> setWitmangaDomain(String value) async {
    try {
      await _safeSettingsBox?.put('witmangaDomain', value);
    } catch (_) {}
  }

  // ── Secure Token Obfuscation Helpers ──
  static const String _tokenPrefix = 'myanimes_enc_v1:';
  static final List<int> _tokenVaultKey = utf8.encode('MyAnimes_Sec_Token_Vault_Key_2026');

  static String? _protectToken(String? raw) {
    if (raw == null || raw.isEmpty) return raw;
    final bytes = utf8.encode(raw);
    final obscured = List<int>.generate(bytes.length, (i) => bytes[i] ^ _tokenVaultKey[i % _tokenVaultKey.length]);
    return '$_tokenPrefix${base64.encode(obscured)}';
  }

  static String? _unprotectToken(dynamic stored) {
    if (stored == null) return null;
    if (stored is! String) return stored.toString();
    if (!stored.startsWith(_tokenPrefix)) {
      return stored; // Backward compatibility with legacy plaintext tokens
    }
    try {
      final base64Part = stored.substring(_tokenPrefix.length);
      final obscured = base64.decode(base64Part);
      final bytes = List<int>.generate(obscured.length, (i) => obscured[i] ^ _tokenVaultKey[i % _tokenVaultKey.length]);
      return utf8.decode(bytes);
    } catch (_) {
      return stored;
    }
  }

  static String? get malAccessToken => _unprotectToken(_settingsBox.get('malAccessToken'));
  static Future<void> setMalAccessToken(String? token) => _settingsBox.put('malAccessToken', _protectToken(token));

  static String? get malRefreshToken => _unprotectToken(_settingsBox.get('malRefreshToken'));
  static Future<void> setMalRefreshToken(String? token) => _settingsBox.put('malRefreshToken', _protectToken(token));

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

  static bool get saveLastScheduleFetch => _settingsBox.get('saveLastScheduleFetch', defaultValue: true) as bool;
  static Future<void> setSaveLastScheduleFetch(bool value) => _settingsBox.put('saveLastScheduleFetch', value);

  static String? get lastScheduleSeasonKey => _settingsBox.get('lastScheduleSeasonKey') as String?;
  static Future<void> setLastScheduleSeasonKey(String key) => _settingsBox.put('lastScheduleSeasonKey', key);

  static String get userTimezone {
    try {
      return _settingsBox.get('userTimezone', defaultValue: 'device') as String;
    } catch (_) {
      return 'device';
    }
  }
  static Future<void> setUserTimezone(String tz) async {
    try {
      await _settingsBox.put('userTimezone', tz);
    } catch (_) {}
  }

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
          if (cachedDetail != null) {
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
      
      final currentMaxYear = DateTime.now().year + 2;
      final parsedExistingYear = int.tryParse(item.year ?? '');
      final isYearCorrupted = parsedExistingYear != null && (parsedExistingYear > currentMaxYear || parsedExistingYear < 1917);

      if (item.year == null || item.year == 'Unknown' || item.year!.isEmpty || isYearCorrupted) {
        if (cachedYears.containsKey(item.animeId)) {
          final cy = cachedYears[item.animeId];
          final pcy = int.tryParse(cy.toString());
          if (pcy != null && pcy <= currentMaxYear && pcy >= 1917) {
            updatedYear = cy.toString();
            needSave = true;
          } else {
            updatedYear = null;
            needSave = true;
          }
        } else {
          // Try season string (e.g. "Fall 2023")
          updatedYear = null;
          if (item.season != null) {
            final m = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(item.season!);
            if (m != null) {
              final y = int.tryParse(m.group(1)!);
              if (y != null && y <= currentMaxYear && y >= 1917) {
                updatedYear = m.group(1);
                needSave = true;
              }
            }
          }
          if (isYearCorrupted && updatedYear == null) {
            updatedYear = null;
            needSave = true;
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
        cached ??= getCachedMangaDetail(item.animeId);
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
          await cacheAnimeDetail(item.animeId, animeObj.toJson());

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

  static String? getWindowsDriveAccessToken() => _unprotectToken(_settingsBox.get('winAccessToken'));
  static String? getWindowsDriveRefreshToken() => _unprotectToken(_settingsBox.get('winRefreshToken'));
  static int? getWindowsDriveExpiry() => _settingsBox.get('winTokenExpiry') as int?;
  static String? getWindowsDriveEmail() => _settingsBox.get('winUserEmail') as String?;

  static Future<void> setWindowsDriveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiry,
    required String email,
  }) async {
    await _settingsBox.put('winAccessToken', _protectToken(accessToken));
    await _settingsBox.put('winRefreshToken', _protectToken(refreshToken));
    await _settingsBox.put('winTokenExpiry', expiry);
    await _settingsBox.put('winUserEmail', email);
  }

  static Future<void> clearWindowsDriveTokens() async {
    await _settingsBox.delete('winAccessToken');
    await _settingsBox.delete('winRefreshToken');
    await _settingsBox.delete('winTokenExpiry');
    await _settingsBox.delete('winUserEmail');
  }

  static Box<dynamic>? get _safeCacheBox {
    try {
      if (_initialized && _cacheBox.isOpen) return _cacheBox;
      if (Hive.isBoxOpen(_cacheBoxName)) {
        final b = Hive.box<dynamic>(_cacheBoxName);
        if (b.isOpen) {
          _cacheBox = b;
          return _cacheBox;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Box<dynamic>? get _safeSettingsBox {
    try {
      if (_initialized && _settingsBox.isOpen) return _settingsBox;
      if (Hive.isBoxOpen(_settingsBoxName)) {
        final b = Hive.box<dynamic>(_settingsBoxName);
        if (b.isOpen) {
          _settingsBox = b;
          return _settingsBox;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Generic TTL Cache Helpers ──

  static Future<void> _putCache(String key, dynamic data, {Duration ttl = const Duration(hours: 24)}) async {
    try {
      final box = _safeCacheBox;
      if (box == null || !box.isOpen) return;
      await box.put('${key}_data', json.encode(data));
      await box.put('${key}_ts', DateTime.now().millisecondsSinceEpoch);
      await box.put('${key}_ttl', ttl.inMilliseconds);
      await box.flush();
    } catch (_) {}
  }

  static bool _isCacheValid(String key) {
    try {
      final box = _safeCacheBox;
      if (box == null || !box.isOpen) return false;
      final ts = box.get('${key}_ts');
      if (ts == null) return false;
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts as int);
      
      final mode = cacheMode;
      if (mode == 'never') return true;

      final duration = mode == 'default'
          ? const Duration(hours: 2)
          : Duration(hours: customCacheDurationHours);

      return DateTime.now().difference(cachedAt).inMilliseconds < duration.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  static List<Map<String, dynamic>>? _getListCache(String key, {bool allowExpired = true}) {
    try {
      if (!allowExpired && !_isCacheValid(key)) return null;
      final box = _safeCacheBox;
      if (box == null || !box.isOpen) return null;
      final raw = box.get('${key}_data');
      if (raw == null) return null;
      if (raw is List) {
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      final list = json.decode(raw as String) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  static String? get lastKnownSeasonKey => _settingsBox.get('lastKnownSeasonKey') as String?;
  static Future<void> setLastKnownSeasonKey(String key) => _settingsBox.put('lastKnownSeasonKey', key);

  static Future<void> clearSeasonCache() async {
    try {
      final box = _safeCacheBox;
      if (box == null || !box.isOpen) return;
      final key = 'season_all_${_currentSeasonKey()}';
      await box.delete('${key}_data');
      await box.delete('${key}_ts');
      await box.delete('season_${_currentSeasonKey()}_data');
      await box.delete('season_${_currentSeasonKey()}_ts');
    } catch (_) {}
  }

  /// Cache all-pages season data. TTL = until next season boundary (up to ~3 months).
  static Future<void> cacheSeasonAllPages(List<Map<String, dynamic>> data) async {
    final key = 'season_all_${_currentSeasonKey()}';
    final existing = getCachedSeasonAllPages(allowExpired: true);
    if (existing != null && existing.length > data.length) {
      // Don't downgrade a full fetch (e.g. 200 items) with a partial preview (e.g. 25 items)
      return;
    }
    await _putCache(key, data, ttl: const Duration(days: 7));
  }

  static List<Map<String, dynamic>>? getCachedSeasonAllPages({bool allowExpired = true}) {
    final key = 'season_all_${_currentSeasonKey()}';
    return _getListCache(key, allowExpired: allowExpired);
  }

  static bool hasAnySeasonCache() {
    try {
      final box = _safeCacheBox;
      if (box == null || !box.isOpen) return false;
      final key = 'season_all_${_currentSeasonKey()}';
      return box.containsKey('${key}_ts');
    } catch (_) {
      return false;
    }
  }

  static List<Map<String, dynamic>>? getSeasonCacheIgnoringTtl() {
    final key = 'season_all_${_currentSeasonKey()}';
    return _getListCache(key, allowExpired: true);
  }

  static bool isSeasonAllPagesCacheValid() {
    return _isCacheValid('season_all_${_currentSeasonKey()}');
  }

  /// Cache all-pages season data for an arbitrary seasonKey (e.g. '2024_fall').
  static Future<void> cacheSeasonAllPagesForSeason(String seasonKey, List<Map<String, dynamic>> data) async {
    final key = 'season_all_$seasonKey';
    final existing = getCachedSeasonAllPagesForSeason(seasonKey);
    if (existing != null && existing.length > data.length) {
      // Don't downgrade a full fetch with a smaller partial result
      return;
    }
    await _putCache(key, data, ttl: const Duration(days: 365));

    final permanent = List<String>.from(_settingsBox.get('permanent_season_keys', defaultValue: <String>[]) as List);
    if (!permanent.contains(seasonKey)) {
      permanent.add(seasonKey);
      await _settingsBox.put('permanent_season_keys', permanent);
    }
    await _settingsBox.flush();
    await _cacheBox.flush();
  }

  static List<Map<String, dynamic>>? getCachedSeasonAllPagesForSeason(String seasonKey) {
    final key = 'season_all_$seasonKey';
    return _getListCache(key, allowExpired: true);
  }

  static bool hasSeasonCacheForSeason(String seasonKey) {
    final key = 'season_all_$seasonKey';
    return _cacheBox.containsKey('${key}_ts') || _cacheBox.containsKey('${key}_data');
  }

  /// Retrieve all season keys that have cached data in Hive (e.g. ['2026_summer', '2020_summer']).
  static List<String> getAllSavedSeasonKeys() {
    final keys = <String>{};
    final permanent = _settingsBox.get('permanent_season_keys') as List?;
    if (permanent != null) {
      for (final k in permanent) {
        if (k is String && k.isNotEmpty) keys.add(k);
      }
    }

    for (final k in _cacheBox.keys) {
      if (k is String && k.startsWith('season_all_') && k.endsWith('_data')) {
        final seasonKey = k.replaceFirst('season_all_', '').replaceFirst('_data', '');
        if (seasonKey.isNotEmpty) {
          keys.add(seasonKey);
        }
      }
    }
    final sorted = keys.toList();
    sorted.sort((a, b) => b.compareTo(a)); // Newest first
    return sorted;
  }

  /// Remove a saved season cache from Hive
  static Future<void> deleteSavedSeason(String seasonKey) async {
    final key = 'season_all_$seasonKey';
    await _cacheBox.delete('${key}_data');
    await _cacheBox.delete('${key}_ts');
    await _cacheBox.delete('${key}_ttl');

    final permanent = List<String>.from(_settingsBox.get('permanent_season_keys', defaultValue: <String>[]) as List);
    permanent.remove(seasonKey);
    await _settingsBox.put('permanent_season_keys', permanent);

    if (lastScheduleSeasonKey == seasonKey) {
      await _settingsBox.delete('lastScheduleSeasonKey');
    }
  }

  // ── App Data Management (Universal Data Page) ──

  static Future<void> saveToAppData(List<AnimeModel> animes) async {
    for (final a in animes) {
      await _appDataBox.put(a.id, a.toJson());
    }
  }

  static List<Map<String, dynamic>> getAllAppDataItems() {
    final Map<int, Map<String, dynamic>> map = {};

    // 1. From dedicated app data box
    for (final key in _appDataBox.keys) {
      final val = _appDataBox.get(key);
      if (val is Map) {
        final m = Map<String, dynamic>.from(val);
        final id = m['mal_id'] ?? m['id'] ?? (key is int ? key : int.tryParse(key.toString()));
        if (id is int && id > 0) map[id] = m;
      }
    }

    // 2. From cached season data
    final lastKey = lastScheduleSeasonKey;
    final seasonData = (lastKey != null && lastKey.isNotEmpty)
        ? getCachedSeasonAllPagesForSeason(lastKey)
        : getCachedSeasonAllPages();
    if (seasonData != null) {
      for (final m in seasonData) {
        final id = m['mal_id'] as int? ?? 0;
        if (id > 0 && !map.containsKey(id)) {
          map[id] = Map<String, dynamic>.from(m);
        }
      }
    }

    // 3. From user's list box
    for (final item in _listBox.values) {
      if (!map.containsKey(item.animeId)) {
        map[item.animeId] = {
          'mal_id': item.animeId,
          'title': item.title,
          'title_japanese': item.title,
          'images': {'jpg': {'large_image_url': item.image, 'image_url': item.image}},
          'score': item.score,
          'genres': item.genres.map((g) => {'name': g}).toList(),
          'type': item.type,
          'year': item.year,
          'season': item.season,
          'episodes': item.episodes,
          'status': 'In My List',
          'studios': item.studios?.map((s) => {'name': s}).toList() ?? [],
        };
      }
    }

    return map.values.toList();
  }

  static Future<void> deleteFromAppData(int animeId) async {
    await _appDataBox.delete(animeId);
  }

  static Future<void> saveAppDataMapDirectly(int animeId, Map<String, dynamic> data) async {
    await _appDataBox.put(animeId, data);
  }

  static Future<AnimeModel?> refetchAppDataItem(int animeId) async {
    try {
      final anime = await JikanService.getAnimeById(animeId);
      await _appDataBox.put(animeId, anime.toJson());
      return anime;
    } catch (_) {
      return null;
    }
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

  static Future<void> deleteCachedAnimeDetail(int animeId) async {
    await _animeDetailCacheBox.delete('anime_${animeId}_data');
    await _animeDetailCacheBox.delete('anime_${animeId}_ts');
    await _animeDetailCacheBox.delete('anime_${animeId}_ttl');
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
      final map = json.decode(raw as String) as Map<String, dynamic>;
      // Sanity check: must have title and at least image or genres to be a valid anime detail
      final hasTitle = (map['title'] != null && map['title'].toString().trim().isNotEmpty) ||
                       (map['title_english'] != null && map['title_english'].toString().trim().isNotEmpty);
      final hasImage = (map['images'] != null && map['images'] is Map && (map['images'] as Map).isNotEmpty) ||
                       (map['image'] != null && map['image'].toString().trim().isNotEmpty);
      if (!hasTitle || !hasImage) {
        deleteCachedAnimeDetail(animeId);
        return null;
      }
      return map;
    } catch (_) {
      deleteCachedAnimeDetail(animeId);
      return null;
    }
  }

  // ── Manga Detail Cache (TTL: 12 hours per manga — SEPARATE from anime!) ──

  static Future<void> deleteCachedMangaDetail(int mangaId) async {
    await _mangaDetailCacheBox.delete('manga_${mangaId}_data');
    await _mangaDetailCacheBox.delete('manga_${mangaId}_ts');
    await _mangaDetailCacheBox.delete('manga_${mangaId}_ttl');
  }

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
      final map = json.decode(raw as String) as Map<String, dynamic>;
      final hasTitle = (map['title'] != null && map['title'].toString().trim().isNotEmpty) ||
                       (map['title_english'] != null && map['title_english'].toString().trim().isNotEmpty);
      final hasImage = (map['images'] != null && map['images'] is Map && (map['images'] as Map).isNotEmpty) ||
                       (map['image'] != null && map['image'].toString().trim().isNotEmpty);
      if (!hasTitle || !hasImage) {
        deleteCachedMangaDetail(mangaId);
        return null;
      }
      return map;
    } catch (_) {
      deleteCachedMangaDetail(mangaId);
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
          "dialogues": item.userRating!.dialogues,
          "main_idea": item.userRating!.mainIdea,
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
            dialogues: (ratingMap['dialogues'] as num?)?.toDouble() ?? 0.0,
            mainIdea: (ratingMap['main_idea'] as num?)?.toDouble() ?? 0.0,
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
