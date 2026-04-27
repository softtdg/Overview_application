import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class OpenItemsServices {
  const OpenItemsServices();

  Future<Response<dynamic>> SearchOpenItemsSOP({
    String? SOP,
    String? leadHandEntryId,
  }) async {
    try {
      final response = await Dioservices.dio.get(
        '/sopSearch/getSOPList',
        queryParameters: {
          'sopNumber': SOP,
          'SOPLeadHandEntryId': leadHandEntryId,
        },
      );
      return response;
    } catch (e) {
      throw Exception("Error in Search Open Items $e");
    }
  }

  Future<Response<dynamic>> SearchOpenItemsByFixtureId({
    required String sopLeadHandEntryId,
  }) async {
    try {
      final response = await Dioservices.dio.get(
        '/partInventory/specificInventoryData/$sopLeadHandEntryId',
      );
      return response;
    } catch (e) {
      throw Exception("Error in Search Open Items by SOP Lead Hand Entry Id $e");
    }
  }
}
