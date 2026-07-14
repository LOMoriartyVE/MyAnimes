import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'hive_service.dart';

enum DownloadStatus { downloading, completed, failed, paused }

class DownloadTask {
  final String id;
  final String url;
  final String title;
  
  String fileName;
  String savePath;
  final String? imageUrl;
  
  double progress;
  String speed;
  String fileSize;
  DownloadStatus status;
  String? error;
  CancelToken? cancelToken;

  DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.fileName,
    required this.savePath,
    this.imageUrl,
    this.progress = 0.0,
    this.speed = '0.0 MB/s',
    this.fileSize = 'Unknown',
    this.status = DownloadStatus.downloading,
    this.error,
    this.cancelToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'fileName': fileName,
      'savePath': savePath,
      'imageUrl': imageUrl,
      'progress': progress,
      'speed': speed,
      'fileSize': fileSize,
      'status': status.index,
      'error': error,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      url: json['url'] as String,
      title: json['title'] as String,
      fileName: json['fileName'] as String,
      savePath: json['savePath'] as String,
      imageUrl: json['imageUrl'] as String?,
      progress: (json['progress'] as num).toDouble(),
      speed: json['speed'] as String,
      fileSize: json['fileSize'] as String,
      status: DownloadStatus.values[json['status'] as int],
      error: json['error'] as String?,
    );
  }
}

