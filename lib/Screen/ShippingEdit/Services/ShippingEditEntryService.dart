import 'package:dio/dio.dart';
import 'package:overview_app/Services/DioServices.dart';

class ShippingEditEntryService {
  const ShippingEditEntryService();

  Future<Response<dynamic>> ShippingSearchSOP(String sopNumber) async {
    try {
      final response = await Dioservices.dio.post(
        '/shipping/edit/search',
        data: {'sopNumber': sopNumber},
      );
      return response;
    } catch (e) {
      throw Exception("Error in Shipping Edit Search API Call $e");
    }
  }
}
