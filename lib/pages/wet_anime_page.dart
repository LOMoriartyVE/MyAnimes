import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart' as ww;
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/services/download_manager.dart';
import '../core/services/storage_permission_helper.dart';
import 'download_manager_page.dart';

class WitAnimePage extends StatefulWidget {
  final String initialUrl;
  final String animeTitle;
  final String? animeImageUrl;

  const WitAnimePage({
    super.key,
    required this.initialUrl,
    required this.animeTitle,
    this.animeImageUrl,
  });

  @override
  State<WitAnimePage> createState() => _WitAnimePageState();
}

class _WitAnimePageState extends State<WitAnimePage> {
  late final ww.WebviewController _winController;
  late final wf.WebViewController _mobileController;
  bool _isWebviewInitialized = false;
  String _currentWebpageUrl = '';

  // Track URLs we've already triggered downloads for to avoid duplicates
  final Set<String> _downloadedUrls = {};

  @override
  void initState() {
    super.initState();
    _currentWebpageUrl = widget.initialUrl;
    initPlatformState();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // JavaScript that runs on EVERY page the webview navigates to.
  // It does two things:
  //   1. Intercepts clicks on download buttons/links on file-hosting sites
  //      and sends the real direct-download URL to Flutter via postMessage.
  //   2. Rewrites target=_blank to _self and blocks popup windows.
  //
  // For each hosting service we scrape the actual download URL from the DOM
  // because the webview_windows package does NOT fire url-change events for
  // Content-Disposition: attachment responses.
  // ─────────────────────────────────────────────────────────────────────────
  static const String _jsDownloadInterceptor = r'''
(function() {
  if (window.__myAnimesInjected) return;
  window.__myAnimesInjected = true;

  var _sentUrls = {};
  function sendDownload(url, ref) {
    if (!url) return;
    // Deduplicate: never send the same URL twice
    if (_sentUrls[url]) return;
    _sentUrls[url] = true;
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
  // Only intercept when the user CLICKS the download button — don't auto-send.
  if (host.includes('mediafire.com')) {
    function hookMediafireButton() {
      var btn = document.getElementById('downloadButton');
      if (btn && !btn.__myAnimesHooked) {
        btn.__myAnimesHooked = true;
        btn.addEventListener('click', function(e) {
          var href = btn.href || btn.getAttribute('href');
          if (href && (href.includes('download') || href.match(/download\d*\.mediafire\.com/))) {
            if (!href.includes('/file/')) {
              e.preventDefault();
              e.stopPropagation();
              sendDownload(href, 'https://www.mediafire.com/');
            }
          }
        }, true);
      }
    }
    hookMediafireButton();
    var targetMf = document.documentElement || document.body || document;
    if (targetMf) {
      var mo = new MutationObserver(function() { hookMediafireButton(); });
      mo.observe(targetMf, {childList: true, subtree: true});
    }
    setInterval(hookMediafireButton, 2000);
  }

  // ───── GOOGLE DRIVE ─────
  // /file/d/ID/view — only send when user clicks the download button
  if (host.includes('drive.google.com') || host.includes('docs.google.com')) {
    function hookDriveButton() {
      // Google Drive "download" button or form
      var form = document.getElementById('download-form') || document.querySelector('form[action*="uc?"]');
      if (form && !form.__myAnimesHooked) {
        form.__myAnimesHooked = true;
        form.addEventListener('submit', function(e) {
          e.preventDefault();
          sendDownload(form.action, 'https://drive.google.com/');
        });
      }
      // Also hook any download link/button
      var btns = document.querySelectorAll('a[href*="export=download"], [data-id][aria-label*="ownload"]');
      btns.forEach(function(btn) {
        if (btn.__myAnimesHooked) return;
        btn.__myAnimesHooked = true;
        btn.addEventListener('click', function(e) {
          var m = window.location.pathname.match(/\/file\/d\/([^\/]+)/);
          if (m && m[1]) {
            e.preventDefault();
            e.stopPropagation();
            sendDownload('https://drive.google.com/uc?export=download&id=' + m[1], 'https://drive.google.com/');
          }
        }, true);
      });
    }
    hookDriveButton();
    setTimeout(hookDriveButton, 2000);
    setTimeout(hookDriveButton, 5000);
  }

  // ───── WORKUPLOAD ─────
  // DO NOT auto-call the API. Only trigger when the user clicks the Download button.
  // Workupload flow: user clicks Download on /file/<id> → navigates to /start/<id> → 
  //   /start/<id> page auto-starts the download via browser Content-Disposition.
  // In our WebView we intercept the /start/ page and call the API there to get the real URL.
  if (host.includes('workupload.com')) {
    var wuSent = false;
    var isStartPage = window.location.pathname.match(/\/start\//);

    function resolveWorkuploadAPI() {
      if (wuSent) return;
      var pathMatch = window.location.pathname.match(/\/(file|start|archive)\/([a-zA-Z0-9_-]+)/);
      if (!pathMatch || !pathMatch[2]) return;
      var fileId = pathMatch[2];

      fetch('https://workupload.com/api/file/getDownloadServer/' + fileId, {
        method: 'GET',
        credentials: 'include'
      })
      .then(function(resp) { return resp.json(); })
      .then(function(json) {
        if (wuSent) return;
        if (json && json.data && json.data.url) {
          wuSent = true;
          console.log('[MyAnimes] Workupload API resolved download URL:', json.data.url);
          sendDownload(json.data.url, window.location.href);
        }
      })
      .catch(function(err) {
        console.log('[MyAnimes] Workupload API error:', err);
      });
    }

    if (isStartPage) {
      // We ARE on the /start/ page — user already clicked Download, so resolve now
      setTimeout(resolveWorkuploadAPI, 500);
      var wuInterval = setInterval(function() {
        if (wuSent) { clearInterval(wuInterval); return; }
        resolveWorkuploadAPI();
      }, 2000);
    } else {
      // We are on the /file/ page — hook the Download button click
      function hookWorkuploadButton() {
        // The download button varies: could be a link with class/id, or a styled button
        var btns = document.querySelectorAll('#downloadButton, .download-btn, a.download, a[href*="/start/"], button[onclick*="download"], .dlbtn');
        btns.forEach(function(btn) {
          if (btn.__myAnimesHooked) return;
          btn.__myAnimesHooked = true;
          btn.addEventListener('click', function(e) {
            // Let the page navigate to /start/ which will trigger the API call
            console.log('[MyAnimes] Workupload download button clicked, navigating to start page...');
          }, true);
        });
      }
      hookWorkuploadButton();
      var targetWu = document.documentElement || document.body || document;
      if (targetWu) {
        var moWu = new MutationObserver(function() { hookWorkuploadButton(); });
        moWu.observe(targetWu, {childList: true, subtree: true});
      }
      setTimeout(hookWorkuploadButton, 2000);
    }
  }

  // ───── GOFILE ─────
  // Only hook clicks on download buttons, don't auto-scan DOM for links
  if (host.includes('gofile.io')) {
    function hookGofileButtons() {
      var btns = document.querySelectorAll('[data-link], button.download-btn, a[href*="/download/"], a[href*="gofile.io/download"]');
      btns.forEach(function(btn) {
        if (btn.__myAnimesHooked) return;
        btn.__myAnimesHooked = true;
        btn.addEventListener('click', function(e) {
          var link = btn.getAttribute('data-link') || btn.href;
          if (link && !link.includes('gofile.io/d/')) {
            e.preventDefault();
            e.stopPropagation();
            sendDownload(link, 'https://gofile.io/');
          }
        }, true);
      });
    }
    hookGofileButtons();
    var targetGf = document.documentElement || document.body || document;
    if (targetGf) {
      var mo3 = new MutationObserver(function() { hookGofileButtons(); });
      mo3.observe(targetGf, {childList: true, subtree: true});
    }
    setInterval(hookGofileButtons, 3000);
  }

  // ───── GENERIC: Intercept clicks on direct-file links only ─────
  document.addEventListener('click', function(e) {
    var target = e.target;
    while (target && target.tagName !== 'A') {
      target = target.parentNode;
      if (!target || target === document) { target = null; break; }
    }
    if (target && target.href) {
      var href = target.href.toLowerCase();
      // Catch direct file links
      if (href.match(/\.(mp4|mkv|avi|zip|rar)(\?|$)/)) {
        e.preventDefault();
        e.stopPropagation();
        sendDownload(target.href, window.location.href);
        return;
      }
      // Catch download subdomain links (download.mediafire, download1234.mediafire, etc.)
      if (href.match(/download\d*\.mediafire\.com\//)) {
        e.preventDefault();
        e.stopPropagation();
        sendDownload(target.href, 'https://www.mediafire.com/');
        return;
      }
      // Catch googleusercontent direct links
      if (href.includes('googleusercontent.com/docs/securesc/')) {
        e.preventDefault();
        e.stopPropagation();
        sendDownload(target.href, 'https://drive.google.com/');
        return;
      }
      // Catch workupload REAL download links only (wdl*.workupload.com, stream.workupload.com)
      if (href.includes('stream.workupload.com/') || href.match(/wdl\d*\.workupload\.com\//)) {
        e.preventDefault();
        e.stopPropagation();
        sendDownload(target.href, 'https://workupload.com/');
        return;
      }
      // Catch gofile direct download links
      if (href.includes('gofile.io/download/') || href.includes('gofile.io/stream/')) {
        e.preventDefault();
        e.stopPropagation();
        sendDownload(target.href, 'https://gofile.io/');
        return;
      }
    }
  }, true);

  // NOTE: XMLHttpRequest and fetch overrides REMOVED.
  // They caused phantom "download started" triggers from background API requests
  // (e.g. workupload token checks, gofile metadata fetches) that are NOT actual files.

  // Helper to detect ad networks
  function isAdUrl(u) {
    if (!u) return false;
    var s = (u + '').toLowerCase();
    if (s.includes('witanime.') || s.includes('witmanga.') || s.includes('mediafire.com') ||
        s.includes('drive.google.com') || s.includes('gofile.io') || s.includes('workupload.com') ||
        s.includes('mp4upload.com') || s.includes('googleusercontent.com') || s.includes('mega.nz') ||
        s.includes('1fichier.com') || s.includes('uptobox.com')) {
      return false;
    }
    return s.includes('adsterra') || s.includes('popcash') || s.includes('propeller') ||
           s.includes('clickadu') || s.includes('monetag') || s.includes('hilltopads') ||
           s.includes('exoclick') || s.includes('syndication') || s.includes('trafficjunky') ||
           s.includes('doubleclick') || s.includes('bet365') || s.includes('1xbet') ||
           s.includes('casino') || s.includes('onclick') || s.includes('adsystem') ||
           s.includes('adskeeper') || s.includes('yllix') || s.includes('alwingulla') ||
           s.includes('deloton') || s.includes('directrev') || s.includes('onclkds') ||
           s.includes('pushwelcome') || s.includes('ad-maven') || s.includes('richpush') ||
           s.includes('coinhive') || s.includes('popads') || s.includes('adcash') ||
           s.includes('smartadserver') || s.includes('adnxs') || s.includes('betwinner') ||
           s.includes('attacksveteran') || s.includes('portalfluently') || s.includes('protrafficinspector') ||
           s.includes('histats') || s.includes('trafficinspector') || s.includes('propellerads');
  }

  // ───── Reactive Smart Window ─────
  function createSmartWindow() {
    function navigateSmart(targetUrl) {
      if (!targetUrl || targetUrl === 'about:blank') return;
      var lower = (targetUrl + '').toLowerCase();
      if (isAdUrl(lower)) {
        console.log('[MyAnimes] Blocked delayed ad popup:', targetUrl);
        return;
      }
      console.log('[MyAnimes] Smart window navigating to:', targetUrl);
      if (lower.match(/\.(mp4|mkv|zip|rar)(\?|$)/i) || 
          lower.match(/download\d*\.mediafire\.com\//) ||
          lower.includes('stream.workupload.com/') || lower.match(/wdl\d*\.workupload\.com\//) ||
          lower.includes('gofile.io/download/') || lower.includes('gofile.io/stream/')) {
        sendDownload(targetUrl, window.location.href);
      } else {
        window.location.href = targetUrl;
      }
    }

    var locObj = {
      _href: '',
      get href() { return this._href; },
      set href(val) {
        this._href = val;
        navigateSmart(val);
      },
      replace: function(val) { navigateSmart(val); },
      assign: function(val) { navigateSmart(val); },
      toString: function() { return this._href; }
    };

    var winObj = {
      focus: function() {},
      close: function() {},
      closed: false,
      document: {
        write: function() {},
        close: function() {},
        open: function() {}
      }
    };

    Object.defineProperty(winObj, 'location', {
      get: function() { return locObj; },
      set: function(val) {
        if (typeof val === 'string') {
          navigateSmart(val);
        } else if (val && val.href) {
          navigateSmart(val.href);
        }
      },
      configurable: true
    });

    return winObj;
  }

  // ───── Popup & Advertising Tab Blocker ─────
  window.open = function(url, name, specs) {
    var win = createSmartWindow();
    if (!url || url === 'about:blank' || url === '') {
      return win;
    }
    var lower = (url + '').toLowerCase();
    if (isAdUrl(lower)) {
      console.log('[MyAnimes] Blocked ad popup:', url);
      return win;
    }
    win.location.href = url;
    return win;
  };

  // ───── Anti-Clickjacking: Remove invisible transparent ad click-traps ─────
  function removeAdOverlays() {
    try {
      document.querySelectorAll('[data-ad-slot], [id*="ad_"], [class*="ad-container"], [id*="ad-banner"]').forEach(function(el) {
        el.remove();
      });

      document.querySelectorAll('div, a, iframe, span').forEach(function(el) {
        if (!el || el.id === 'app' || el.hasAttribute('x-data') || (el.closest && el.closest('header, nav, [x-data]'))) return;
        var style = window.getComputedStyle(el);
        if (style.position === 'fixed' || style.position === 'absolute') {
          var z = parseInt(style.zIndex, 10);
          if (z >= 100) {
            var rect = el.getBoundingClientRect();
            if (rect.width >= window.innerWidth * 0.5 && rect.height >= window.innerHeight * 0.5) {
              var bg = style.backgroundColor;
              var op = parseFloat(style.opacity);
              if (op < 0.1 || bg === 'transparent' || bg.includes('rgba(0, 0, 0, 0)')) {
                console.log('[MyAnimes] Removed ad click trap overlay:', el);
                el.remove();
              }
            }
          }
        }
      });
    } catch(e) {}
  }
  removeAdOverlays();
  setInterval(removeAdOverlays, 400);

  // ───── Block popup ads on clicks and rewrite target=_blank to _self ─────
  document.addEventListener('click', function(e) {
    removeAdOverlays();

    var el = e.target;
    while (el && el !== document) {
      if (el.tagName === 'A') {
        var href = (el.getAttribute('href') || '').toLowerCase();
        if (isAdUrl(href)) {
          e.preventDefault();
          e.stopImmediatePropagation();
          return false;
        }
        if (el.target === '_blank') {
          el.target = '_self';
        }
      }

      // Check if button/element has data-url or data-href or data-link
      var dataUrl = el.getAttribute('data-url') || el.getAttribute('data-href') || el.getAttribute('data-link');
      if (dataUrl && !isAdUrl(dataUrl) && (dataUrl.startsWith('http://') || dataUrl.startsWith('https://'))) {
        e.preventDefault();
        e.stopPropagation();
        window.location.href = dataUrl;
        return;
      }

      el = el.parentElement;
    }
  }, true);

  setInterval(function() {
    document.querySelectorAll('a[target="_blank"]').forEach(function(a) {
      var href = (a.getAttribute('href') || '').toLowerCase();
      if (isAdUrl(href)) {
        a.removeAttribute('href');
        a.onclick = function(e) { e.preventDefault(); e.stopImmediatePropagation(); return false; };
      } else {
        a.target = '_self';
      }
    });
  }, 400);
})();
''';

  Future<void> initPlatformState() async {
    final searchQuery = widget.animeTitle.replaceAll(' - Ep. ', ' الحلقة ');
    final witanimeDomain = HiveService.witanimeDomain;
    
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
            window.location.href = "https://$witanimeDomain/?s=" + query;
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
              final referer = data['referer'] as String?;
              if (_isSecureDownloadUrl(url) && !_downloadedUrls.contains(url!)) {
                _downloadedUrls.add(url);
                debugPrint('[MyAnimes] JS intercepted verified download: $url');
                _startDownload(url, referer: referer ?? _currentWebpageUrl);
              }
            }
          } catch (e) {
            debugPrint('webMessage parse error: $e');
          }
        });

        // Listen for URL changes (still useful for navigation tracking + direct .mp4 links)
        _winController.url.listen((url) {
          if (!mounted) return;
          
          if (_isAdUrl(url)) {
            debugPrint('[WitAnime Win] Blocked ad navigation: $url');
            _winController.stop();
            return;
          }

          // Inject 404 check
          _winController.executeScript(jsCheck404);

          if (_isPotentialDownload(url) && _isSecureDownloadUrl(url)) {
            _winController.stop();
            if (!_downloadedUrls.contains(url)) {
              _downloadedUrls.add(url);
              _startDownload(url, referer: _currentWebpageUrl);
            }
          } else {
            setState(() {
              _currentWebpageUrl = url;
            });
          }
        });

        await _winController.setBackgroundColor(Colors.transparent);
        // Set policy to deny to block all OS popup window spawns!
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
                final referer = data['referer'] as String?;
                if (_isSecureDownloadUrl(url) && !_downloadedUrls.contains(url!)) {
                  _downloadedUrls.add(url);
                  _startDownload(url, referer: referer ?? _currentWebpageUrl);
                }
              }
            } catch (e) {
              debugPrint('JS channel parse error: $e');
            }
          })
          ..setNavigationDelegate(
            wf.NavigationDelegate(
              onPageStarted: (String url) {
                _mobileController.runJavaScript(_jsMobileDownloadInterceptor);
              },
              onPageFinished: (String url) {
                // Inject download interceptor adapted for mobile (use JS channel instead of postMessage)
                _mobileController.runJavaScript(_jsMobileDownloadInterceptor);
                _mobileController.runJavaScript(jsCheck404);
                if (mounted) {
                  setState(() {
                    _currentWebpageUrl = url;
                  });
                }
              },
              onNavigationRequest: (wf.NavigationRequest request) {
                final url = request.url;
                if (_isAdUrl(url)) {
                  debugPrint('[WitAnime Mobile] Blocked ad navigation: $url');
                  return wf.NavigationDecision.prevent;
                }
                if (_isPotentialDownload(url)) {
                  if (!_downloadedUrls.contains(url)) {
                    _downloadedUrls.add(url);
                    _startDownload(url, referer: _currentWebpageUrl);
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

  bool _isSecureDownloadUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    // Strictly require HTTPS or HTTP scheme (blocks file:, data:, javascript:, blob:, etc.)
    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) return false;
    // Block loopback and local network SSRF probes
    final host = uri.host.toLowerCase();
    if (host.isEmpty ||
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        host.startsWith('172.16.') ||
        host.endsWith('.local') ||
        host.endsWith('.internal')) {
      return false;
    }
    // Block known ad/malware domains
    if (_isAdUrl(url)) return false;
    return true;
  }

  bool _isAdUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    
    // Whitelist legitimate domains
    if (lower.contains('witanime.') || lower.contains('witmanga.')) return false;
    if (lower.contains('mediafire.com') || lower.contains('drive.google.com') || 
        lower.contains('docs.google.com') || lower.contains('gofile.io') || 
        lower.contains('workupload.com') || lower.contains('mp4upload.com') ||
        lower.contains('googleusercontent.com') || lower.contains('mega.nz') ||
        lower.contains('1fichier.com') || lower.contains('uptobox.com')) {
      return false;
    }
    
    const adKeywords = [
      'adsterra', 'popcash', 'propeller', 'clickadu', 'monetag', 'hilltopads',
      'exoclick', 'syndication', 'trafficjunky', 'doubleclick', 'bet365', '1xbet',
      'casino', 'onclick', 'adsystem', 'adskeeper', 'yllix', 'alwingulla',
      'deloton', 'directrev', 'onclkds', 'pushwelcome', 'ad-maven', 'richpush',
      'coinhive', 'googlesyndication', 'adnxs', 'smartadserver', 'betwinner',
      'melbet', 'mostbet', 'linebet', 'popads', 'adcash', 'adclick', 'adservice',
      'attacksveteran', 'portalfluently', 'protrafficinspector', 'trafficinspector',
      'histats', 'propellerads'
    ];
    for (final kw in adKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  // Mobile version of the interceptor uses the JS channel API
  static String get _jsMobileDownloadInterceptor => _jsDownloadInterceptor.replaceAll(
    'window.chrome.webview.postMessage(',
    'MyAnimesDownload.postMessage('
  );

  bool _isPotentialDownload(String url) {
    final lowerUrl = url.toLowerCase();
    
    // NEVER intercept witanime/witmanga domains
    if (lowerUrl.contains('witanime.') || lowerUrl.contains('witmanga.')) return false;
    
    // Webpages of file hosting services are NOT direct download streams; webview must load them!
    if (lowerUrl.contains('mediafire.com/file/') ||
        lowerUrl.contains('mediafire.com/view/') ||
        lowerUrl.contains('workupload.com/file/') ||
        lowerUrl.contains('workupload.com/start/') ||
        lowerUrl.contains('workupload.com/archive/') ||
        lowerUrl.contains('gofile.io/d/') ||
        lowerUrl.contains('gofile.io/t/') ||
        lowerUrl.contains('mp4upload.com/') ||
        lowerUrl.contains('drive.google.com/file/') ||
        lowerUrl.contains('drive.google.com/open') ||
        lowerUrl.contains('mega.nz/') ||
        lowerUrl.contains('1fichier.com/') ||
        lowerUrl.contains('uptobox.com/')) {
      return false;
    }

    // Direct file formats
    if (lowerUrl.endsWith('.mp4') || 
        lowerUrl.endsWith('.mkv') || 
        lowerUrl.endsWith('.zip') || 
        lowerUrl.endsWith('.rar') ||
        lowerUrl.contains('.mp4?') ||
        lowerUrl.contains('.mkv?')) {
      return true;
    }
    
    // Mediafire direct links
    if (RegExp(r'download\d*\.mediafire\.com/').hasMatch(lowerUrl)) {
      return true;
    }
    
    // Google Drive direct export
    if ((lowerUrl.contains('drive.google.com/uc?') || lowerUrl.contains('docs.google.com/uc?')) && lowerUrl.contains('export=download')) {
      return true;
    }
    if (lowerUrl.contains('googleusercontent.com/docs/securesc/')) {
      return true;
    }
    
    // Workupload: direct download server subdomains (e.g. f102.workupload.com/download/, wdl*.workupload.com/, stream.workupload.com/)
    if (lowerUrl.contains('stream.workupload.com/') ||
        RegExp(r'[a-z0-9]+\.workupload\.com/download/').hasMatch(lowerUrl) ||
        RegExp(r'wdl\d*\.workupload\.com/').hasMatch(lowerUrl)) {
      return true;
    }
    
    // GoFile
    if (lowerUrl.contains('gofile.io/download/') || lowerUrl.contains('gofile.io/stream/') || lowerUrl.contains('.gofile.io/download')) {
      return true;
    }
    
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

  Future<void> _startDownload(String url, {String? referer}) async {
    String? cookies;
    String? accountToken;
    String? userAgent;

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
        final uaRes = await _winController.executeScript('navigator.userAgent');
        if (uaRes is String) {
          userAgent = _parseJSString(uaRes);
        }
      } catch (e) {
        debugPrint("Failed to get credentials on Windows: $e");
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      try {
        if (Platform.isAndroid) {
          const cookieChannel = MethodChannel('com.myanimes.app/cookies');
          
          // 1. Get cookies for target download URL
          final nativeCookies = await cookieChannel.invokeMethod<String>('getCookies', {'url': url});
          
          // 2. Also get cookies for the root domain if target is a subdomain (e.g. f102.workupload.com -> workupload.com)
          String? domainCookies;
          try {
            final uri = Uri.parse(url);
            final hostParts = uri.host.split('.');
            if (hostParts.length >= 2) {
              final rootDomain = hostParts.sublist(hostParts.length - 2).join('.');
              domainCookies = await cookieChannel.invokeMethod<String>('getCookies', {'url': 'https://$rootDomain'});
            }
          } catch (_) {}

          // 3. Also get cookies for current page / referer
          String? pageCookies;
          final refUrl = referer ?? _currentWebpageUrl;
          if (refUrl.isNotEmpty) {
            try {
              pageCookies = await cookieChannel.invokeMethod<String>('getCookies', {'url': refUrl});
            } catch (_) {}
          }

          // Combine native cookies, deduplicating keys
          final cookieMap = <String, String>{};
          for (final c in [domainCookies, pageCookies, nativeCookies]) {
            if (c != null && c.isNotEmpty) {
              for (final part in c.split(';')) {
                final trimmed = part.trim();
                final eqIdx = trimmed.indexOf('=');
                if (eqIdx > 0) {
                  final k = trimmed.substring(0, eqIdx).trim();
                  final v = trimmed.substring(eqIdx + 1).trim();
                  cookieMap[k] = v;
                }
              }
            }
          }
          if (cookieMap.isNotEmpty) {
            cookies = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
          }
        }

        // Fallback to document.cookie if native didn't get any or on iOS
        if (cookies == null || cookies.isEmpty) {
          final cookieRes = await _mobileController.runJavaScriptReturningResult('document.cookie');
          if (cookieRes is String) {
            cookies = _parseJSString(cookieRes);
          }
        }

        final tokenRes = await _mobileController.runJavaScriptReturningResult(
          '(function(){try{return localStorage.getItem("accountToken")||"";}catch(e){return "";}})()'
        );
        if (tokenRes is String) {
          accountToken = _parseJSString(tokenRes);
        }

        final uaRes = await _mobileController.runJavaScriptReturningResult('navigator.userAgent');
        if (uaRes is String) {
          userAgent = _parseJSString(uaRes);
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

    final hasStorage = await StoragePermissionHelper.hasPermission();
    if (!hasStorage) {
      if (!mounted) return;
      final granted = await StoragePermissionHelper.requestWithRationale(
        context,
        title: 'Storage Access Required',
        message: 'Storage permission is required to save downloaded episodes to your device.\n\nGrant storage access to start downloading?',
      );
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download cancelled: storage permission was not granted.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    debugPrint('[WitAnime] Starting download with cookies: ${cookies?.isNotEmpty == true ? "YES (${cookies!.length} chars)" : "NONE"}, userAgent: $userAgent');

    final accepted = await DownloadManager.instance.startDownload(
      url, 
      widget.animeTitle, 
      imageUrl: widget.animeImageUrl,
      cookies: cookies,
      referer: referer ?? (_currentWebpageUrl.isNotEmpty ? _currentWebpageUrl : null),
      userAgent: userAgent,
    );

    if (!mounted) return;
    if (accepted) {
      final navigator = Navigator.of(context);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Started downloading episode in background!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'Open Manager',
            textColor: Colors.white,
            onPressed: () {
              navigator.push(
                MaterialPageRoute(builder: (context) => const DownloadManagerPage()),
              );
            },
          ),
        ),
      );
    } else {
      debugPrint('[WitAnime] Download rejected for URL: $url');
    }
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
        titleSpacing: 0,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.animeTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (_currentWebpageUrl.isNotEmpty)
              Text(
                Uri.tryParse(_currentWebpageUrl)?.host ?? _currentWebpageUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 22), 
            tooltip: 'Back',
            onPressed: () async {
              if (Platform.isWindows) {
                _winController.goBack();
              } else {
                if (await _mobileController.canGoBack()) {
                  _mobileController.goBack();
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, size: 22), 
            tooltip: 'Forward',
            onPressed: () async {
              if (Platform.isWindows) {
                _winController.goForward();
              } else {
                if (await _mobileController.canGoForward()) {
                  _mobileController.goForward();
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22), 
            tooltip: 'Reload',
            onPressed: () {
              if (Platform.isWindows) {
                _winController.reload();
              } else {
                _mobileController.reload();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded, size: 22),
            tooltip: 'Open in External Browser',
            onPressed: () async {
              final target = _currentWebpageUrl.isNotEmpty ? _currentWebpageUrl : widget.initialUrl;
              final uri = Uri.tryParse(target);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
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
          const SizedBox(width: 4),
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
                color: AppColors.accent.withValues(alpha: 0.15),
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
                        '${activeTasks.length} episodes downloading in background...',
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
