import 'package:dio/dio.dart';
import '../models/vehicle_type.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Harga cuci per jenis kendaraan (khusus Owner).
class PriceService {
  PriceService._();
  static final PriceService instance = PriceService._();

  Dio get _dio => ApiClient.dio;

  Future<PriceList> fetchPrices() async {
    try {
      final res = await _dio.get('/prices');
      return _parse(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PriceList> savePrices(PriceList prices) async {
    try {
      final res = await _dio.put(
        '/prices',
        data: {for (final entry in prices.entries) entry.key.apiValue: entry.value},
      );
      return _parse(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  PriceList _parse(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>;
    return {
      for (final type in VehicleType.values)
        type: (data[type.apiValue] as num).toInt(),
    };
  }
}
