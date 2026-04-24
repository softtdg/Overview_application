import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class Publicsearchservice {
  const Publicsearchservice();

  Future<Response<dynamic>> PublicSearchService({
    required String fixtureNumber,
    // required String user,
  }) async {
    try {
      final response = await Dioservices.dio.get(
        // http://192.168.2.108:7070/api/admin/190-100-1436
        '/admin/$fixtureNumber',
        // queryParameters: {'fixtureNumber': fixtureNumber, 'user': user},
      );

      return response;
    } catch (e) {
      throw Exception("Error In Public Search API: $e");
    }
  }

  Future<Response<dynamic>> FixtureDetailsService({
    required String fixtureNumber,
    required String user,
  }) async {
    try {
      final response = await Dioservices.dio.get(
        '/sopSearch/fixtureDetails',
        queryParameters: {'fixtureNumber': fixtureNumber, 'user': user},
      );

      return response;
    } catch (e) {
      throw Exception("Error In Fixture Details API: $e");
    }
  }
}
