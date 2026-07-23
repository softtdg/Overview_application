import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
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

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _openedReportAfterLogin = false;
  String? _errorMessage;
  String? _failedUrl;

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

  bool _isLoginUrl(String url) {
    final path = (Uri.tryParse(url)?.path ?? '').toLowerCase();
    return path.contains('login');
  }

  bool _isReportUrl(String url) {
    final path = (Uri.tryParse(url)?.path ?? '').toLowerCase();
    return path.contains('expedite-report');
  }

  Future<void> _initWebView() async {
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
            await _fixLoginPasswordTyping();
            await _hideReactTopHeader();
            await _hideUploadExportButtons();
            await _enableLiveTableSearch();

            // After React login succeeds, it often lands on `/` (blank).
            // Send the user to the actual report page once.
            if (!_isLoginUrl(url) &&
                !_isReportUrl(url) &&
                !_openedReportAfterLogin) {
              _openedReportAfterLogin = true;
              await _controller.loadRequest(Uri.parse(reportUrl));
              return;
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

    await _configureAndroidWebView();
    await _loadReport();
  }

  Future<void> _configureAndroidWebView() async {
    final platform = _controller.platform;
    if (platform is! AndroidWebViewController) return;

    AndroidWebViewController.enableDebugging(false);
    platform.setMediaPlaybackRequiresUserGesture(false);
  }

  /// Keep input type="password" (changing it breaks React). Unlock on focus so
  /// Autofill cannot steal the Android InputConnection before the user types.
  Future<void> _fixLoginPasswordTyping() async {
    try {
      await _controller.runJavaScript('''
        (function () {
          function unlock(el) {
            try { el.removeAttribute('readonly'); } catch (e) {}
          }

          function patch(el) {
            if (!el || el.__flutterPwPatched) return;
            el.__flutterPwPatched = true;
            try {
              el.setAttribute('autocomplete', 'off');
              el.setAttribute('autocorrect', 'off');
              el.setAttribute('autocapitalize', 'off');
              el.setAttribute('spellcheck', 'false');
              el.setAttribute('readonly', 'true');
              el.addEventListener('touchstart', function () { unlock(el); }, { passive: true });
              el.addEventListener('mousedown', function () { unlock(el); });
              el.addEventListener('focus', function () { unlock(el); });
            } catch (e) {}
          }

          function patchAll(root) {
            (root || document).querySelectorAll('input[type="password"]').forEach(patch);
          }

          patchAll(document);
          if (window.__flutterPwObserver) return;
          window.__flutterPwObserver = new MutationObserver(function (mutations) {
            mutations.forEach(function (m) {
              m.addedNodes.forEach(function (n) {
                if (!n || n.nodeType !== 1) return;
                if (n.matches && n.matches('input[type="password"]')) patch(n);
                if (n.querySelectorAll) patchAll(n);
              });
            });
          });
          window.__flutterPwObserver.observe(document.documentElement, {
            childList: true,
            subtree: true
          });
        })();
      ''');
    } catch (_) {}
  }

  /// Hides the React site grey bar (TEST OVERVIEW / Logout). Flutter already
  /// has Digital Wall + drawer, so that duplicate header is not needed.
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

  /// Hide React Upload / Export controls in the Flutter WebView.
  Future<void> _hideUploadExportButtons() async {
    try {
      await _controller.runJavaScript('''
        (function () {
          function normalize(text) {
            return (text || '').replace(/\\s+/g, ' ').trim().toLowerCase();
          }

          function hideUploadExport() {
            if (!document.getElementById('flutter-hide-upload-export-style')) {
              var style = document.createElement('style');
              style.id = 'flutter-hide-upload-export-style';
              style.textContent = [
                'button[aria-label*="Upload" i],',
                'button[aria-label*="Export" i],',
                'a[aria-label*="Upload" i],',
                'a[aria-label*="Export" i] {',
                '  display: none !important;',
                '}'
              ].join('\\n');
              document.head.appendChild(style);
            }

            document.querySelectorAll('button, a, [role="button"]').forEach(function (el) {
              if (!el || el.dataset.flutterUploadExportHidden === '1') return;

              var label = normalize(el.innerText || el.textContent || el.getAttribute('aria-label') || '');
              if (label !== 'upload' && label !== 'export') return;

              el.style.setProperty('display', 'none', 'important');
              el.style.setProperty('visibility', 'hidden', 'important');
              el.style.setProperty('pointer-events', 'none', 'important');
              el.dataset.flutterUploadExportHidden = '1';
            });
          }

          hideUploadExport();

          if (!window.__flutterHideUploadExportObserver) {
            window.__flutterHideUploadExportObserver = new MutationObserver(function () {
              hideUploadExport();
            });
            window.__flutterHideUploadExportObserver.observe(document.documentElement, {
              childList: true,
              subtree: true
            });
          }
        })();
      ''');
    } catch (_) {}
  }

  /// React search only runs on Enter. Fire Enter automatically while typing
  /// so the table filters as the user types (debounced).
  Future<void> _enableLiveTableSearch() async {
    try {
      await _controller.runJavaScript('''
        (function () {
          function fireEnter(el) {
            ['keydown', 'keypress', 'keyup'].forEach(function (type) {
              el.dispatchEvent(new KeyboardEvent(type, {
                key: 'Enter',
                code: 'Enter',
                keyCode: 13,
                which: 13,
                bubbles: true,
                cancelable: true
              }));
            });
            if (el.form) {
              el.form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
            }
          }

          function patchSearchInput(el) {
            if (!el || el.__flutterLiveSearch) return;
            el.__flutterLiveSearch = true;

            var placeholder = (el.getAttribute('placeholder') || '');
            if (placeholder.indexOf('Press Enter') !== -1) {
              el.setAttribute(
                'placeholder',
                placeholder.replace(/\\s*\\(Press Enter\\)\\s*/i, '').trim() || 'Search in table...'
              );
            }

            var timer = null;
            el.addEventListener('input', function () {
              if (timer) clearTimeout(timer);
              timer = setTimeout(function () {
                fireEnter(el);
              }, 350);
            });
          }

          function findAndPatch() {
            document.querySelectorAll('input[type="search"], input[type="text"], input:not([type])').forEach(function (el) {
              var ph = (el.getAttribute('placeholder') || '').toLowerCase();
              var aria = (el.getAttribute('aria-label') || '').toLowerCase();
              var looksLikeSearch =
                ph.indexOf('search') !== -1 ||
                ph.indexOf('press enter') !== -1 ||
                aria.indexOf('search') !== -1;
              if (looksLikeSearch) patchSearchInput(el);
            });
          }

          findAndPatch();

          if (!window.__flutterLiveSearchObserver) {
            window.__flutterLiveSearchObserver = new MutationObserver(function () {
              findAndPatch();
            });
            window.__flutterLiveSearchObserver.observe(document.documentElement, {
              childList: true,
              subtree: true
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
      _openedReportAfterLogin = false;
    });

    await _controller.loadRequest(Uri.parse(reportUrl));
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
      resizeToAvoidBottomInset: true,
      appBar: const CommonAppBar(),
      drawer: const CommonDrawer(),
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
        // IgnorePointer so a stuck/flickering loader never blocks keyboard input.
        if (_isLoading && _errorMessage == null)
          const IgnorePointer(
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF39495F)),
            ),
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
