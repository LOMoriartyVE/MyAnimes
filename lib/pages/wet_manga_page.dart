import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart' as ww;
import 'package:webview_flutter/webview_flutter.dart' as wf;
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/services/download_manager.dart';
import 'download_manager_page.dart';

class WitMangaPage extends StatefulWidget {
  final String initialUrl;
  final String mangaTitle;
  final String? mangaImageUrl;

  const WitMangaPage({
    super.key,
    required this.initialUrl,
    required this.mangaTitle,
    this.mangaImageUrl,
  });

  @override
  State<WitMangaPage> createState() => _WitMangaPageState();
}

class _WitMangaPageState extends State<WitMangaPage> {
  late final ww.WebviewController _winController;
  late final wf.WebViewController _mobileController;
  bool _isWebviewInitialized = false;

  final Set<String> _downloadedUrls = {};

  // ─────────────────────────────────────────────────────────────────────────
  // JavaScript download interceptor (identical to wet_anime_page)
  // Scrapes real download URLs from hosting sites and sends via postMessage.
  // ─────────────────────────────────────────────────────────────────────────
  static const String _jsDownloadInterceptor = r'''
(function() {
  if (window.__myAnimesInjected) return;
  window.__myAnimesInjected = true;

  function sendDownload(url, ref) {
    if (!url) return;
    try {
      window.chrome.webview.postMessage(JSON.stringify({
        type: 'download',
        url: url,
        referer: ref || window.location.href
      }));
    } catch(e) {}
  }

  var host = window.location.hostname.toLowerCase();

  // ───── MEDIAFIRE ─────
  if (host.includes('mediafire.com')) {
    function grabMediafire() {
      var btn = document.getElementById('downloadButton');
      if (btn && btn.href && btn.href.includes('download')) {
        sendDownload(btn.href, 'https://www.mediafire.com/');
      }
    }
    grabMediafire();
    var mo = new MutationObserver(function() { grabMediafire(); });
    mo.observe(document.body, {childList: true, subtree: true});
    setInterval(grabMediafire, 1500);
  }

  // ───── GOOGLE DRIVE ─────
  if (host.includes('drive.google.com') || host.includes('docs.google.com')) {
    var m = window.location.pathname.match(/\/file\/d\/([^\/]+)/);
    if (m && m[1]) {
      var driveUrl = 'https://drive.google.com/uc?export=download&id=' + m[1];
      sendDownload(driveUrl, 'https://drive.google.com/');
    }
    function grabDriveConfirm() {
      var form = document.getElementById('download-form') || document.querySelector('form[action*="uc?"]');
      if (form && form.action) {
        sendDownload(form.action, 'https://drive.google.com/');
      }
    }
    grabDriveConfirm();
    setTimeout(grabDriveConfirm, 2000);
  }

  // ───── WORKUPLOAD ─────
  if (host.includes('workupload.com')) {
    function grabWorkupload() {
      var btn = document.getElementById('downloadButton') ||
                document.querySelector('a[href*="/download/"]') ||
                document.querySelector('a.btn-download');
      if (btn) {
        var href = btn.href || btn.getAttribute('data-url');
        if (href) {
          sendDownload(href, 'https://workupload.com/');
          return;
        }
      }
      var startBtn = document.querySelector('a[href*="/start/"]');
      if (startBtn && startBtn.href) {
        fetch(startBtn.href, {method:'GET',redirect:'follow'}).then(function(r){
          if (r.url && (r.url.includes('/download/') || r.url.includes('stream.'))) {
            sendDownload(r.url, 'https://workupload.com/');
          }
        }).catch(function(){});
      }
    }
    grabWorkupload();
    var mo2 = new MutationObserver(function() { grabWorkupload(); });
    mo2.observe(document.body, {childList: true, subtree: true});
    setInterval(grabWorkupload, 2000);
  }

  // ───── GOFILE ─────
  if (host.includes('gofile.io')) {
    function grabGofile() {
      var links = document.querySelectorAll('a[href*="/download/"], a[href*="gofile.io/download"]');
      links.forEach(function(a) {
        if (a.href) sendDownload(a.href, 'https://gofile.io/');
      });
      var btns = document.querySelectorAll('[data-link], button.download-btn');
      btns.forEach(function(b) {
        var link = b.getAttribute('data-link');
        if (link) sendDownload(link, 'https://gofile.io/');
      });
    }
    grabGofile();
    var mo3 = new MutationObserver(function() { grabGofile(); });
    mo3.observe(document.body, {childList: true, subtree: true});
    setInterval(grabGofile, 2500);
  }

  // ───── GENERIC click interceptor ─────
  document.addEventListener('click', function(e) {
    var target = e.target;
    while (target && target.tagName !== 'A') {
      target = target.parentNode;
      if (!target || target === document) { target = null; break; }
    }
    if (target && target.href) {
      var href = target.href.toLowerCase();
      if (href.match(/\.(mp4|mkv|avi|zip|rar|pdf|cbz|cbr)(\?|$)/)) {
        e.preventDefault();
        e.stopPropagation();
        sendDownload(target.href, window.location.href);
        return;
      }
      if (href.match(/download\d*\.mediafire\.com\//)) {
        e.preventDefault();
        e.stopPropagation();
        sendDownload(target.href, 'https://www.mediafire.com/');
        return;
      }
      if (href.includes('googleusercontent.com/docs/securesc/')) {
        e.preventDefault();
        e.stopPropagation();
        sendDownload(target.href, 'https://drive.google.com/');
        return;
      }
    }
  }, true);

  // ───── XHR / Fetch interception ─────
  var origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    this._myUrl = url;
    return origOpen.apply(this, arguments);
  };
  var origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function() {
    this.addEventListener('load', function() {
      try {
        if (this.responseURL &&
            (this.responseURL.match(/\.(mp4|mkv|zip|rar|pdf|cbz|cbr)(\?|$)/) ||
             this.responseURL.includes('googleusercontent.com') ||
             this.responseURL.match(/download\d*\.mediafire\.com/))) {
          sendDownload(this.responseURL, window.location.href);
        }
      } catch(e) {}
    });
    return origSend.apply(this, arguments);
  };

  var origFetch = window.fetch;
  window.fetch = function() {
    return origFetch.apply(this, arguments).then(function(response) {
      try {
        var ct = response.headers.get('content-type') || '';
        var cd = response.headers.get('content-disposition') || '';
        if (cd.includes('attachment') || ct.includes('video/') || ct.includes('application/octet-stream')) {
          sendDownload(response.url, window.location.href);
        }
      } catch(e) {}
      return response;
    });
  };

  // ───── Popup blocker + target=_blank rewriter ─────
  window.open = function(url) {
    if (url) window.location.href = url;
    return null;
  };
  setInterval(function() {
    document.querySelectorAll('a[target="_blank"]').forEach(function(a) {
      a.target = '_self';
    });
  }, 500);
})();
''';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    final searchQuery = widget.mangaTitle;
    final witmangaDomain = HiveService.witmangaDomain;
    
