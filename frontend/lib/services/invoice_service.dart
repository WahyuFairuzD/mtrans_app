import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/invoice.dart';
import '../utils/invoice_format.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

class InvoiceService {
  InvoiceService._() {
    AuthService.instance.addListener(() {
      if (AuthService.instance.user == null) _signatureCache.clear();
    });
  }
  static final InvoiceService instance = InvoiceService._();

  Dio get _dio => ApiClient.dio;

  final Map<String, Future<Uint8List>> _signatureCache = {};

  Future<InvoicePreview> preview({
    required int branchId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final res = await _dio.get(
        '/invoices/preview',
        queryParameters: {
          'branch_id': branchId,
          'from': isoDate(from),
          'to': isoDate(to),
        },
      );
      return InvoicePreview.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<({Invoice invoice, int skippedCount})> create({
    required int branchId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required DateTime invoiceDate,
    required DateTime dueDate,
    int? number,
    required Uint8List signaturePng,
  }) async {
    try {
      final form = FormData.fromMap({
        'branch_id': branchId.toString(),
        'period_start': isoDate(periodStart),
        'period_end': isoDate(periodEnd),
        'invoice_date': isoDate(invoiceDate),
        'due_date': isoDate(dueDate),
        if (number != null) 'number': number.toString(),
        'signature': MultipartFile.fromBytes(
          signaturePng,
          filename: 'signature.png',
          contentType: DioMediaType.parse('image/png'),
        ),
      });
      final res = await _dio.post(
        '/invoices',
        data: form,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          sendTimeout: const Duration(minutes: 1),
          receiveTimeout: const Duration(minutes: 1),
        ),
      );
      final body = res.data as Map<String, dynamic>;
      return (
        invoice: Invoice.fromJson(body['invoice'] as Map<String, dynamic>),
        skippedCount: (body['skipped_count'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Invoice>> fetchList({
    int? branchId,
    InvoiceStatus? status,
    int offset = 0,
    int limit = 50,
  }) async {
    try {
      final res = await _dio.get(
        '/invoices',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (branchId != null) 'branch_id': branchId,
          if (status != null) 'status': status.apiValue,
        },
      );
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(Invoice.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Invoice> fetchDetail(String id) async {
    try {
      final res = await _dio.get('/invoices/$id');
      final body = res.data as Map<String, dynamic>;
      return Invoice.fromJson(body['invoice'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Invoice> voidInvoice(String id) async {
    try {
      final res = await _dio.post('/invoices/$id/void');
      final body = res.data as Map<String, dynamic>;
      return Invoice.fromJson(body['invoice'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Uint8List> signatureBytes(String id) =>
      _signatureCache.putIfAbsent(id, () => _loadSignature(id));

  Future<Uint8List> _loadSignature(String id) async {
    try {
      final res = await _dio.get<List<int>>(
        '/invoices/$id/signature',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const <int>[]);
    } on DioException catch (e) {
      _signatureCache.remove(id);
      throw ApiException.fromDio(e);
    }
  }
}
