import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart' as ww;
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/services/download_manager.dart';
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
  // The download page has a button with id="downloadButton" whose href is the real link
  if (host.includes('mediafire.com')) {
    function grabMediafire() {
      var btn = document.getElementById('downloadButton');
      if (btn && btn.href && (btn.href.includes('download') || btn.href.match(/download\d*\.mediafire\.com/))) {
        if (!btn.href.includes('/file/')) {
          sendDownload(btn.href, 'https://www.mediafire.com/');
        }
      }
    }
    grabMediafire();
    var targetMf = document.documentElement || document.body || document;
    if (targetMf) {
      var mo = new MutationObserver(function() { grabMediafire(); });
      mo.observe(targetMf, {childList: true, subtree: true});
    }
    setInterval(grabMediafire, 1500);
  }

  // ───── GOOGLE DRIVE ─────
  // /file/d/ID/view pages have a download button or we can construct the direct link
  if (host.includes('drive.google.com') || host.includes('docs.google.com')) {
    var m = window.location.pathname.match(/\/file\/d\/([^\/]+)/);
    if (m && m[1]) {
      var driveUrl = 'https://drive.google.com/uc?export=download&id=' + m[1];
      sendDownload(driveUrl, 'https://drive.google.com/');
    }
    // Also try to catch the download form/confirm button
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
  // workupload.com uses an internal API to resolve the real download URL.
  // Flow: /file/<id> → sets token cookie → /api/file/getDownloadServer/<id> → JSON { data: { url: "..." } }
  if (host.includes('workupload.com')) {
    var wuSent = false;
    function grabWorkuploadAPI() {
      if (wuSent) return;
      // Extract file ID from URL path: /file/xxx, /start/xxx, /archive/xxx
      var pathMatch = window.location.pathname.match(/\/(file|start|archive)\/([a-zA-Z0-9_-]+)/);
      if (!pathMatch || !pathMatch[2]) return;
      var fileId = pathMatch[2];

      // Call the internal API to get the real download server URL
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
          sendDownload(json.data.url, 'https://workupload.com/');
        }
      })
      .catch(function(err) {
        console.log('[MyAnimes] Workupload API error, falling back to DOM:', err);
        // Fallback: try to find a direct download link in the DOM
        var btn = document.getElementById('downloadButton') ||
                  document.querySelector('a[href*="/download/"]') ||
                  document.querySelector('a[href*="stream.workupload.com"]');
        if (btn) {
          var href = btn.href || btn.getAttribute('data-url');
          if (href && (href.includes('/download/') || href.includes('stream.')) && !href.includes('/start/') && !href.includes('/file/')) {
            wuSent = true;
            sendDownload(href, 'https://workupload.com/');
          }
        }
      });
    }
    // Wait a moment for the token cookie to be set, then call the API
    setTimeout(grabWorkuploadAPI, 800);
    // Retry every 3 seconds in case the first attempt fails (e.g. token not ready)
    var wuInterval = setInterval(function() {
      if (wuSent) { clearInterval(wuInterval); return; }
      grabWorkuploadAPI();
    }, 3000);
  }

  // ───── GOFILE ─────
  // gofile.io/d/xxx shows file listing. Download links are constructed via API.
  if (host.includes('gofile.io')) {
    function grabGofile() {
      var links = document.querySelectorAll('a[href*="/download/"], a[href*="gofile.io/download"]');
      links.forEach(function(a) {
        if (a.href && !a.href.includes('gofile.io/d/')) sendDownload(a.href, 'https://gofile.io/');
      });
      var btns = document.querySelectorAll('[data-link], button.download-btn');
      btns.forEach(function(b) {
        var link = b.getAttribute('data-link');
        if (link && !link.includes('gofile.io/d/')) sendDownload(link, 'https://gofile.io/');
      });
    }
    grabGofile();
    var targetGf = document.documentElement || document.body || document;
    if (targetGf) {
      var mo3 = new MutationObserver(function() { grabGofile(); });
      mo3.observe(targetGf, {childList: true, subtree: true});
    }
    setInterval(grabGofile, 2500);
  }

  // ───── GENERIC: Intercept ALL clicks on download-looking links ─────
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
      // Catch workupload direct download links (including API-resolved wdl subdomains)
      if (href.includes('workupload.com/download/') || href.includes('stream.workupload.com/') || href.match(/wdl\d*\.workupload\.com\//)) {
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

  // ───── Override XMLHttpRequest to catch AJAX-initiated downloads ─────
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
            (this.responseURL.match(/\.(mp4|mkv)(\?|$)/) ||
             this.responseURL.includes('googleusercontent.com') ||
             this.responseURL.match(/download\d*\.mediafire\.com/))) {
          sendDownload(this.responseURL, window.location.href);
        }
      } catch(e) {}
    });
    return origSend.apply(this, arguments);
  };

  // ───── Override fetch to catch fetch-initiated downloads ─────
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
  // WitAnime and other download managers call `var w = window.open('', '_blank')` synchronously
  // to avoid browser popup blockers, then assign `w.location.href = data.url` when the server API returns.
  // A reactive proxy captures this delayed assignment and navigates to the real download site!
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
          (lower.includes('workupload.com/download/') || lower.includes('stream.workupload.com/') || lower.match(/wdl\d*\.workupload\.com\//)) ||
          (lower.includes('gofile.io/download/') || lower.includes('gofile.io/stream/'))) {
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
      // 1. Remove explicit ad containers
      document.querySelectorAll('[data-ad-slot], [id*="ad_"], [class*="ad-container"], [id*="ad-banner"]').forEach(function(el) {
        el.remove();
      });

      // 2. Remove floating full-screen transparent click traps
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
              if (url != null && url.isNotEmpty && !_downloadedUrls.contains(url)) {
                _downloadedUrls.add(url);
                debugPrint('[MyAnimes] JS intercepted download: $url');
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

          if (_isPotentialDownload(url)) {
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
                if (url != null && url.isNotEmpty && !_downloadedUrls.contains(url)) {
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
    
    // Workupload: direct /download/ path or any download subdomain (wdl1.workupload.com, wdl.workupload.com, stream.workupload.com, etc.)
    if (lowerUrl.contains('workupload.com/download/') || 
        lowerUrl.contains('stream.workupload.com/') ||
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
      widget.animeTitle, 
      imageUrl: widget.animeImageUrl,
      cookies: cookies,
      referer: referer,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Started downloading episode in background!'),
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
