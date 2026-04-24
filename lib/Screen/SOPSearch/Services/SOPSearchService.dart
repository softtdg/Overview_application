import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class SOPSearchService {
  const SOPSearchService();

  Future<Response<dynamic>> SOPSearch({required String SOP}) {

    return Dioservices.dio.get(
      '/sopSearch/SOPSerchService',
      queryParameters: {"SOPNumber": SOP.trim()},
      options: Options(headers: Dioservices.dio.options.headers),
    );
  }
}
