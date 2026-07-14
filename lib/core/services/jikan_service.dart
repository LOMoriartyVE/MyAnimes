import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/anime_model.dart';
import '../models/character_model.dart';
import 'hive_service.dart';
import 'mal_auth_service.dart';

/// Jikan API v4 / MyAnimeList API v2 hybrid service.
class JikanService {
  // ── API Health Status ──
  static final ValueNotifier<bool> apiAvailable = ValueNotifier<bool>(true);
  static String? lastErrorMessage;
  static DateTime? _lastSuccessTime;
  /// When the API last responded successfully (null if never)
  static DateTime? get lastSuccessTime => _lastSuccessTime;
  static bool _usingCachedData = false;

  /// Whether the home page is currently showing cached data due to API failure
  static final ValueNotifier<bool> usingCachedData = ValueNotifier<bool>(false);

  static void _markApiHealthy() {
    _lastSuccessTime = DateTime.now();
    if (!apiAvailable.value) {
      apiAvailable.value = true;
      lastErrorMessage = null;
    }
    if (_usingCachedData) {
      _usingCachedData = false;
      usingCachedData.value = false;
    }
  }

  static void _markApiDown(String message) {
    lastErrorMessage = message;
    if (apiAvailable.value) {
      apiAvailable.value = false;
    }
  }

  static void markUsingCachedData() {
    _usingCachedData = true;
    usingCachedData.value = true;
  }

  static const String _baseUrl = 'https://api.jikan.moe/v4';
  static const String _malBaseUrl = 'https://api.myanimelist.net/v2';
  static String get _clientId => dotenv.env['CLIENT_ID'] ?? '';

  static final List<_QueueItem> _queue = [];
  static bool _isProcessing = false;

  /// Internal queue item for Jikan (rate-limited serial queue)
  static Future<dynamic> _enqueue(String url) {
    final completer = Completer<dynamic>();
    _queue.add(_QueueItem(url: url, completer: completer, retries: 3));
    _processQueue();
    return completer.future;
  }

