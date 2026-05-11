import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class QAOutService {
  const QAOutService();

  Future<Response<dynamic>> QAOutHistory() async {
    try {
      final response = await Dioservices.dio.get('/qa/getQCOutHistory');
      return response;
    } catch (e) {
      throw Exception('Failed to call QA Out history: $e');
    }
  }

  Future<Response<dynamic>> QAOutSearch(String SOP) async {
    try {
      final resposne = await Dioservices.dio.post(
        '/qa/featchQCOutData',
        data: {'SOPNum': SOP},
      );
      return resposne;
    } catch (e) {
      throw Exception('Failed to call QA Out search: $e');
    }
  }

  Future<Response<dynamic>> UpdateQCOutDate(String SOP) async {
    try {
      final response = await Dioservices.dio.post(
        '/qa/update-qa-out',
        data: {'var': SOP},
      );
      return response;
    } catch (e) {
      throw Exception('Failed to call QA Out update: $e');
    }
  }

  Future<Response<dynamic>> QAOutSOPById(String SOPId) async {
    try {
      final response = await Dioservices.dio.get(
        '/qa/getQCOutDataForEdit/$SOPId',
      );
      return response;
    } catch (e) {
      throw Exception('Failed to call QA Out SOP by ID: $e');
    }
  }

  Future<Response<dynamic>> UpdateQAOutEntry(
    Map<String, dynamic> payload,
  ) async {
    try {
      final resposne = await Dioservices.dio.post(
        '/qa/updateQCOutEntry',
        data: payload,
      );
      return resposne;
    } catch (e) {
      throw Exception('Failed to call QA Out update entry: $e');
    }
  }
}
