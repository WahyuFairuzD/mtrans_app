import 'package:dio/dio.dart';
import '../models/stock.dart';
import 'api_client.dart';
import 'api_exception.dart';

const int stockPageSize = 100;

class StockService {
  StockService._();

  static final StockService instance = StockService._();

  Dio get _dio => ApiClient.dio;

  Future<({List<StockItem> items, int changesToday})> fetchItems() async {
    try {
      final res = await _dio.get('/stock/items');
      final body = res.data as Map<String, dynamic>;
      final items = (body['data'] as List)
          .map((e) => StockItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final summary = body['summary'] as Map<String, dynamic>;
      return (
        items: items,
        changesToday: (summary['changes_today'] as num).toInt(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<StockChange> createItem({
    required String name,
    required String category,
    required String unit,
    int initialQuantity = 0,
  }) async {
    try {
      final res = await _dio.post(
        '/stock/items',
        data: {
          'name': name,
          'category': category,
          'unit': unit,
          'initial_quantity': initialQuantity,
        },
      );
      return _parseChange(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<StockChange> adjust({
    required String itemId,
    required int amount,
    required bool isAdd,
    String? message,
  }) async {
    try {
      final res = await _dio.post(
        '/stock/items/$itemId/adjust',
        data: {
          'action': isAdd ? 'add' : 'subtract',
          'amount': amount,
          if (message != null && message.isNotEmpty) 'message': message,
        },
      );
      return _parseChange(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<StockMovement>> fetchMovements({
    DateTime? from,
    DateTime? to,
    int offset = 0,
    int limit = stockPageSize,
  }) async {
    try {
      final res = await _dio.get(
        '/stock/movements',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (from != null) 'from': _wibIso(from, endOfDay: false),
          if (to != null) 'to': _wibIso(to, endOfDay: true),
        },
      );
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) => StockMovement.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  StockChange _parseChange(Map<String, dynamic> body) {
    final movement = body['movement'];
    return (
      item: StockItem.fromJson(body['item'] as Map<String, dynamic>),
      movement: movement == null
          ? null
          : StockMovement.fromJson(movement as Map<String, dynamic>),
    );
  }

  String _wibIso(DateTime d, {required bool endOfDay}) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final time = endOfDay ? '23:59:59.999' : '00:00:00';
    return '$y-$m-${day}T$time+07:00';
  }
}