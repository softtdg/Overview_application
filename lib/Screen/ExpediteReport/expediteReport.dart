import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:overview_app/Widgets/CommonAppBar.dart';
import 'package:path_provider/path_provider.dart';
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
            await _interceptBlobDownloads();

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

    _controller.addJavaScriptChannel(
      'FlutterDownload',
      onMessageReceived: _handleBlobDownload,
    );

    await _configureAndroidWebView();
    await _loadReport();
  }

  Future<void> _handleBlobDownload(JavaScriptMessage message) async {
    try {
      final json = jsonDecode(message.message);
      final base64Data = json['data'] as String;
      var fileName = (json['fileName'] as String?)?.trim();
      if (fileName == null || fileName.isEmpty) {
        fileName = 'Expedite_Report.xlsx';
      }

      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty) {
        throw Exception('Downloaded file is empty');
      }

      final dir = await _downloadDirectory();
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';
      await File(filePath).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to Downloads/$fileName')),
      );
    } catch (e) {
      debugPrint('Blob download error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<Directory> _downloadDirectory() async {
    if (Platform.isAndroid) {
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (await publicDownloads.exists()) {
        return publicDownloads;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  static const MethodChannel _filePickerChannel =
      MethodChannel('overview_app/file_picker');

  Future<void> _configureAndroidWebView() async {
    final platform = _controller.platform;
    if (platform is! AndroidWebViewController) return;

    AndroidWebViewController.enableDebugging(false);
    platform.setMediaPlaybackRequiresUserGesture(false);

    // Without this, React <input type="file"> cannot open Android file picker.
    await platform.setOnShowFileSelector(_androidFilePicker);
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    try {
      // Verify native channel is registered (requires full app reinstall after Kotlin changes).
      try {
        final ping = await _filePickerChannel.invokeMethod<String>('ping');
        if (ping != 'ok') {
          throw Exception('Native file picker not ready');
        }
      } on MissingPluginException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'App needs full reinstall for file upload.\n'
                'Stop the app, then run: flutter run',
              ),
              duration: Duration(seconds: 6),
            ),
          );
        }
        return <String>[];
      }

      final allowMultiple = params.mode == FileSelectorMode.openMultiple;
      final picked = await _filePickerChannel.invokeMethod<List<dynamic>>(
        'pickFiles',
        {'allowMultiple': allowMultiple},
      );

      if (picked == null || picked.isEmpty) {
        return <String>[];
      }

      final uris =
          picked.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      debugPrint('WebView file picker selected: $uris');
      return uris;
    } catch (e, st) {
      debugPrint('Android file picker error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File picker failed: $e')),
        );
      }
      return <String>[];
    }
  }

  Future<void> _interceptBlobDownloads() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          if (window.__flutterBlobIntercepted) return;
          window.__flutterBlobIntercepted = true;

          var origCreateObjectURL = URL.createObjectURL;
          URL.createObjectURL = function(blob) {
            var url = origCreateObjectURL.call(URL, blob);
            window.__lastBlobUrl = url;
            window.__lastBlob = blob;
            return url;
          };

          var origOpen = window.open;
          window.open = function(url) {
            if (url && url.toString().startsWith('blob:')) {
              var blob = window.__lastBlob;
              if (blob) {
                var reader = new FileReader();
                reader.onloadend = function() {
                  var base64 = reader.result.split(',')[1];
                  FlutterDownload.postMessage(JSON.stringify({
                    data: base64,
                    fileName: 'expedite_report.xlsx'
                  }));
                };
                reader.readAsDataURL(blob);
                return null;
              }
            }
            return origOpen.apply(window, arguments);
          };

          var origClick = HTMLAnchorElement.prototype.click;
          HTMLAnchorElement.prototype.click = function() {
            if (this.href && this.href.startsWith('blob:')) {
              var fileName = this.download || 'expedite_report.xlsx';
              var blobUrl = this.href;
              var xhr = new XMLHttpRequest();
              xhr.open('GET', blobUrl, true);
              xhr.responseType = 'blob';
              xhr.onload = function() {
                var reader = new FileReader();
                reader.onloadend = function() {
                  var base64 = reader.result.split(',')[1];
                  FlutterDownload.postMessage(JSON.stringify({
                    data: base64,
                    fileName: fileName
                  }));
                };
                reader.readAsDataURL(xhr.response);
              };
              xhr.send();
              return;
            }
            return origClick.apply(this, arguments);
          };
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
      resizeToAvoidBottomInset: false,
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
