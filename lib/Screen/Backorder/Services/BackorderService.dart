import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class BackorderService {
  const BackorderService();

  Future<Response<dynamic>> criticalItemList() async {
    try {
        final response = await Dioservices.dio.get("/partInventory/criticalOpenItemsList");
        return response;
    } catch (e) {
      print('Error in criticalItemList API Call: $e');
      rethrow;
    }
  }

  Future<Response<dynamic>> backOrderUpdate(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await Dioservices.dio.patch(
        "/backorder/update",
        data: payload,
      );
      return response;
    } on DioException catch (e) {
      print('Error in backOrderUpdate API Call: ${e.message}');
      print('Status: ${e.response?.statusCode}');
      print('Server body: ${e.response?.data}');
      rethrow;
    } catch (e) {
      print('Error in backOrderUpdate API Call: $e');
      rethrow;
    }
  }
}
