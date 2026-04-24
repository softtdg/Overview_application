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

    if (token != null) {
      dio.options.headers["authentication"] = token;
    }
    print("TOKEN: ${Dioservices.dio.options.headers["authentication"]}");
  }
}