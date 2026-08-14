import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class ShippingInService {
  const ShippingInService();

  Future<Response<dynamic>> ShippingInHistory() async {
    try {
      final resposne = await Dioservices.dio.get('/shipping/in/history');
      return resposne;
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception("Error in Shipping in");
    }
  }

  Future<Response<dynamic>> EditShippingInDate(String SOP) async {
    try {
      final resposne = await Dioservices.dio.post(
        '/shipping/in/edit',
        data: {'sopNumbers': SOP},
      );
      return resposne;
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception("Error updating shipping in date");
    }
  }

  Future<Response<dynamic>> SearchShippingIn(String sopNumber) async {
    try {
      final resposne = await Dioservices.dio.post(
        '/shipping/edit/search',
        data: {'sopNumber': sopNumber},
      );
      return resposne;
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception("Error searching shipping in");
    }
  }

  Future<Response<dynamic>> EditDate(String SOP, String fromQADate) async {
    try {
      final resposne = await Dioservices.dio.post(
        '/shipping/in/edit/date',
        data: {'sopNumber': SOP, 'fromQADate': fromQADate},
      );
      return resposne;
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception("Error updating shipping in");
    }
  }
}
