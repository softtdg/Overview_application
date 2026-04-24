import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class PickedHistoryService {
  const PickedHistoryService();

  Future<Response<dynamic>> PickedLogHistoryService() async {
    try {
      final response = await Dioservices.dio.get('/pickedLog/list');

      return response;
    } catch (e) {
      throw Exception("Error in Picked History : $e");
    }
  }
}
