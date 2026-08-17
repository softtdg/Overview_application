import 'package:dio/dio.dart';
import 'package:overview_app/Services/api_cache.dart';

/// Caches successful GET responses. Writes (POST/PUT/PATCH/DELETE) drop the cache
/// so lists refresh after an update. Offline / failed GETs fall back to stale cache.
class ApiCacheInterceptor extends Interceptor {
  ApiCacheInterceptor({ApiCache? cache}) : _cache = cache ?? ApiCache.instance;

  final ApiCache _cache;

  static const Duration defaultTtl = Duration(minutes: 3);
  static const Duration lookupTtl = Duration(minutes: 30);

  static const _skipPaths = {
    '/auth/login',
  };

  Duration _ttlFor(String path) {
    if (path.contains('/locations') || path.contains('/prodMgr')) {
      return lookupTtl;
    }
    return defaultTtl;
  }

  String _key(RequestOptions options) {
    final uri = options.uri;
    final query = Map<String, dynamic>.from(uri.queryParameters);
    final keys = query.keys.toList()..sort();
    final q = keys.map((k) => '$k=${query[k]}').join('&');
    return '${options.method}|${uri.path}?$q';
  }

  bool _shouldCache(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return false;
    if (options.extra['noCache'] == true) return false;
    final path = options.uri.path;
    for (final skip in _skipPaths) {
      if (path.contains(skip)) return false;
    }
    return true;
  }

  bool _isWrite(String method) {
    switch (method.toUpperCase()) {
      case 'POST':
      case 'PUT':
      case 'PATCH':
      case 'DELETE':
        return true;
      default:
        return false;
    }
  }

  Response<dynamic> _toResponse(RequestOptions options, ApiCacheEntry entry) {
    return Response<dynamic>(
      requestOptions: options,
      data: entry.data,
      statusCode: entry.statusCode,
      extra: {
        ...options.extra,
        'fromCache': true,
      },
    );
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_shouldCache(options) || options.extra['refresh'] == true) {
      handler.next(options);
      return;
    }
    try {
      final entry = await _cache.get(_key(options));
      if (entry != null && entry.isFresh(_ttlFor(options.uri.path))) {
        handler.resolve(_toResponse(options, entry));
        return;
      }
    } catch (_) {}
    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    try {
      if (_shouldCache(options) &&
          response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        await _cache.set(
          _key(options),
          ApiCacheEntry(
            savedAt: DateTime.now(),
            statusCode: response.statusCode!,
            data: response.data,
          ),
        );
      } else if (_isWrite(options.method) &&
          response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        await _cache.clear();
      }
    } catch (_) {}
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (_shouldCache(options)) {
      try {
        final entry = await _cache.get(_key(options));
        if (entry != null) {
          handler.resolve(_toResponse(options, entry));
          return;
        }
      } catch (_) {}
    }
    handler.next(err);
  }
}
