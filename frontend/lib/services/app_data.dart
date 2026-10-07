import 'package:flutter/foundation.dart';
import '../models/bus_wash.dart';
import '../utils/wib.dart';
import 'api_exception.dart';
import 'auth_service.dart';
import 'job_service.dart';

class AppData extends ChangeNotifier {
  AppData._() {
    AuthService.instance.addListener(_onAuthChanged);
  }

  static final AppData instance = AppData._();

  List<BusWash> _buses = [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  int _generation = 0;
  List<BusWash> get buses => List.unmodifiable(_buses);
  List<BusWash> get operational => _buses
      .where((b) => b.date == kToday || b.status != WashStatus.unitKeluar)
      .toList();

  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> refresh() async {
    if (_loading) return;

    final gen = _generation;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final list = await JobService.instance.fetchJobs();
      if (gen != _generation) return;

      _buses = list;
      _loaded = true;
    } on ApiException catch (e) {
      if (gen == _generation) _error = e.message;
    } catch (_) {
      if (gen == _generation) {
        _error = 'Terjadi kesalahan saat memuat data. Coba lagi.';
      }
    } finally {
      if (gen == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void addBus(BusWash bus) {
    _buses = [bus, ..._buses.where((b) => b.id != bus.id)];
    notifyListeners();
  }

  void clear() {
    _generation++;
    _buses = [];
    _loading = false;
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  void _onAuthChanged() {
    if (AuthService.instance.user == null) clear();
  }
}