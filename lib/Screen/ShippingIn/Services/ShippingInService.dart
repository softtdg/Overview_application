import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class ShippingInService {
  const ShippingInService();

  Future<Response<dynamic>> ShippingInHistory() async {
    try {
      final resposne = await Dioservices.dio.get('/shipping/in/history');
      return resposne;
    } catch (e) {
      throw Exception("Error in Shipping in $e");
    }
  }

  Future<Response<dynamic>> EditShippingInDate(String SOP) async {
    try {
      final resposne = await Dioservices.dio.post(
        '/shipping/in/edit',
        data: {'sopNumbers': SOP},
      );
      return resposne;
    } catch (e) {
      throw Exception("Error in Search Shipping in $e");
    }
  }

  Future<Response<dynamic>> SearchShippingIn(String sopNumber) async {
    try {
      final resposne = await Dioservices.dio.post(
        '/shipping/edit/search',
        data: {'sopNumber': sopNumber},
      );
      return resposne;
    } catch (e) {
      throw Exception("Error in Search Shipping in $e");
    }
  }

  Future<Response<dynamic>> EditDate(String SOP, String fromQADate) async {
    try {
      final resposne = await Dioservices.dio.post(
        '/shipping/in/edit/date',
        data: {'sopNumber': SOP, 'fromQADate': fromQADate},
      );
      return resposne;
    } catch (e) {
      throw Exception("Error in Update Shipping in $e");
    }
  }
}
