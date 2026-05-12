import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class QAEditServices {
  const QAEditServices();

  Future<Response<dynamic>> GetQAEditHistory() async {
    try {
      final response = await Dioservices.dio.get('/qa/getQAEditData');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch QA Edit history: $e');
    }
  }

  Future<Response<dynamic>> QAEditSOPById(String SOPId) async {
    try {
      final response = await Dioservices.dio.get('/qa/searchQaEditData/$SOPId');
      return response;
    } catch (e) {
      throw Exception('Failed to search QA Edit: $e');
    }
  }

  Future<Response<dynamic>> UpdateQAEdit(Map<String, dynamic> payload) async {
    try {
      final response = await Dioservices.dio.post(
        '/qa/updateQaEditData',
        data: payload,
      );
      return response;
    } catch (e) {
      throw Exception("Failed to call QA Edit update entry $e");
    }
  }
}
