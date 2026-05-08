import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class QAInService {
  const QAInService();

  Future<Response<dynamic>> QAInHistory() async {
    try {
      final response = await Dioservices.dio.get('/qa/history');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch QA In history: $e');
    }
  }

  Future<Response<dynamic>> QAInSearch(String SOP) async {
    try {
      final response = await Dioservices.dio.post(
        '/qa/history/',
        data: {'SOPNum': SOP},
      );
      return response;
    } catch (e) {
      throw Exception('Failed to fetch QA In details: $e');
    }
  }

  Future<Response<dynamic>> UpdateQAInDate(String SOP) async {
    try {
      final response = await Dioservices.dio.post(
        '/qa/updateQAInDate',
        data: {'sopNumber': SOP},
      );
      return response;
    } catch (e) {
      throw Exception('Failed to submit QA In data: $e');
    }
  }

  Future<Response<dynamic>> QAInSOPById(String SOPId) async {
    try {
      final response = await Dioservices.dio.get('/qa/edit/$SOPId');
      return response;
    } catch (e) {
      throw Exception('Failed to fetch QA In SOP by ID: $e');
    }
  }
}