    // JS 404 Check
    final jsCheck404 = '''
      (function() {
        function check404() {
          const is404 = document.title.includes('404') || 
                        document.title.includes('الخطأ') || 
                        document.body.innerText.includes('Sorry, page not found!') || 
                        document.body.innerText.includes('الخطأ 404');
          if (is404) {
            const query = encodeURIComponent("$searchQuery");
            window.location.href = "https://$witmangaDomain/?s=" + query;
          }
        }
        check404();
        setTimeout(check404, 500);
        setTimeout(check404, 1500);
      })();
    ''';

    if (Platform.isWindows) {
      try {
        _winController = ww.WebviewController();
        await _winController.initialize();

        await _winController.setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
        );
        
        // Register JS to auto-inject on every new document
        await _winController.addScriptToExecuteOnDocumentCreated(_jsDownloadInterceptor);

        // Listen to webMessage for download URLs sent from injected JS
        _winController.webMessage.listen((message) {
          if (!mounted) return;
          try {
            final data = message is Map ? message : (message is String ? jsonDecode(message) : null);
            if (data == null) return;
            if (data['type'] == 'download') {
              final url = data['url'] as String?;
              if (url != null && url.isNotEmpty && !_downloadedUrls.contains(url)) {
                _downloadedUrls.add(url);
                debugPrint('[MyAnimes] JS intercepted download: $url');
                _startDownload(url);
              }
            }
          } catch (e) {
            debugPrint('webMessage parse error: $e');
          }
        });

        _winController.url.listen((url) {
          if (!mounted) return;
          _winController.executeScript(jsCheck404);
          if (_isPotentialDownload(url)) {
            _winController.stop();
            if (!_downloadedUrls.contains(url)) {
              _downloadedUrls.add(url);
              _startDownload(url);
            }
          }
        });

        await _winController.setBackgroundColor(Colors.transparent);
        await _winController.setPopupWindowPolicy(ww.WebviewPopupWindowPolicy.deny);
        await _winController.loadUrl(widget.initialUrl);

        if (!mounted) return;
        setState(() => _isWebviewInitialized = true);
      } catch (e) {
        debugPrint("Webview init error: $e");
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      try {
        _mobileController = wf.WebViewController()
          ..setJavaScriptMode(wf.JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setUserAgent('Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36')
          ..addJavaScriptChannel('MyAnimesDownload', onMessageReceived: (wf.JavaScriptMessage msg) {
            try {
              final data = jsonDecode(msg.message);
              if (data['type'] == 'download') {
                final url = data['url'] as String?;
                if (url != null && url.isNotEmpty && !_downloadedUrls.contains(url)) {
                  _downloadedUrls.add(url);
                  _startDownload(url);
                }
              }
            } catch (e) {
              debugPrint('JS channel parse error: $e');
            }
          })
          ..setNavigationDelegate(
            wf.NavigationDelegate(
              onPageFinished: (String url) {
                _mobileController.runJavaScript(_jsMobileDownloadInterceptor);
                _mobileController.runJavaScript(jsCheck404);
              },
              onNavigationRequest: (wf.NavigationRequest request) {
                final url = request.url;
                if (_isPotentialDownload(url)) {
                  if (!_downloadedUrls.contains(url)) {
                    _downloadedUrls.add(url);
                    _startDownload(url);
                  }
                  return wf.NavigationDecision.prevent;
                }
                return wf.NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.initialUrl));

        if (!mounted) return;
        setState(() => _isWebviewInitialized = true);
      } catch (e) {
        debugPrint("Webview init error: $e");
      }
    }
  }

  static String get _jsMobileDownloadInterceptor => _jsDownloadInterceptor.replaceAll(
    'window.chrome.webview.postMessage(',
    'MyAnimesDownload.postMessage('
  );

  bool _isPotentialDownload(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('witmanga.') || lowerUrl.contains('witanime.')) return false;
    if (lowerUrl.endsWith('.mp4') || lowerUrl.endsWith('.mkv') || 
        lowerUrl.endsWith('.zip') || lowerUrl.endsWith('.rar') ||
        lowerUrl.endsWith('.pdf') || lowerUrl.endsWith('.cbz') ||
        lowerUrl.contains('.mp4?') || lowerUrl.contains('.mkv?')) {
      return true;
    }
    if (RegExp(r'download\d*\.mediafire\.com/').hasMatch(lowerUrl)) return true;
    if ((lowerUrl.contains('drive.google.com/uc?') || lowerUrl.contains('docs.google.com/uc?')) && lowerUrl.contains('export=download')) return true;
    if (lowerUrl.contains('googleusercontent.com/docs/securesc/')) return true;
    if (lowerUrl.contains('workupload.com/download/') || lowerUrl.contains('stream.workupload.com/')) return true;
    if (lowerUrl.contains('gofile.io/download/') || lowerUrl.contains('gofile.io/stream/') || lowerUrl.contains('.gofile.io/download')) return true;
    return false;
  }

