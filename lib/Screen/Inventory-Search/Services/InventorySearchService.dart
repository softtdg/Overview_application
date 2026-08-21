import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class InventorySearchService {
  const InventorySearchService();

  Future<Response<dynamic>> searchPart({required String tdgpn}) async {
    try {
      final response = await Dioservices.dio.get(
        '/partInventory/search',
        queryParameters: {'TDGPN': tdgpn},
      );
      return response;
    } catch (e) {
      throw Exception("Error in Search Invetory API: $e");
    }
  }

  Future<Response<dynamic>> getSearchPartInventory({
    required String tdgpn,
  }) async {
    try {
      final response = await Dioservices.dio.get('/partInventory/$tdgpn');
      return response;
    } catch (e) {
      throw Exception("Error in Get Search Part Inventory API: $e");
    }
  }
}