  /// Direct concurrent fetch for MyAnimeList (MAL does not have strict 3 req/sec limits)
  static Future<dynamic> _executeMal(String url) async {
    try {
      final headers = <String, String>{
        'User-Agent': 'MyAnimes/1.1.70 (Flutter; Windows/Android)',
        'Accept': 'application/json',
      };

      final token = await MalAuthService.instance.getValidAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        headers['X-MAL-CLIENT-ID'] = _clientId;
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 429 || response.statusCode == 500 || response.statusCode == 502 || response.statusCode == 503 || response.statusCode == 504) {
        // Retry once on transient error
        await Future.delayed(const Duration(milliseconds: 1000));
        final retryResponse = await http.get(
          Uri.parse(url),
          headers: headers,
        ).timeout(const Duration(seconds: 10));

        if (retryResponse.statusCode != 200) {
          final msg = 'MAL API Error (${retryResponse.statusCode})';
          _markApiDown(msg);
          throw Exception(msg);
        } else {
          final body = json.decode(retryResponse.body);
          _markApiHealthy();
          return body;
        }
      } else if (response.statusCode != 200) {
        final msg = 'MAL API Error: ${response.statusCode}';
        _markApiDown(msg);
        throw Exception(msg);
      } else {
        final body = json.decode(response.body);
        _markApiHealthy();
        return body;
      }
    } catch (e) {
      _markApiDown(e.toString());
      rethrow;
    }
  }

  static Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final item = _queue.removeAt(0);
      try {
        final response = await http.get(
          Uri.parse(item.url),
          headers: {
            'User-Agent': 'MyAnimes/1.1.70 (Flutter; Windows/Android)',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 429 || response.statusCode == 500 || response.statusCode == 502 || response.statusCode == 503 || response.statusCode == 504) {
          if (item.retries > 0) {
            await Future.delayed(const Duration(milliseconds: 2000));
            _queue.insert(0, _QueueItem(
              url: item.url,
              completer: item.completer,
              retries: item.retries - 1,
            ));
          } else {
            final msg = response.statusCode == 429 
                ? 'Rate limit exceeded. Please try again later.'
                : 'Server error (${response.statusCode}). Please try again later.';
            _markApiDown(msg);
            item.completer.completeError(Exception(msg));
          }
        } else if (response.statusCode != 200) {
          final msg = 'API Error: ${response.statusCode}';
          _markApiDown(msg);
          item.completer.completeError(Exception(msg));
        } else {
          final body = json.decode(response.body);
          _markApiHealthy();
          item.completer.complete(body);
        }
      } catch (e) {
        if ((e is TimeoutException || e.toString().contains('SocketException') || e.toString().contains('Connection failed')) && item.retries > 0) {
          await Future.delayed(const Duration(milliseconds: 2000));
          _queue.insert(0, _QueueItem(
            url: item.url,
            completer: item.completer,
            retries: item.retries - 1,
          ));
        } else {
          _markApiDown(e.toString());
          if (!item.completer.isCompleted) {
            item.completer.completeError(e);
          }
        }
      }

      // Mandatory 400ms delay between Jikan requests
      await Future.delayed(const Duration(milliseconds: 400));
    }

    _isProcessing = false;
  }

  /// Helper to extract just data from response body
  static List _extractList(dynamic body) {
    if (body is Map && body.containsKey('data')) {
      final list = body['data'] as List;
      // If it is MAL list format, map each item to its node
      if (list.isNotEmpty && list.first is Map && (list.first as Map).containsKey('node')) {
        return list.map((item) => item['node']).toList();
      }
      return list;
    }
    if (body is List) return body;
    return [];
  }

  static Map<String, dynamic> _extractMap(dynamic body) {
    if (body is Map && body.containsKey('data')) {
      return body['data'] as Map<String, dynamic>;
    }
    if (body is Map<String, dynamic>) return body;
    return {};
  }

  static bool _hasNextPage(dynamic body) {
    if (body is Map) {
      if (body.containsKey('paging')) {
        final paging = body['paging'];
        return paging is Map && paging.containsKey('next');
      }
      final pagination = body['pagination'];
      if (pagination is Map) {
        return pagination['has_next_page'] == true;
      }
    }
    return false;
  }

  static const String _malFields = 'id,title,alternative_titles,main_picture,mean,synopsis,genres,status,rating,studios,num_episodes,start_season,media_type,source,average_episode_duration,num_list_users,rank,popularity,start_date,end_date,broadcast,my_list_status';

  static Map<String, dynamic> _mapMalToJikan(Map<String, dynamic> mal) {
    final id = mal['id'] ?? 0;
    final title = mal['title'] ?? 'Unknown';
    final altTitles = mal['alternative_titles'] ?? {};
    final titleEnglish = (altTitles['en'] != null && altTitles['en'].toString().trim().isNotEmpty)
        ? altTitles['en'].toString()
        : title;
    final titleJapanese = altTitles['ja'] ?? '';

    final mainPicture = mal['main_picture'] ?? {};
    final imageUrl = AnimeModel.getHighResImageUrl(mainPicture['large'] ?? mainPicture['medium'] ?? '');

    final myListStatus = mal['my_list_status'];
    if (myListStatus != null && myListStatus is Map) {
      final status = myListStatus['status'] as String? ?? 'plan_to_watch';
      final progress = myListStatus['num_episodes_watched'] as int? ?? myListStatus['num_chapters_read'] as int? ?? 0;
      final score = myListStatus['score'] as int? ?? 0;
      Future.microtask(() {
        HiveService.syncFromMal(
          animeId: id,
          status: status,
          progress: progress,
          score: score,
          title: titleEnglish,
          image: imageUrl,
          episodes: (mal['num_episodes'] ?? mal['num_chapters'] ?? '?').toString(),
        );
      });
    }

    final score = mal['mean'] ?? mal['score'];
    final synopsis = mal['synopsis'] ?? 'No synopsis available.';
    
    var status = mal['status'] ?? 'Unknown';
    if (status == 'currently_airing') {
      status = 'Currently Airing';
    } else if (status == 'finished_airing') {
      status = 'Finished Airing';
    } else if (status == 'not_yet_aired') {
      status = 'Not yet aired';
    }

    final genresList = mal['genres'] as List?;
    final genres = genresList?.map((g) => {
      'name': g['name'] ?? '',
    }).toList() ?? [];

    final studiosList = mal['studios'] as List?;
    final studios = studiosList?.map((s) => {
      'name': s['name'] ?? '',
    }).toList() ?? [];

    final durationSeconds = mal['average_episode_duration'] as int?;
    final duration = durationSeconds != null ? '${durationSeconds ~/ 60} min' : 'Unknown';

    final malBroadcast = mal['broadcast'] ?? {};
    final broadcastDay = malBroadcast['day_of_the_week'];
    final broadcastTime = malBroadcast['start_time'];

    final startSeason = mal['start_season'] ?? {};
    final year = startSeason['year'] ?? mal['start_date']?.toString().split('-').first ?? 'Unknown';
    final season = startSeason['season'];

    return {
      'mal_id': id,
      'title': title,
      'title_english': titleEnglish,
      'title_japanese': titleJapanese,
      'images': {
        'jpg': {
          'image_url': imageUrl,
          'large_image_url': imageUrl,
        }
      },
      'score': score,
      'synopsis': synopsis,
      'genres': genres,
      'status': status,
      'rating': mal['rating'] ?? 'None',
      'studios': studios,
      'episodes': mal['num_episodes'] ?? '?',
      'year': year,
      'type': (mal['media_type'] as String?)?.toUpperCase() ?? 'Unknown',
      'source': mal['source'] ?? 'Unknown',
      'duration': duration,
      'members': mal['num_list_users'],
      'rank': mal['rank'],
      'popularity': mal['popularity'],
      'aired': {
        'from': mal['start_date'],
        'to': mal['end_date'],
      },
      'broadcast': {
        'day': broadcastDay,
        'time': broadcastTime,
      },
      'season': season,
    };
  }

  static String _buildUrl(String endpoint, Map<String, String> params) {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final queryParams = <String, String>{};
    params.forEach((key, value) {
      if (value.isNotEmpty) queryParams[key] = value;
    });
    return uri.replace(queryParameters: queryParams).toString();
  }

  static String _buildMalUrl(String endpoint, Map<String, String> params) {
    final uri = Uri.parse('$_malBaseUrl$endpoint');
    final queryParams = <String, String>{};
    params.forEach((key, value) {
      if (value.isNotEmpty) queryParams[key] = value;
    });
    return uri.replace(queryParameters: queryParams).toString();
  }

  static String _getCurrentSeason() {
    final month = DateTime.now().month;
    if (month >= 1 && month <= 3) return 'winter';
    if (month >= 4 && month <= 6) return 'spring';
    if (month >= 7 && month <= 9) return 'summer';
    return 'fall';
  }

  static int _getCurrentYear() => DateTime.now().year;

  /// Deduplicate list of AnimeModel based on unique ID
  static List<AnimeModel> _deduplicate(List<AnimeModel> list) {
    final seen = <int>{};
    return list.where((item) => seen.add(item.id)).toList();
  }

  // ── Public API Methods (Routed to MyAnimeList v2) ──

  /// Get current season anime (single page with limit)
  static Future<List<AnimeModel>> getSeasonNow({int limit = 15, int page = 1}) async {
    final offset = (page - 1) * limit;
    final year = _getCurrentYear();
    final season = _getCurrentSeason();
    final url = _buildMalUrl('/anime/season/$year/$season', {
      'fields': _malFields,
      'limit': '$limit',
      'offset': '$offset',
    });
    final body = await _executeMal(url);
    final data = _extractList(body);
    return _deduplicate(data.map((e) => AnimeModel.fromJson(_mapMalToJikan(e as Map<String, dynamic>))).toList());
  }

  /// Fetch ALL pages of the current season in the background.
  /// Calls [onProgress] with the growing list after each page.
  static Future<List<AnimeModel>> getSeasonNowAllPages({
    void Function(List<AnimeModel> soFar)? onProgress,
  }) async {
    final uniqueAnime = <int, AnimeModel>{};
    int page = 1;
    bool hasNext = true;
    final year = _getCurrentYear();
    final season = _getCurrentSeason();

    while (hasNext) {
      final offset = (page - 1) * 25;
      final url = _buildMalUrl('/anime/season/$year/$season', {
        'fields': _malFields,
        'limit': '25',
        'offset': '$offset',
      });
      try {
        final body = await _executeMal(url);
        final data = _extractList(body);
        final parsed = data.map((e) => AnimeModel.fromJson(_mapMalToJikan(e as Map<String, dynamic>))).toList();
        for (var item in parsed) {
          uniqueAnime[item.id] = item;
        }
        hasNext = _hasNextPage(body);
        page++;
        onProgress?.call(List.unmodifiable(uniqueAnime.values.toList()));
        if (hasNext) await Future.delayed(const Duration(milliseconds: 100));
      } catch (_) {
        break;
      }
    }

    return uniqueAnime.values.toList();
  }

  /// Get upcoming anime (not yet aired)
  static Future<List<AnimeModel>> getUpcomingAnime({int limit = 15, int page = 1}) async {
    final offset = (page - 1) * limit;
    final url = _buildMalUrl('/anime/ranking', {
      'ranking_type': 'upcoming',
      'fields': _malFields,
      'limit': '$limit',
      'offset': '$offset',
    });
    final body = await _executeMal(url);
    final data = _extractList(body);
    return _deduplicate(data.map((e) => AnimeModel.fromJson(_mapMalToJikan(e as Map<String, dynamic>))).toList());
  }

  /// Get top anime with pagination
  static Future<List<AnimeModel>> getTopAnime({int limit = 15, int page = 1}) async {
    final offset = (page - 1) * limit;
    final url = _buildMalUrl('/anime/ranking', {
      'ranking_type': 'all',
      'fields': _malFields,
      'limit': '$limit',
      'offset': '$offset',
    });
    final body = await _executeMal(url);
    final data = _extractList(body);
    return _deduplicate(data.map((e) => AnimeModel.fromJson(_mapMalToJikan(e as Map<String, dynamic>))).toList());
  }

  /// Search anime with filters
  static Future<List<AnimeModel>> searchAnime({
    String query = '',
    String status = '',
    String rating = '',
    String orderBy = 'score',
    String sort = 'desc',
    String genres = '',
    String producers = '',
    int limit = 25,
    int page = 1,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 3) {
      // Fallback to Jikan API v4 endpoint (supports short/empty queries)
      final params = <String, String>{
        'q': cleanQuery,
        'status': status,
        'rating': rating,
        'order_by': orderBy,
        'sort': sort,
        'genres': genres,
        'producers': producers,
        'limit': '$limit',
        'page': '$page',
      };
      final url = _buildUrl('/anime', params);
      final body = await _enqueue(url);
      final data = _extractList(body);
      return _deduplicate(data.map((e) => AnimeModel.fromJson(e as Map<String, dynamic>)).toList());
    }

    final offset = (page - 1) * limit;
    final url = _buildMalUrl('/anime', {
      'q': cleanQuery,
      'fields': _malFields,
      'limit': '$limit',
      'offset': '$offset',
    });
    final body = await _executeMal(url);
    final data = _extractList(body);
    return _deduplicate(data.map((e) => AnimeModel.fromJson(_mapMalToJikan(e as Map<String, dynamic>))).toList());
  }

  /// Get anime details by ID
  static Future<AnimeModel> getAnimeById(int id) async {
    final url = _buildMalUrl('/anime/$id', {'fields': _malFields});
    final body = await _executeMal(url);
    final data = _extractMap(body);
    return AnimeModel.fromJson(_mapMalToJikan(data));
  }

  /// Get anime characters (Hybrid - kept on Jikan as MAL has no character endpoint)
  static Future<List<CharacterModel>> getAnimeCharacters(int id, {int limit = 10}) async {
    final url = _buildUrl('/anime/$id/characters', {});
    final body = await _enqueue(url);
    final data = _extractList(body);
    return data
        .take(limit)
        .map((e) => CharacterModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get schedule for a specific day (Hybrid - kept on Jikan)
  static Future<List<AnimeModel>> getSchedule(String day) async {
    final url = _buildUrl('/schedules', {'filter': day, 'sfw': 'true'});
    final body = await _enqueue(url);
    final data = _extractList(body);
    return _deduplicate(data.map((e) => AnimeModel.fromJson(e as Map<String, dynamic>)).toList());
  }

  /// Get anime episodes (Hybrid - kept on Jikan)
  static Future<int> getNextEpisodeNumber(int id) async {
    try {
      final url = _buildUrl('/anime/$id/episodes', {});
      final body = await _enqueue(url);
      final data = _extractList(body);
      if (data.isEmpty) return 1;
      
      int maxEp = 0;
      for (final ep in data) {
        final epNum = ep['mal_id'] as int? ?? 0;
        if (epNum > maxEp) maxEp = epNum;
      }
      return maxEp + 1;
    } catch (_) {
      return 1;
    }
  }

  /// Get anime genres (Hybrid - kept on Jikan)
  static Future<List<Map<String, dynamic>>> getAnimeGenres() async {
    try {
      final url = _buildUrl('/genres/anime', {});
      final body = await _enqueue(url);
      final data = _extractList(body);
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Get historical season archive
  static Future<List<AnimeModel>> getSeasonArchive(int year, String season, {int limit = 25}) async {
    try {
      final url = _buildMalUrl('/anime/season/$year/$season', {
        'fields': _malFields,
        'limit': '$limit',
      });
      final body = await _executeMal(url);
      final data = _extractList(body);
      return _deduplicate(data.map((e) => AnimeModel.fromJson(_mapMalToJikan(e as Map<String, dynamic>))).toList());
    } catch (_) {
      return [];
    }
  }

  /// Get a single random anime (Hybrid - kept on Jikan)
  static Future<AnimeModel?> getRandomAnime() async {
    try {
      final url = _buildUrl('/random/anime', {'sfw': 'true'});
      final body = await _enqueue(url);
      final data = _extractMap(body);
      return AnimeModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Get anime producers (Hybrid - kept on Jikan)
  static Future<List<Map<String, dynamic>>> getProducers() async {
    try {
      final url = _buildUrl('/producers', {});
      final body = await _enqueue(url);
      final data = _extractList(body);
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── Manga Methods ──

  /// Get top manga with pagination
  static Future<List<AnimeModel>> getTopManga({int limit = 15, int page = 1}) async {
    try {
      final offset = (page - 1) * limit;
      final url = _buildMalUrl('/manga/ranking', {
        'ranking_type': 'all',
        'fields': 'id,title,alternative_titles,main_picture,mean,synopsis,genres,status,media_type,num_volumes,num_chapters',
        'limit': '$limit',
        'offset': '$offset',
      });
      final body = await _executeMal(url);
      final data = _extractList(body);
      return _deduplicate(data.map((e) => AnimeModel.fromJson(_mapMalToJikan(e as Map<String, dynamic>))).toList());
    } catch (_) {
      return [];
    }
  }

  /// Get top reviews with pagination (Hybrid - kept on Jikan)
  static Future<List<Map<String, dynamic>>> getTopReviews({int limit = 10, int page = 1}) async {
    try {
      final url = _buildUrl('/reviews/anime', {'page': '$page'});
      final body = await _enqueue(url);
      final data = _extractList(body);
      return data.take(limit).cast<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Get anime pictures
  static Future<List<String>> getAnimePictures(int id) async {
    try {
      final url = _buildMalUrl('/anime/$id', {'fields': 'pictures'});
      final body = await _executeMal(url);
      final picturesList = body['pictures'] as List?;
      if (picturesList == null) return [];
      return picturesList.map<String>((e) => e['large'] ?? e['medium'] ?? '').where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get anime statistics (Hybrid - kept on Jikan)
  static Future<Map<String, dynamic>?> getAnimeStatistics(int id) async {
    try {
      final url = _buildUrl('/anime/$id/statistics', {});
      final body = await _enqueue(url);
      return _extractMap(body);
    } catch (_) {
      return null;
    }
  }

  /// Get anime reviews (Hybrid - kept on Jikan)
  static Future<List<Map<String, dynamic>>> getAnimeReviews(int id) async {
    try {
      final url = _buildUrl('/anime/$id/reviews', {});
      final body = await _enqueue(url);
      final data = _extractList(body);
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Get anime news (Hybrid - kept on Jikan)
  static Future<List<Map<String, dynamic>>> getAnimeNews(int id) async {
    try {
      final url = _buildUrl('/anime/$id/news', {});
      final body = await _enqueue(url);
      final data = _extractList(body);
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Get manga details by ID
  static Future<AnimeModel> getMangaById(int id) async {
    final url = _buildMalUrl('/manga/$id', {
      'fields': 'id,title,alternative_titles,main_picture,mean,synopsis,genres,status,media_type,num_volumes,num_chapters,my_list_status'
    });
    final body = await _executeMal(url);
    final data = _extractMap(body);
    return AnimeModel.fromJson(_mapMalToJikan(data));
  }

  /// Get manga characters (Hybrid - kept on Jikan)
  static Future<List<CharacterModel>> getMangaCharacters(int id, {int limit = 10}) async {
    try {
      final url = _buildUrl('/manga/$id/characters', {});
      final body = await _enqueue(url);
      final data = _extractList(body);
      return data
          .take(limit)
          .map((e) => CharacterModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get manga pictures
  static Future<List<String>> getMangaPictures(int id) async {
    try {
      final url = _buildMalUrl('/manga/$id', {'fields': 'pictures'});
      final body = await _executeMal(url);
      final picturesList = body['pictures'] as List?;
      if (picturesList == null) return [];
      return picturesList.map<String>((e) => e['large'] ?? e['medium'] ?? '').where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get manga statistics (Hybrid - kept on Jikan)
  static Future<Map<String, dynamic>?> getMangaStatistics(int id) async {
    try {
      final url = _buildUrl('/manga/$id/statistics', {});
      final body = await _enqueue(url);
      return _extractMap(body);
    } catch (_) {
      return null;
    }
  }

  /// Get manga reviews (Hybrid - kept on Jikan)
  static Future<List<Map<String, dynamic>>> getMangaReviews(int id) async {
    try {
      final url = _buildUrl('/manga/$id/reviews', {});
      final body = await _enqueue(url);
      final data = _extractList(body);
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Get manga news (Hybrid - kept on Jikan)
  static Future<List<Map<String, dynamic>>> getMangaNews(int id) async {
    try {
      final url = _buildUrl('/manga/$id/news', {});
      final body = await _enqueue(url);
      final data = _extractList(body);
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Get anime recommendations
  static Future<List<AnimeModel>> getAnimeRecommendations(int id) async {
    try {
      final url = _buildMalUrl('/anime/$id', {'fields': 'recommendations'});
      final body = await _executeMal(url);
      final recs = body['recommendations'] as List?;
      if (recs == null) return [];
      
      final List<AnimeModel> list = [];
      for (var item in recs.take(10)) {
        final node = item['node'];
        if (node != null) {
          final mapped = _mapMalToJikan(node as Map<String, dynamic>);
          list.add(AnimeModel.fromJson(mapped));
        }
      }
      return _deduplicate(list);
    } catch (_) {
      return [];
    }
  }

  /// Get manga recommendations
  static Future<List<AnimeModel>> getMangaRecommendations(int id) async {
    try {
      final url = _buildMalUrl('/manga/$id', {'fields': 'recommendations'});
      final body = await _executeMal(url);
      final recs = body['recommendations'] as List?;
      if (recs == null) return [];
      
      final List<AnimeModel> list = [];
      for (var item in recs.take(10)) {
        final node = item['node'];
        if (node != null) {
          final mapped = _mapMalToJikan(node as Map<String, dynamic>);
          list.add(AnimeModel.fromJson(mapped));
        }
      }
      return _deduplicate(list);
    } catch (_) {
      return [];
    }
  }

  /// Get authenticated user-specific anime suggestions
  static Future<List<AnimeModel>> getUserSuggestions({int limit = 15, int page = 1}) async {
    try {
      final offset = (page - 1) * limit;
      final url = _buildMalUrl('/anime/suggestions', {
        'fields': _malFields,
        'limit': '$limit',
        'offset': '$offset',
      });
      final body = await _executeMal(url);
      final data = _extractList(body);
      return _deduplicate(data.map((e) => AnimeModel.fromJson(_mapMalToJikan(e as Map<String, dynamic>))).toList());
    } catch (_) {
      return [];
    }
  }
}

class _QueueItem {
  final String url;
  final Completer<dynamic> completer;
  final int retries;

  _QueueItem({
    required this.url,
    required this.completer,
    required this.retries,
  });
}
