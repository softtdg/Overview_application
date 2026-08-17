import 'package:dio/dio.dart';
import 'package:overview_app/Services/api_cache.dart';
import 'package:overview_app/Services/api_cache_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dioservices {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: "http://192.168.1.17:8080/api",
      headers: {"Content-Type": "application/json"},
    ),
  );

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await ApiCache.instance.init();
    dio.interceptors.removeWhere((i) => i is ApiCacheInterceptor);
    dio.interceptors.add(ApiCacheInterceptor());
  }

  // Set token before request
  static Future<void> setToken() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    if (token != null && token.isNotEmpty) {
      final cleanToken = token.trim();
      dio.options.headers["authentication"] = cleanToken;
      dio.options.headers["Authorization"] = "Bearer $cleanToken";
    } else {
      dio.options.headers.remove("authentication");
      dio.options.headers.remove("Authorization");
    }
  }
}
