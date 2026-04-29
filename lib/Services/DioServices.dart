import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dioservices {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: "http://192.168.1.7:8080/api",
      headers: {"Content-Type": "application/json"},
    ),
  );

  // Set token before request
  static Future<void> setToken() async {
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
    print("TOKEN(auth): ${Dioservices.dio.options.headers["authentication"]}");
    print("TOKEN(authorization): ${Dioservices.dio.options.headers["Authorization"]}");
  }
}