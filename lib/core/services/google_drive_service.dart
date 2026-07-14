import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:http/http.dart' as http;
import 'hive_service.dart';

class AuthenticatedClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _inner = http.Client();

  AuthenticatedClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }
}

class GoogleDriveService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope, // Use hidden appdata folder
    ],
  );

  static GoogleSignInAccount? _currentUser;

  /// Get the current signed-in user account email or status.
  static String? get userEmail {
    if (Platform.isWindows) {
      return HiveService.getWindowsDriveEmail();
    }
    return _currentUser?.email;
  }

  /// Get the current signed-in user account.
  static GoogleSignInAccount? get currentUser => _currentUser;

  /// Check if a user is currently signed in.
  static bool get isSignedIn {
    if (Platform.isWindows) {
      return HiveService.getWindowsDriveAccessToken() != null;
    }
    return _currentUser != null;
  }

  /// Sign in the user (supports Mobile and Windows).
  static Future<dynamic> signIn() async {
    if (Platform.isWindows) {
      return await _signInWindows();
    }

    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      debugPrint('Google Sign-in failed: $e');
      return null;
    }
  }

  /// Windows OAuth2 Loopback Authentication Flow
  static Future<bool> _signInWindows() async {
    HttpServer? server;
    try {
      // 1. Bind loopback server to a random available port
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      // 2. Build OAuth authorization URL with proper URL encoding
      final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': '209786026743-45r5mu5dukhcgic5734ailo9trqip5fh.apps.googleusercontent.com',
        'redirect_uri': 'http://localhost:$port',
        'response_type': 'code',
        'scope': 'https://www.googleapis.com/auth/drive.appdata https://www.googleapis.com/auth/userinfo.email',
      });

      // 3. Open user's default browser
      await url_launcher.launchUrl(authUri, mode: url_launcher.LaunchMode.externalApplication);

      // 4. Listen for redirection containing the auth code
      String? authCode;
      await for (final request in server) {
        final uri = request.uri;
        if (uri.queryParameters.containsKey('code')) {
          authCode = uri.queryParameters['code'];
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write('''
              <html>
                <head>
                  <title>Authentication Successful</title>
                  <style>
                    body { font-family: sans-serif; text-align: center; padding-top: 50px; background-color: #0F1117; color: #ffffff; }
                    h1 { color: #8F8CFF; }
                    .container { border: 1px solid #2A2D3A; display: inline-block; padding: 30px; border-radius: 12px; background-color: #161925; }
                  </style>
                </head>
                <body>
                  <div class="container">
                    <h1>Authentication Successful!</h1>
                    <p>You can close this tab and return to the MyAnimes app.</p>
                  </div>
                </body>
              </html>
            ''');
          await request.response.close();
          break;
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found');
          await request.response.close();
        }
      }

      if (authCode == null) return false;

      // 5. Exchange code for access & refresh tokens
      final tokenResponse = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': '209786026743-45r5mu5dukhcgic5734ailo9trqip5fh.apps.googleusercontent.com',
          'client_secret': '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',
          'code': authCode,
          'grant_type': 'authorization_code',
          'redirect_uri': 'http://localhost:$port',
        },
      );

      if (tokenResponse.statusCode == 200) {
        final tokenData = json.decode(tokenResponse.body);
        final accessToken = tokenData['access_token'];
        final refreshToken = tokenData['refresh_token'] ?? '';
        final expiresIn = tokenData['expires_in'] as int;
        final expiry = DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;

        // Fetch user email using userinfo endpoint
        String email = 'Windows User';
        final userinfoResponse = await http.get(
          Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        if (userinfoResponse.statusCode == 200) {
          final userData = json.decode(userinfoResponse.body);
          email = userData['email'] ?? 'Windows User';
        }

        await HiveService.setWindowsDriveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiry: expiry,
          email: email,
        );
        return true;
      } else {
        debugPrint('Token exchange failed: ${tokenResponse.statusCode} - ${tokenResponse.body}');
      }
      return false;
    } catch (e) {
      debugPrint('Windows OAuth failed: $e');
      return false;
    } finally {
      await server?.close();
    }
  }

  /// Sign out the user.
  static Future<void> signOut() async {
    if (Platform.isWindows) {
      await HiveService.clearWindowsDriveTokens();
      return;
    }
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Google Sign-out failed: $e');
    }
  }

  /// Silently try to sign in (check if already authorized).
  static Future<dynamic> signInSilently() async {
    if (Platform.isWindows) {
      return await _getWindowsAccessToken();
    }

    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser;
    } catch (e) {
      debugPrint('Google Silent Sign-in failed: $e');
      return null;
    }
  }

  /// Get / Refresh Windows Access Token
  static Future<String?> _getWindowsAccessToken() async {
    final expiry = HiveService.getWindowsDriveExpiry();
    final refreshToken = HiveService.getWindowsDriveRefreshToken();
    var accessToken = HiveService.getWindowsDriveAccessToken();

    if (accessToken == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    // Check if token expired or about to expire (with a 1-minute buffer)
    if (expiry != null && now > (expiry - 60000) && refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('https://oauth2.googleapis.com/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'client_id': '209786026743-45r5mu5dukhcgic5734ailo9trqip5fh.apps.googleusercontent.com',
            'client_secret': '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',
            'refresh_token': refreshToken,
            'grant_type': 'refresh_token',
          },
        );

        if (response.statusCode == 200) {
          final tokenData = json.decode(response.body);
          accessToken = tokenData['access_token'];
          final expiresIn = tokenData['expires_in'] as int;
          final newExpiry = DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;

          await HiveService.setWindowsDriveTokens(
            accessToken: accessToken!,
            refreshToken: refreshToken,
            expiry: newExpiry,
            email: HiveService.getWindowsDriveEmail() ?? 'Windows User',
          );
        } else {
          await signOut();
          return null;
        }
      } catch (e) {
        debugPrint('Failed to refresh token: $e');
        return null;
      }
    }

    return accessToken;
  }

  /// Get authenticated HTTP client.
  static Future<drive.DriveApi?> _getDriveApi() async {
    if (Platform.isWindows) {
      final token = await _getWindowsAccessToken();
      if (token == null) return null;
      final client = AuthenticatedClient(token);
      return drive.DriveApi(client);
    }

    final account = _currentUser ?? await signInSilently();
    if (account == null) return null;

    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;

    return drive.DriveApi(client);
  }

  /// Export Hive data as a JSON file and upload it to Google Drive.
  static Future<bool> uploadBackup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      // 1. Prepare backup payload using existing HiveService exporter
      final jsonContent = await HiveService.exportAsJson();
      debugPrint('uploadBackup: Uploading JSON content: $jsonContent');
      final bytes = utf8.encode(jsonContent);
      final media = drive.Media(Stream.value(bytes), bytes.length);

      // 2. Search if file already exists in appDataFolder
      final fileList = await driveApi.files.list(
        q: "name = 'my_animes_backup.json'",
        spaces: 'appDataFolder',
      );

      final files = fileList.files;
      final driveFile = drive.File()
        ..name = 'my_animes_backup.json'
        ..parents = ['appDataFolder'];

      if (files != null && files.isNotEmpty) {
        // Update existing backup file
        final fileId = files.first.id!;
        await driveApi.files.update(
          drive.File()..name = 'my_animes_backup.json',
          fileId,
          uploadMedia: media,
        );
      } else {
        // Create new backup file
        await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Google Drive Upload failed: $e');
      return false;
    }
  }

  /// Download backup from Google Drive and restore it to Hive.
  static Future<bool> downloadAndRestoreBackup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      // 1. Search for the backup file
      final fileList = await driveApi.files.list(
        q: "name = 'my_animes_backup.json'",
        spaces: 'appDataFolder',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) {
        debugPrint('No backup file found on Google Drive.');
        return false;
      }

      final fileId = files.first.id!;

      // 2. Download file content
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataBytes = [];
      await for (final chunk in response.stream) {
        dataBytes.addAll(chunk);
      }

      final jsonString = utf8.decode(dataBytes);
      debugPrint('downloadAndRestoreBackup: Downloaded JSON content: $jsonString');

      // 3. Restore data to Hive using existing HiveService exporter
      await HiveService.importFromJson(jsonString);
      return true;
    } catch (e) {
      debugPrint('Google Drive Restore failed: $e');
      return false;
    }
  }
}
