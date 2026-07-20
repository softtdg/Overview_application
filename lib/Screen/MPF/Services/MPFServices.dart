import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class MPFServices {
  const MPFServices();

  Future<Response<dynamic>> SOPCheck(String SOP) async {
    try {
      final response = await Dioservices.dio.get(
        '/sopSearch/sopCheck?sopNumber=$SOP',
      );
      return response;
    } catch (e) {
      print("Error in SOPCheck api call $e");
      rethrow;
    }
  }

  Future<Response<dynamic>> SOPList(String SOP) async {
    try {
      final response = await Dioservices.dio.get(
        '/sopSearch/getSOPList?sopNumber=$SOP',
      );
      return response;
    } catch (e) {
      print("Error in getSOPList api call $e");
      rethrow;
    }
  }

  Future<Response<dynamic>> fixtureDetails({
    required String fixtureNumber,
    required String sopNumber,
    required String mpf,
    required String user,
  }) async {
    try {
      final response = await Dioservices.dio.get(
        '/sopSearch/fixtureDetails',
        queryParameters: {
          'fixtureNumber': fixtureNumber,
          'sopNumber': sopNumber,
          'mpf': mpf,
          'user': user,
        },
      );
      return response;
    } catch (e) {
      print("Error in picklist api call $e");
      rethrow;
    }
  }

  Future<Response<dynamic>> PickListData(String user, String fixture) async {
    try {
      final response = await Dioservices.dio.get(
        '/sopSearch/getPickListData?user=$user&fixture=$fixture',
      );
      return response;
    } catch (e) {
      print("Error in getPickListData api call $e");
      rethrow;
    }
  }

  Future<Response<dynamic>> PickListCount() async {
    try {
      final response = await Dioservices.dio.get('/sopSearch/pickListCount');
      return response;
    } catch (e) {
      print("Error in PickListCount $e");
      rethrow;
    }
  }

  Future<Response<dynamic>> searchPartNumber(String partNumber) async {
    try {
      final response = await Dioservices.dio.get(
        '/partNumber/search?partNumber=$partNumber',
      );
      return response;
    } catch (e) {
      print("Error in searchPartNumber api call $e");
      rethrow;
    }
  }

  Future<Response<dynamic>> magnifiedFixtureData(String tdgpn) async {
    try {
      final response = await Dioservices.dio.get(
        '/adminPartNumber/magnifiedFixtureData',
        queryParameters: {'tdgpn': tdgpn},
      );
      return response;
    } catch (e) {
      print("Error in magnifiedFixtureData api call $e");
      rethrow;
    }
  }

  Future<Response<dynamic>> inventoryPickList(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await Dioservices.dio.post(
        '/sopSearch/inventoryPickList',
        data: payload,
      );
      return response;
    } catch (e) {
      print("Error in inventoryPickList api call $e");
      rethrow;
    }
  }

  Future<Response<dynamic>> getFixtureDataFromLivePdm({
    required String sopNumber,
    required String fixtureNumber,
    required String user,
    String lhrEntryId = '',
  }) async {
    try {
      final response = await Dioservices.dio.get(
        '/sopSearch/mpfFixtureDataGetFromLivePdm',
        queryParameters: {
          'sopNumber': sopNumber,
          'fixtureNumber': fixtureNumber,
          'user': user,
          'lhrEntryId': lhrEntryId,
        },
      );
      return response;
    } on DioException catch (e) {
      print("STATUS CODE: ${e.response?.statusCode}");
      print("RESPONSE DATA: ${e.response?.data}");
      print("REQUEST URL: ${e.requestOptions.uri}");
      print("REQUEST HEADERS: ${e.requestOptions.headers}");
      rethrow;
    }
  }
}
