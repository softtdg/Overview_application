import 'package:dio/dio.dart';
import '../../../Services/DioServices.dart';

class LoginService {
  const LoginService();

  Future<Response<dynamic>> login({
    required String username,
    required String password,
  }) {
    final payload = {
      'UserName': username.trim(),
      'Password': password.trim(),
    };

    return Dioservices.dio.post(
      '/auth/login',
      data: payload,
      // Some backends read credentials from query params instead of body.
      queryParameters: payload,
      options: Options(contentType: Headers.jsonContentType),
    );
  }
}
