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

  Future<Response<dynamic>> SOPById(String SOPId) async {
    try {
      final response = await Dioservices.dio.get('/shipping/bySOPId/$SOPId');
      return response;
    } catch (e) {
      print("Error in Shipping Out API Call $e");
      throw Exception("Error in Shipping Out API Call $e");
    }
  }

  Future<Response<dynamic>> Locations() async {
    try {
      final response = await Dioservices.dio.get('/shipping/locations');
      return response;
    } catch (e) {
      throw Exception("Error in Shipping Out Location API Call $e");
    }
  }

  Future<Response<dynamic>> ProdMgr() async {
    try {
      final response = await Dioservices.dio.get('/shipping/prodMgr');
      return response;
    } catch (e) {
      throw Exception("Error in Shipping Out Prod Mgr API Call $e");
    }
  }

  Future<Response<dynamic>> UpdateShippingOut(
    String SOPId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await Dioservices.dio.post(
        '/shipping/edit?SOPId=$SOPId',
        data: payload,
      );
      return response;
    } catch (e) {
      throw Exception("Error in Shipping Out Update API Call $e");
    }
  }
}
