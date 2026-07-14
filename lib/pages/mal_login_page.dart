import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart' as ww;
import 'package:webview_flutter/webview_flutter.dart' as wf;
import '../core/theme/app_colors.dart';
import '../core/services/mal_auth_service.dart';

class MalLoginPage extends StatefulWidget {
  const MalLoginPage({super.key});

  @override
  State<MalLoginPage> createState() => _MalLoginPageState();
}

class _MalLoginPageState extends State<MalLoginPage> {
  late final ww.WebviewController _winController;
  late final wf.WebViewController _mobileController;
  bool _isWebviewInitialized = false;
  bool _isExchangingToken = false;
  late final String _codeVerifier;
  late final String _authUrl;

  @override
  void initState() {
    super.initState();
    _codeVerifier = MalAuthService.instance.generateCodeVerifier();
    _authUrl = MalAuthService.instance.getAuthorizeUrl(_codeVerifier);
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    if (Platform.isWindows) {
      try {
        _winController = ww.WebviewController();
        await _winController.initialize();

        await _winController.setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
        );

        _winController.url.listen((url) {
          if (!mounted) return;
          _handleRedirect(url);
        });

        await _winController.setBackgroundColor(Colors.transparent);
        await _winController.loadUrl(_authUrl);

        if (!mounted) return;
        setState(() => _isWebviewInitialized = true);
      } catch (e) {
        debugPrint("MAL login webview init error: $e");
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      try {
        _mobileController = wf.WebViewController()
          ..setJavaScriptMode(wf.JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setUserAgent('Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36')
          ..setNavigationDelegate(
            wf.NavigationDelegate(
              onNavigationRequest: (wf.NavigationRequest request) {
                final url = request.url;
                if (_handleRedirect(url)) {
                  return wf.NavigationDecision.prevent;
                }
                return wf.NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(_authUrl));

        if (!mounted) return;
        setState(() => _isWebviewInitialized = true);
      } catch (e) {
        debugPrint("MAL login webview init error: $e");
      }
    }
  }

  bool _handleRedirect(String url) {
    if (url.startsWith('http://localhost') && url.contains('code=')) {
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      if (code != null) {
        _exchangeToken(code);
        return true;
      }
    }
    return false;
  }

  Future<void> _exchangeToken(String code) async {
    if (_isExchangingToken) return;
    setState(() {
      _isExchangingToken = true;
    });

    final success = await MalAuthService.instance.exchangeCodeForToken(code, _codeVerifier);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully logged in to MyAnimeList!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to link MyAnimeList account.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isExchangingToken = false;
      });
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
        title: const Text('Link MyAnimeList'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: Stack(
        children: [
          if (_isWebviewInitialized && !_isExchangingToken)
            Platform.isWindows
                ? ww.Webview(_winController)
                : wf.WebViewWidget(controller: _mobileController)
          else
            const Center(child: CircularProgressIndicator()),
          if (_isExchangingToken)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      'Exchanging authorization credentials...',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
