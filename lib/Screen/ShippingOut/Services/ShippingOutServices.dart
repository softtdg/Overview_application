import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class ShippingOutService {
  const ShippingOutService();

  Future<Response<dynamic>> ShippingOutHistory() async {
    try {
      final resposne = await Dioservices.dio.get('/shipping/history');
      return resposne;
    } catch (e) {
      throw Exception("Error in Shipping Out API Call $e");
    }
  }

  Future<Response<dynamic>> EditSOPNums(String SOP) async {
    try {
      final response = await Dioservices.dio.post(
        '/shipping/sopNums',
        data: {'sops': SOP},
      );
      return response;
    } catch (e) {
      throw Exception("Error in Shipping Out API Call $e");
    }
  }
}