  String _parseJSString(String jsResult) {
    try {
      final decoded = jsonDecode(jsResult);
      if (decoded is String) return decoded;
    } catch (_) {}
    var s = jsResult.trim();
    if (s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }
    return s.replaceAll(r'\"', '"');
  }

  Future<void> _startDownload(String url) async {
    String? cookies;
    String? accountToken;

    if (Platform.isWindows) {
      try {
        final cookieRes = await _winController.executeScript('document.cookie');
        if (cookieRes is String) {
          cookies = _parseJSString(cookieRes);
        }
        final tokenRes = await _winController.executeScript(
          '(function(){try{return localStorage.getItem("accountToken")||"";}catch(e){return "";}})()'
        );
        if (tokenRes is String) {
          accountToken = _parseJSString(tokenRes);
        }
      } catch (e) {
        debugPrint("Failed to get credentials on Windows: $e");
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      try {
        final cookieRes = await _mobileController.runJavaScriptReturningResult('document.cookie');
        if (cookieRes is String) {
          cookies = _parseJSString(cookieRes);
        }
        final tokenRes = await _mobileController.runJavaScriptReturningResult(
          '(function(){try{return localStorage.getItem("accountToken")||"";}catch(e){return "";}})()'
        );
        if (tokenRes is String) {
          accountToken = _parseJSString(tokenRes);
        }
      } catch (e) {
        debugPrint("Failed to get credentials on mobile: $e");
      }
    }

    if (accountToken != null && accountToken.isNotEmpty) {
      if (cookies == null || cookies.isEmpty) {
        cookies = 'accountToken=$accountToken';
      } else {
        if (!cookies.contains('accountToken=')) {
          cookies = '$cookies; accountToken=$accountToken';
        }
      }
    }

    DownloadManager.instance.startDownload(
      url, 
      widget.mangaTitle, 
      imageUrl: widget.mangaImageUrl,
      cookies: cookies,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Started downloading chapter in background!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Open Manager',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DownloadManagerPage()),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      _winController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WitManga Reader'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          // Dynamic Download Manager Button
          ValueListenableBuilder<List<DownloadTask>>(
            valueListenable: DownloadManager.instance.tasksNotifier,
            builder: (context, activeTasks, _) {
              final count = activeTasks.length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.download_for_offline_rounded, size: 24),
                    tooltip: 'Download Manager',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DownloadManagerPage()),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20), 
            onPressed: () {
              if (Platform.isWindows) {
                _winController.reload();
              } else {
                _mobileController.reload();
              }
            }
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18), 
            onPressed: () async {
              if (Platform.isWindows) {
                _winController.goBack();
              } else {
                if (await _mobileController.canGoBack()) {
                  _mobileController.goBack();
                }
              }
            }
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18), 
            onPressed: () async {
              if (Platform.isWindows) {
                _winController.goForward();
              } else {
                if (await _mobileController.canGoForward()) {
                  _mobileController.goForward();
                }
              }
            }
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Downloads Floating Bar
          ValueListenableBuilder<List<DownloadTask>>(
            valueListenable: DownloadManager.instance.tasksNotifier,
            builder: (context, activeTasks, _) {
              if (activeTasks.isEmpty) return const SizedBox.shrink();
              return Container(
                color: AppColors.accent.withOpacity(0.15),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${activeTasks.length} chapters downloading in background...',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DownloadManagerPage()),
                        );
                      },
                      child: Text(
                        'View Tasks',
                        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: _isWebviewInitialized
                ? (Platform.isWindows 
                    ? ww.Webview(_winController) 
                    : wf.WebViewWidget(controller: _mobileController))
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}
