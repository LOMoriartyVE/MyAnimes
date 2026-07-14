import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'hive_service.dart';

class MalAuthService {
  static final MalAuthService instance = MalAuthService._internal();
  MalAuthService._internal();

  static String get _clientId => dotenv.env['CLIENT_ID'] ?? '';
  static const String _redirectUri = 'http://localhost';

  final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(HiveService.malAccessToken != null);

  bool get isLoggedIn => HiveService.malAccessToken != null;

  /// Generates PKCE code verifier (random 128 characters)
  String generateCodeVerifier() {
    final random = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    return List.generate(128, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Constructs the MyAnimeList OAuth authorization URL
  String getAuthorizeUrl(String codeChallenge) {
    return 'https://myanimelist.net/v1/oauth2/authorize'
        '?response_type=code'
        '&client_id=$_clientId'
        '&code_challenge=$codeChallenge'
        '&code_challenge_method=plain'
        '&redirect_uri=${Uri.encodeComponent(_redirectUri)}';
  }

  /// Exchanges authorization code for access and refresh tokens
  Future<bool> exchangeCodeForToken(String code, String codeVerifier) async {
    try {
      final response = await http.post(
        Uri.parse('https://myanimelist.net/v1/oauth2/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'MyAnimes/1.1.70 (Flutter; Windows/Android)',
        },
        body: {
          'client_id': _clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'code_verifier': codeVerifier,
          'redirect_uri': _redirectUri,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;
        final expiresIn = data['expires_in'] as int;

        final expiryTime = DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;

        await HiveService.setMalAccessToken(accessToken);
        await HiveService.setMalRefreshToken(refreshToken);
        await HiveService.setMalTokenExpiry(expiryTime);

        // Fetch username
        await fetchAndSaveUsername(accessToken);

        isLoggedInNotifier.value = true;
        return true;
      } else {
        debugPrint('Token exchange failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Token exchange exception: $e');
      return false;
    }
  }

  /// Refreshes the MyAnimeList OAuth token using refresh token
  Future<bool> refreshToken() async {
    final rToken = HiveService.malRefreshToken;
    if (rToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('https://myanimelist.net/v1/oauth2/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'MyAnimes/1.1.70 (Flutter; Windows/Android)',
        },
        body: {
          'client_id': _clientId,
          'grant_type': 'refresh_token',
          'refresh_token': rToken,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;
        final expiresIn = data['expires_in'] as int;

        final expiryTime = DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;

        await HiveService.setMalAccessToken(accessToken);
        await HiveService.setMalRefreshToken(refreshToken);
        await HiveService.setMalTokenExpiry(expiryTime);

        isLoggedInNotifier.value = true;
        return true;
      } else {
        debugPrint('Token refresh failed: ${response.statusCode} - ${response.body}');
        await logout();
        return false;
      }
    } catch (e) {
      debugPrint('Token refresh exception: $e');
      return false;
    }
  }

  /// Ensures a valid token is available, refreshing if expired
  Future<String?> getValidAccessToken() async {
    final token = HiveService.malAccessToken;
    if (token == null) return null;

    final expiry = HiveService.malTokenExpiry;
    if (expiry != null) {
      // Refresh token if it expires in less than 5 minutes
      final bufferTime = DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch;
      if (expiry < bufferTime) {
        final success = await refreshToken();
        if (success) {
          return HiveService.malAccessToken;
        }
        return null;
      }
    }
    return token;
  }

  /// Fetches authenticated user info and saves the username and picture
  Future<void> fetchAndSaveUsername(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.myanimelist.net/v2/users/@me?fields=picture'),
        headers: {
          'Authorization': 'Bearer $token',
          'User-Agent': 'MyAnimes/1.1.70 (Flutter; Windows/Android)',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final name = data['name'] as String?;
        await HiveService.setMalUsername(name);
        
        // Extract picture URL if present (can be string or Map)
        String? pictureUrl;
        final pic = data['picture'];
        if (pic != null) {
          if (pic is Map) {
            pictureUrl = pic['large']?.toString() ?? pic['medium']?.toString();
          } else if (pic is String) {
            pictureUrl = pic;
          }
        }
        await HiveService.setMalUserPicture(pictureUrl);
      }
    } catch (e) {
      debugPrint('Failed to fetch user profile: $e');
    }
  }

  /// Logs out the user and clears all credentials
  Future<void> logout() async {
    await HiveService.setMalAccessToken(null);
    await HiveService.setMalRefreshToken(null);
    await HiveService.setMalTokenExpiry(null);
    await HiveService.setMalUsername(null);
    await HiveService.setMalUserPicture(null);
    isLoggedInNotifier.value = false;
  }

  // ── Sync list actions directly to MAL account ──

  /// Updates anime progress on official MyAnimeList profile
  Future<bool> updateAnimeProgress(
    int animeId, {
    String? status,
    int? numWatchedEpisodes,
    int? score,
  }) async {
    final token = await getValidAccessToken();
    if (token == null) return false;

    final body = <String, String>{};
    if (status != null) {
      // MAL status values: watching, completed, on_hold, dropped, plan_to_watch
      body['status'] = _mapCategoryToMalStatus(status);
    }
    if (numWatchedEpisodes != null) {
      body['num_watched_episodes'] = '$numWatchedEpisodes';
    }
    if (score != null) {
      body['score'] = '$score';
    }

    if (body.isEmpty) return true;

    try {
      final response = await http.put(
        Uri.parse('https://api.myanimelist.net/v2/anime/$animeId/my_list_status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'MyAnimes/1.1.70 (Flutter; Windows/Android)',
        },
        body: body,
      ).timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating MAL anime progress: $e');
      return false;
    }
  }

  /// Updates manga progress on official MyAnimeList profile
  Future<bool> updateMangaProgress(
    int mangaId, {
    String? status,
    int? numChaptersRead,
    int? numVolumesRead,
    int? score,
  }) async {
    final token = await getValidAccessToken();
    if (token == null) return false;

    final body = <String, String>{};
    if (status != null) {
      body['status'] = _mapCategoryToMalStatus(status);
    }
    if (numChaptersRead != null) {
      body['num_chapters_read'] = '$numChaptersRead';
    }
    if (numVolumesRead != null) {
      body['num_volumes_read'] = '$numVolumesRead';
    }
    if (score != null) {
      body['score'] = '$score';
    }

    if (body.isEmpty) return true;

    try {
      final response = await http.put(
        Uri.parse('https://api.myanimelist.net/v2/manga/$mangaId/my_list_status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'MyAnimes/1.1.70 (Flutter; Windows/Android)',
        },
        body: body,
      ).timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating MAL manga progress: $e');
      return false;
    }
  }

  /// Removes anime from MAL user list
  Future<bool> deleteAnimeFromList(int animeId) async {
    final token = await getValidAccessToken();
    if (token == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('https://api.myanimelist.net/v2/anime/$animeId/my_list_status'),
        headers: {
          'Authorization': 'Bearer $token',
          'User-Agent': 'MyAnimes/1.1.70 (Flutter; Windows/Android)',
        },
      );
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      debugPrint('Error deleting MAL anime: $e');
      return false;
    }
  }

  /// Removes manga from MAL user list
  Future<bool> deleteMangaFromList(int mangaId) async {
    final token = await getValidAccessToken();
    if (token == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('https://api.myanimelist.net/v2/manga/$mangaId/my_list_status'),
        headers: {
          'Authorization': 'Bearer $token',
          'User-Agent': 'MyAnimes/1.1.70 (Flutter; Windows/Android)',
        },
      );
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      debugPrint('Error deleting MAL manga: $e');
      return false;
    }
  }

  String _mapCategoryToMalStatus(String category) {
    switch (category.toLowerCase()) {
      case 'watching':
      case 'reading':
        return 'watching';
      case 'completed':
        return 'completed';
      case 'on_hold':
      case 'onhold':
        return 'on_hold';
      case 'dropped':
        return 'dropped';
      case 'plan_to_watch':
      case 'plantowatch':
      case 'plan_to_read':
      case 'plantoread':
        return 'plan_to_watch';
      default:
        return 'plan_to_watch';
    }
  }

  /// Fetches the user's anime list from MyAnimeList
  Future<List<Map<String, dynamic>>> getUserAnimeList() async {
    final token = await getValidAccessToken();
    if (token == null) return [];

    final list = <Map<String, dynamic>>[];
    int offset = 0;
    bool hasNext = true;

    while (hasNext) {
      try {
        final response = await http.get(
          Uri.parse('https://api.myanimelist.net/v2/users/@me/animelist?limit=100&offset=$offset&fields=list_status,alternative_titles,main_picture,mean,synopsis,genres,status,media_type,num_episodes,start_season,studios'),
          headers: {
            'Authorization': 'Bearer $token',
            'User-Agent': 'MyAnimes/1.1.70 (Flutter; Windows/Android)',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final items = data['data'] as List?;
          if (items != null && items.isNotEmpty) {
            for (var item in items) {
              final node = item['node'] as Map<String, dynamic>;
              final listStatus = item['list_status'] as Map<String, dynamic>;
              list.add({
                'node': node,
                'list_status': listStatus,
              });
            }
            offset += 100;
            hasNext = data['paging']?['next'] != null;
          } else {
            hasNext = false;
          }
        } else {
          hasNext = false;
        }
      } catch (e) {
        debugPrint('Error fetching user MAL animelist: $e');
        hasNext = false;
      }
    }
    return list;
  }

  /// Fetches the user's manga list from MyAnimeList
  Future<List<Map<String, dynamic>>> getUserMangaList() async {
    final token = await getValidAccessToken();
    if (token == null) return [];

    final list = <Map<String, dynamic>>[];
    int offset = 0;
    bool hasNext = true;

    while (hasNext) {
      try {
        final response = await http.get(
          Uri.parse('https://api.myanimelist.net/v2/users/@me/mangalist?limit=100&offset=$offset&fields=list_status,alternative_titles,main_picture,mean,synopsis,genres,status,media_type,num_volumes,num_chapters'),
          headers: {
            'Authorization': 'Bearer $token',
            'User-Agent': 'MyAnimes/1.1.70 (Flutter; Windows/Android)',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final items = data['data'] as List?;
          if (items != null && items.isNotEmpty) {
            for (var item in items) {
              final node = item['node'] as Map<String, dynamic>;
              final listStatus = item['list_status'] as Map<String, dynamic>;
              list.add({
                'node': node,
                'list_status': listStatus,
              });
            }
            offset += 100;
            hasNext = data['paging']?['next'] != null;
          } else {
            hasNext = false;
          }
        } else {
          hasNext = false;
        }
      } catch (e) {
        debugPrint('Error fetching user MAL mangelist: $e');
        hasNext = false;
      }
    }
    return list;
  }
}
