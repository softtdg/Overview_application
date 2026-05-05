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
}
