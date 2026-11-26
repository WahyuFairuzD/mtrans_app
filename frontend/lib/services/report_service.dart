import 'package:dio/dio.dart';
import '../models/operational_report.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Laporan inspeksi untuk Pengawas Operational.
class ReportService {
  ReportService._();

  static final ReportService instance = ReportService._();

  Dio get _dio => ApiClient.dio;

  Future<List<ReportableBus>> fetchBuses({int limit = 100}) async {
    try {
      final res = await _dio.get('/reports/buses', queryParameters: {'limit': limit});
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(ReportableBus.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Laporan tersimpan untuk satu pekerjaan, atau null bila belum ada.
  Future<OperationalReport?> fetchReport(String jobId) async {
    try {
      final res = await _dio.get('/reports/$jobId');
      final body = res.data as Map<String, dynamic>;
      final report = body['report'] as Map<String, dynamic>?;
      return report == null ? null : OperationalReport.fromJson(report);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<OperationalReport> saveReport(
    String jobId,
    OperationalReport report,
  ) async {
    try {
      final res = await _dio.put('/reports/$jobId', data: report.toJson());
      final body = res.data as Map<String, dynamic>;
      return OperationalReport.fromJson(body['report'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ReportSigner?> fetchSigner() async {
    try {
      final res = await _dio.get('/reports/signer');
      final body = res.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      return data == null ? null : ReportSigner.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ReportSigner> saveSigner(ReportSigner signer) async {
    try {
      final res = await _dio.put(
        '/reports/signer',
        data: {
          'qc_name': signer.qcName,
          'qc_signature': signer.qcSignature,
          'operational_name': signer.operationalName,
          'operational_signature': signer.operationalSignature,
        },
      );
      final body = res.data as Map<String, dynamic>;
      return ReportSigner.fromJson(body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
