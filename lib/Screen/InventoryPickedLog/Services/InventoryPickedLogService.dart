import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class InventoryPickedLogService {
  const InventoryPickedLogService();

  /// status: 0 = pending, 1 = accepted picked, 2 = rejected void.
  /// pickListNumber is optional and used for search.
  Future<Response<dynamic>> InventroyService({
    int status = 0,
    String? pickListNumber,
  }) async {
    try {
      final queryParameters = <String, dynamic>{'status': status};
      if (pickListNumber != null && pickListNumber.trim().isNotEmpty) {
        queryParameters['pickListNumber'] = pickListNumber.trim();
      }

      final response = await Dioservices.dio.get(
        '/sopSearch/allInventoryPickLists',
        queryParameters: queryParameters,
      );
      return response;
    } catch (e) {
      throw Exception("Error in Inventory Picked Log : $e");
    }
  }

  Future<Response<dynamic>> ViewInventoryPickListService(String id) async {
    try {
      final response = await Dioservices.dio.get(
        '/sopSearch/inventoryPickList/$id',
      );
      return response;
    } catch (e) {
      throw Exception("Error in Inventory Picked Log : $e");
    }
  }

  Future<Response<dynamic>> AcceptInventory(
    String id, {
    required List<Map<String, dynamic>> sheetData,
  }) async {
    try {
      return await Dioservices.dio.put(
        '/sopSearch/acceptInventoryPickList/$id',
        data: <String, dynamic>{'sheetData': sheetData},
      );
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception('Error in Accept Inventory Picked Log : $e');
    }
  }

  Future<Response<dynamic>> RejectInventory(
    String id, {
    required List<Map<String, dynamic>> sheetData,
  }) async {
    try {
      return await Dioservices.dio.put(
        '/sopSearch/rejectInventoryPickList/$id',
        data: <String, dynamic>{'sheetData': sheetData},
      );
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception('Error in Reject Inventory Picked Log : $e');
    }
  }
}