class DownloadManager {
  DownloadManager._() {
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );
  }
  static final DownloadManager instance = DownloadManager._();

  static const String _chromeUserAgent = 
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 25),
    receiveTimeout: const Duration(minutes: 30),
    headers: {
      'User-Agent': _chromeUserAgent,
      'Accept': '*/*',
      'Accept-Encoding': 'identity', // Ensure raw stream with Content-Length is sent
      'Connection': 'keep-alive',
    },
    followRedirects: true,
    maxRedirects: 5,
  ));

  final ValueNotifier<List<DownloadTask>> tasksNotifier = ValueNotifier<List<DownloadTask>>([]);
  
  // Completed downloads from Hive (in-memory cache for quick access)
  final ValueNotifier<List<DownloadTask>> completedTasksNotifier = ValueNotifier<List<DownloadTask>>([]);

  void init() {
    // Load completed downloads from Hive
    final completed = HiveService.getCompletedDownloads();
    completedTasksNotifier.value = completed.map((m) => DownloadTask.fromJson(m)).toList();
  }

  Future<void> startDownload(String url, String animeTitle, {String? imageUrl, String? cookies, String? referer}) async {
    // Check if download is already in queue
    final alreadyActive = tasksNotifier.value.any((t) => t.url == url && t.status == DownloadStatus.downloading);
    if (alreadyActive) return;

    // Generate safe initial filename
    String fileName = url.split('/').last.split('?').first;
    if (fileName.isEmpty || fileName.length < 4) {
      fileName = '${animeTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '')}.mp4';
    } else {
      fileName = Uri.decodeComponent(fileName);
      if (!fileName.endsWith('.mp4') && !fileName.endsWith('.mkv') && !fileName.endsWith('.zip') && !fileName.endsWith('.rar')) {
        fileName = '$fileName.mp4';
      }
    }

    // Build save path
    String? rootPath = HiveService.localAnimeFolder;
    if (rootPath == null) {
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          rootPath = downloadsDir.path;
        } else {
          final docs = await getApplicationDocumentsDirectory();
          rootPath = docs.path;
        }
      } catch (_) {
        final docs = await getApplicationDocumentsDirectory();
        rootPath = docs.path;
      }
    }
    
    final watchingDir = Directory('$rootPath${Platform.pathSeparator}Watching Animes');
    if (!await watchingDir.exists()) await watchingDir.create(recursive: true);

    final cleanTitle = animeTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
    final animeDir = Directory('${watchingDir.path}${Platform.pathSeparator}$cleanTitle');
    if (!await animeDir.exists()) await animeDir.create(recursive: true);

    final savePath = '${animeDir.path}${Platform.pathSeparator}$fileName';

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final cancelToken = CancelToken();

    final task = DownloadTask(
      id: id,
      url: url,
      title: animeTitle,
      fileName: fileName,
      savePath: savePath,
      imageUrl: imageUrl,
      cancelToken: cancelToken,
    );

    // Add to active tasks
    tasksNotifier.value = [...tasksNotifier.value, task];

    // Background Download
    _executeDownload(task, cookies: cookies, referer: referer);
  }

  Future<String> _resolveGoogleDriveUrl(String url, {String? cookies}) async {
    if (!url.contains('drive.google.com') && !url.contains('docs.google.com')) return url;
    if (url.contains('confirm=')) return url; // Already resolved
    
    String exportUrl = url;
    if (url.contains('/file/d/')) {
      final parts = url.split('/file/d/');
      if (parts.length > 1) {
        final id = parts[1].split('/')[0];
        exportUrl = 'https://drive.google.com/uc?export=download&id=$id';
      }
    }

    try {
      final headers = <String, dynamic>{
        'User-Agent': _chromeUserAgent,
      };
      if (cookies != null && cookies.isNotEmpty) {
        headers['Cookie'] = cookies;
      }

      // Use stream response type to avoid downloading the whole file if it's direct!
      final response = await _dio.get<ResponseBody>(
        exportUrl,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
        ),
      );
      
      final contentType = response.headers.value('content-type') ?? '';
      if (!contentType.contains('text/html')) {
        // It's already a direct download stream!
        return exportUrl;
      }
      
      // Read stream as string to parse confirm token
      final transformer = utf8.decoder;
      final body = await transformer.bind(response.data!.stream).join();
      
      final match = RegExp(r'confirm=([a-zA-Z0-9-_]+)').firstMatch(body);
      if (match != null) {
        final confirmToken = match.group(1);
        final idMatch = RegExp(r'id=([a-zA-Z0-9-_]+)').firstMatch(exportUrl) ?? RegExp(r'id=([a-zA-Z0-9-_]+)').firstMatch(body);
        if (idMatch != null) {
          final id = idMatch.group(1);
          return 'https://drive.google.com/uc?export=download&confirm=$confirmToken&id=$id';
        }
      }
    } catch (e) {
      debugPrint("Error resolving Google Drive: $e");
    }
    
    return exportUrl;
  }

  Future<void> _executeDownload(DownloadTask task, {String? cookies, String? referer}) async {
    int lastBytes = 0;
    DateTime lastTime = DateTime.now();
    
    // Create temporary download file path to avoid conflict/corruption
    final tempSavePath = '${task.savePath}.tmp';

    try {
      // 1. Resolve URLs if they are from Google Drive
      String downloadUrl = task.url;
      if (downloadUrl.contains('drive.google.com') || downloadUrl.contains('docs.google.com')) {
        downloadUrl = await _resolveGoogleDriveUrl(downloadUrl, cookies: cookies);
      }

      // 2. Set Referer/Cookie headers for hosts
      final headers = <String, dynamic>{
        'User-Agent': _chromeUserAgent,
      };
      if (cookies != null && cookies.isNotEmpty) {
        headers['Cookie'] = cookies;
      }

      if (referer != null && referer.isNotEmpty) {
        headers['Referer'] = referer;
      } else {
        if (downloadUrl.contains('mediafire.com')) {
          headers['Referer'] = 'https://www.mediafire.com/';
        } else if (downloadUrl.contains('drive.google.com') || downloadUrl.contains('docs.google.com')) {
          headers['Referer'] = 'https://drive.google.com/';
        } else {
          // Automatic fallback Referer based on the host URL to support other download servers (workupload, gofile, etc)
          try {
            final uri = Uri.parse(downloadUrl);
            headers['Referer'] = '${uri.scheme}://${uri.host}/';
          } catch (_) {
            headers['Referer'] = downloadUrl;
          }
        }
      }

      // 3. Start download request
      final response = await _dio.download(
        downloadUrl,
        tempSavePath,
        cancelToken: task.cancelToken,
        options: Options(headers: headers),
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final diffMs = now.difference(lastTime).inMilliseconds;

          if (total != -1) {
            task.fileSize = _formatBytes(total);
            task.progress = received / total;
          } else {
            task.progress = -1.0; // Indeterminate
            task.fileSize = '${_formatBytes(received)} / Unknown';
          }

          if (diffMs >= 800) {
            final bytesSinceLast = received - lastBytes;
            final speedBps = (bytesSinceLast / diffMs) * 1000;
            final speedMbps = speedBps / (1024 * 1024);
            
            task.speed = '${speedMbps.toStringAsFixed(1)} MB/s';
            lastBytes = received;
            lastTime = now;

            if (total != -1) {
              task.fileSize = _formatBytes(total);
            } else {
              task.fileSize = '${_formatBytes(received)} / Unknown';
            }

            // Notify update
            tasksNotifier.value = [...tasksNotifier.value];
          } else if (task.progress == 0.0) {
            tasksNotifier.value = [...tasksNotifier.value];
          }
        },
      );

      // Check if file downloaded is actually an HTML page or extremely small
      final tempFile = File(tempSavePath);
      if (!tempFile.existsSync()) {
        throw Exception('Download file was not created.');
      }

      final fileSize = tempFile.lengthSync();
      if (fileSize < 1024 * 150) { // 150 KB
        final content = await tempFile.readAsString().catchError((_) => '');
        if (content.trim().startsWith('<html') || 
            content.trim().startsWith('<!doc') || 
            content.trim().startsWith('<!DOC') ||
            content.contains('window.location.href')) {
          throw Exception('The link returned a web page (e.g. ad page or verification/virus page) instead of the video file.');
        }
      }

      // 4. Extract content-disposition to rename file if possible
      String finalFileName = task.fileName;
      final disposition = response.headers.value('content-disposition');
      if (disposition != null) {
        final regExp = RegExp(r'filename="?([^";]+)"?');
        final match = regExp.firstMatch(disposition);
        if (match != null) {
          finalFileName = Uri.decodeComponent(match.group(1)!);
        }
      }

      // Rename from .tmp to final path
      final animeDir = Directory(task.savePath).parent;
      final finalPath = '${animeDir.path}${Platform.pathSeparator}$finalFileName';
      
      // Delete existing file if exists
      final destFile = File(finalPath);
      if (destFile.existsSync()) {
        destFile.deleteSync();
      }
      
      await tempFile.rename(finalPath);

      // Update task fields
      task.fileName = finalFileName;
      task.savePath = finalPath;
      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      task.speed = 'Finished';
      task.fileSize = _formatBytes(fileSize);
      task.cancelToken = null;

      // Remove from active tasks, add to completed box in Hive & in-memory completed notifier
      tasksNotifier.value = tasksNotifier.value.where((t) => t.id != task.id).toList();
      await HiveService.addCompletedDownload(task.toJson());
      completedTasksNotifier.value = [...completedTasksNotifier.value, task];
    } catch (e) {
      // Clean up tmp file
      final tempFile = File(tempSavePath);
      if (tempFile.existsSync()) {
        try { tempFile.deleteSync(); } catch (_) {}
      }

      if (e is DioException && CancelToken.isCancel(e)) {
        task.status = DownloadStatus.paused;
        task.speed = 'Paused';
      } else {
        task.status = DownloadStatus.failed;
        task.speed = 'Failed';
        // Human-friendly error
        final errStr = e.toString();
        if (errStr.contains('HTML') || errStr.contains('web page')) {
          task.error = 'Invalid Link: Server returned an HTML web page instead of a file.';
        } else if (e is DioException) {
          final statusCode = e.response?.statusCode;
          if (statusCode != null) {
            task.error = 'Server error: HTTP $statusCode';
          } else if (e.type == DioExceptionType.connectionTimeout) {
            task.error = 'Connection timed out. Check your internet connection.';
          } else if (e.type == DioExceptionType.receiveTimeout) {
            task.error = 'Download timed out. The server stopped responding.';
          } else {
            task.error = errStr.replaceAll('DioException', '').replaceAll('Exception:', '').trim();
          }
        } else {
          task.error = errStr.replaceAll('Exception:', '').trim();
        }
      }
      task.cancelToken = null;
      tasksNotifier.value = [...tasksNotifier.value];
    }
  }

  void pauseDownload(String id) {
    try {
      final task = tasksNotifier.value.firstWhere((t) => t.id == id);
      task.cancelToken?.cancel();
    } catch (_) {}
  }

  void resumeDownload(String id) {
    try {
      final task = tasksNotifier.value.firstWhere((t) => t.id == id);
      if (task.status == DownloadStatus.paused || task.status == DownloadStatus.failed) {
        task.status = DownloadStatus.downloading;
        task.speed = 'Connecting...';
        task.cancelToken = CancelToken();
        tasksNotifier.value = [...tasksNotifier.value];
        _executeDownload(task);
      }
    } catch (_) {}
  }

  void cancelDownload(String id) {
    try {
      final task = tasksNotifier.value.firstWhere((t) => t.id == id);
      task.cancelToken?.cancel();
      
      final file = File(task.savePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
      final tempFile = File('${task.savePath}.tmp');
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    } catch (_) {}
    tasksNotifier.value = tasksNotifier.value.where((t) => t.id != id).toList();
  }

  Future<void> deleteCompleted(String id) async {
    try {
      final task = completedTasksNotifier.value.firstWhere((t) => t.id == id);
      final file = File(task.savePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
    await HiveService.deleteCompletedDownload(id);
    completedTasksNotifier.value = completedTasksNotifier.value.where((t) => t.id != id).toList();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return '${dBytes.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
