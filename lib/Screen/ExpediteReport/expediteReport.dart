import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class ExpediteReport extends StatefulWidget {
  const ExpediteReport({super.key});

  @override
  State<ExpediteReport> createState() => _ExpediteReportState();
}

class _ExpediteReportState extends State<ExpediteReport> {
  /// React Expedite Report running on your PC.
  static const String reportUrl = 'http://192.168.1.5:3000/expedite-report';
  static const String reactOrigin = 'http://192.168.1.5:3000/expedite-report';

  late final WebViewController _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();

  bool _isLoading = true;
  bool _openedReport = false;
  String? _errorMessage;
  String? _failedUrl;
  String _token = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initWebView();
    }
  }

  Uri get _reportUri => Uri.parse(reportUrl);

  String _forceHttp(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (uri.scheme == 'https' && uri.host == _reportUri.host) {
      return uri.replace(scheme: 'http').toString();
    }
    return url;
  }

  Future<void> _initWebView() async {
    final prefs = await SharedPreferences.getInstance();
    _token = (prefs.getString('token') ?? '').trim();
    _userName = (prefs.getString('UserName') ?? '').trim();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final fixed = _forceHttp(request.url);
            if (fixed != request.url) {
              _controller.loadRequest(Uri.parse(fixed));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _errorMessage = null;
              _failedUrl = null;
            });
          },
          onPageFinished: (url) async {
            await _injectAuthIntoPage();
            await _disablePasswordAutofillHints();
            await _hideReactTopHeader();

            // First load origin only to seed storage, then open report.
            final isOriginOnly =
                url == reactOrigin ||
                url == 'http://192.168.1.5:3000' ||
                url.startsWith('http://192.168.1.5:3000/?');

            if (!_openedReport && isOriginOnly) {
              _openedReport = true;
              await _controller.loadRequest(Uri.parse(_reportUrlWithToken()));
            }

            if (!mounted) return;
            setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (!mounted) return;

            final failingUrl = error.url ?? reportUrl;
            final isSslProtocolError =
                error.description.contains('ERR_SSL_PROTOCOL_ERROR') ||
                error.errorType == WebResourceErrorType.failedSslHandshake;

            if (isSslProtocolError) {
              _loadViaHttpFallback(_forceHttp(failingUrl));
              return;
            }

            setState(() {
              _isLoading = false;
              _failedUrl = failingUrl;
              _errorMessage = error.description;
            });
          },
          onSslAuthError: (error) async {
            await error.proceed();
          },
        ),
      );

    _configureAndroidWebView();
    await _loadReport();
  }

  String _reportUrlWithToken() {
    if (_token.isEmpty) return reportUrl;
    final uri = Uri.parse(reportUrl);
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'token': _token,
            'authentication': _token,
            if (_userName.isNotEmpty) 'username': _userName,
          },
        )
        .toString();
  }

  void _configureAndroidWebView() {
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  Future<void> _setAuthCookies() async {
    if (_token.isEmpty) return;

    final cookies = <WebViewCookie>[
      WebViewCookie(
        name: 'token',
        value: _token,
        domain: '192.168.1.5',
        path: '/',
      ),
      WebViewCookie(
        name: 'authentication',
        value: _token,
        domain: '192.168.1.5',
        path: '/',
      ),
      WebViewCookie(
        name: 'Authorization',
        value: 'Bearer $_token',
        domain: '192.168.1.5',
        path: '/',
      ),
      WebViewCookie(
        name: 'authToken',
        value: _token,
        domain: '192.168.1.5',
        path: '/',
      ),
    ];

    if (_userName.isNotEmpty) {
      cookies.add(
        WebViewCookie(
          name: 'UserName',
          value: _userName,
          domain: '192.168.1.5',
          path: '/',
        ),
      );
      cookies.add(
        WebViewCookie(
          name: 'username',
          value: _userName,
          domain: '192.168.1.5',
          path: '/',
        ),
      );
    }

    for (final cookie in cookies) {
      await _cookieManager.setCookie(cookie);
    }
  }

  Future<void> _injectAuthIntoPage() async {
    if (_token.isEmpty) return;

    try {
      await _controller.runJavaScript('''
        (function () {
          var token = ${jsonEncode(_token)};
          var userName = ${jsonEncode(_userName)};
          var keys = [
            'token',
            'authentication',
            'authToken',
            'accessToken',
            'access_token',
            'jwt',
            'jwtToken',
            'Authorization'
          ];

          keys.forEach(function (key) {
            try {
              if (key === 'Authorization') {
                localStorage.setItem(key, 'Bearer ' + token);
                sessionStorage.setItem(key, 'Bearer ' + token);
              } else {
                localStorage.setItem(key, token);
                sessionStorage.setItem(key, token);
              }
            } catch (e) {}
          });

          if (userName) {
            try {
              localStorage.setItem('UserName', userName);
              localStorage.setItem('username', userName);
              localStorage.setItem('user', userName);
              sessionStorage.setItem('UserName', userName);
              sessionStorage.setItem('username', userName);
            } catch (e) {}
          }

          try {
            document.cookie = 'token=' + encodeURIComponent(token) + '; path=/';
            document.cookie = 'authentication=' + encodeURIComponent(token) + '; path=/';
            document.cookie = 'Authorization=' + encodeURIComponent('Bearer ' + token) + '; path=/';
            if (userName) {
              document.cookie = 'UserName=' + encodeURIComponent(userName) + '; path=/';
              document.cookie = 'username=' + encodeURIComponent(userName) + '; path=/';
            }
          } catch (e) {}
        })();
      ''');
    } catch (_) {}
  }

  Future<void> _hideReactTopHeader() async {
    try {
      await _controller.runJavaScript('''
        (function () {
          function hideTopHeader() {
            if (!document.getElementById('flutter-hide-top-header-style')) {
              var style = document.createElement('style');
              style.id = 'flutter-hide-top-header-style';
              style.textContent = [
                'header,',
                'nav,',
                '.navbar,',
                '.MuiAppBar-root,',
                '.MuiToolbar-root,',
                '[class*="AppBar"],',
                '[class*="Navbar"],',
                '[class*="TopBar"],',
                '[class*="top-bar"],',
                '[class*="topbar"],',
                '[class*="HeaderBar"],',
                '[class*="site-header"] {',
                '  display: none !important;',
                '}'
              ].join('\\n');
              document.head.appendChild(style);
            }

            var markers = [
              'TEST OVERVIEW',
              'Production report',
              'Logout'
            ];

            document.querySelectorAll('div, header, nav, section, aside').forEach(function (el) {
              if (!el || el.dataset.flutterHeaderHidden === '1') return;

              var text = (el.innerText || '').replace(/\\s+/g, ' ').trim();
              if (!text || text.length > 280) return;

              var rect = el.getBoundingClientRect();
              if (rect.top > 140) return;
              if (rect.height < 28 || rect.height > 140) return;
              if (rect.width < (window.innerWidth * 0.55)) return;

              var hasMarker = markers.some(function (marker) {
                return text.indexOf(marker) !== -1;
              });
              if (!hasMarker) return;

              // Prefer hiding a header-like container that includes overview/logout actions.
              var looksLikeHeader =
                (text.indexOf('TEST OVERVIEW') !== -1) ||
                (text.indexOf('Logout') !== -1 &&
                  (text.indexOf('Production report') !== -1 || text.indexOf('Om') !== -1));

              if (!looksLikeHeader) return;

              el.style.setProperty('display', 'none', 'important');
              el.style.setProperty('visibility', 'hidden', 'important');
              el.style.setProperty('height', '0', 'important');
              el.style.setProperty('overflow', 'hidden', 'important');
              el.dataset.flutterHeaderHidden = '1';
            });
          }

          hideTopHeader();

          if (!window.__flutterHideHeaderObserver) {
            window.__flutterHideHeaderObserver = new MutationObserver(function () {
              hideTopHeader();
            });
            window.__flutterHideHeaderObserver.observe(document.documentElement, {
              childList: true,
              subtree: true
            });
          }
        })();
      ''');
    } catch (_) {}
  }

  Future<void> _disablePasswordAutofillHints() async {
    try {
      await _controller.runJavaScript('''
        (function () {
          function patchPasswordFields(root) {
            (root || document).querySelectorAll('input[type="password"]').forEach(function (el) {
              el.setAttribute('type', 'text');
              el.setAttribute('autocomplete', 'off');
              el.setAttribute('autocapitalize', 'off');
              el.setAttribute('autocorrect', 'off');
              el.setAttribute('spellcheck', 'false');
              el.setAttribute('data-lpignore', 'true');
              el.style.webkitTextSecurity = 'disc';
            });
          }

          patchPasswordFields(document);

          if (!window.__passwordPatchObserver) {
            window.__passwordPatchObserver = new MutationObserver(function () {
              patchPasswordFields(document);
            });
            window.__passwordPatchObserver.observe(document.documentElement, {
              childList: true,
              subtree: true,
              attributes: true,
              attributeFilter: ['type']
            });
          }
        })();
      ''');
    } catch (_) {}
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _failedUrl = null;
      _openedReport = false;
    });

    await _setAuthCookies();

    // Load React origin first so localStorage/cookies belong to that domain,
    // then navigate to /expedite-report after auth injection.
    await _controller.loadRequest(Uri.parse(reactOrigin));
  }

  Future<void> _loadViaHttpFallback(String url) async {
    try {
      final response = await Dio().get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
          headers: const {'Accept': 'text/html,application/xhtml+xml'},
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _failedUrl = url;
          _errorMessage =
              'HTTP ${response.statusCode}: Unable to load React page.';
        });
        return;
      }

      final baseUrl = url.endsWith('/') ? url : '$url/';
      await _controller.loadHtmlString(response.data!, baseUrl: baseUrl);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _failedUrl = url;
        _errorMessage =
            'Could not open React page.\n'
            'Check that $reportUrl is running and reachable.\n\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
      // Hide Flutter grey header (Digital Wall + menu) on this WebView page.
      body: SafeArea(
        child: kIsWeb ? _buildWebUnsupported() : _buildMobileWebView(),
      ),
    );
  }

  Widget _buildMobileWebView() {
    final webView = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? WebViewWidget.fromPlatformCreationParams(
            params: AndroidWebViewWidgetCreationParams(
              controller: _controller.platform,
              displayWithHybridComposition: true,
            ),
          )
        : WebViewWidget(controller: _controller);

    return Stack(
      children: [
        if (_errorMessage == null) webView else _buildErrorState(),
        if (_isLoading && _errorMessage == null)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF39495F)),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Failed to load Expedite Report',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (_failedUrl != null) ...[
              const SizedBox(height: 8),
              Text(
                _failedUrl!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF39495F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebUnsupported() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'WebView is for Android/iOS.\n'
              'On Flutter Web, open the React app directly:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            SelectableText(
              reportUrl,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
