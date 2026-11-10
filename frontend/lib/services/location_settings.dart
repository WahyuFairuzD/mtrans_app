import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/branch.dart';
import 'auth_service.dart';
import 'master_service.dart';

class LocationSettings extends ChangeNotifier {
  LocationSettings._() {
    AuthService.instance.addListener(_onAuthChanged);
  }

  static final LocationSettings instance = LocationSettings._();

  static const _prefKey = 'owner_location';
  static const _allValue = 'all';
  static const _defaultBranchName = 'Arjosari';

  List<Branch> _branches = [];
  int? _branchId;
  Future<void>? _loading;

  List<Branch> get branches => List.unmodifiable(_branches);

  int? get branchId => _branchId;
  bool get isAll => _branchId == null;
  bool get loaded => _branches.isNotEmpty;

  String get label {
    for (final branch in _branches) {
      if (branch.id == _branchId) return branch.name;
    }
    return 'Semua Lokasi';
  }

  Future<void> ensureLoaded() {
    return _loading ??= _load().catchError((Object error) {
      _loading = null;
      throw error;
    });
  }

  Future<void> _load() async {
    final branches = await MasterService.instance.fetchBranches();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);

    int? resolved;
    var needsSave = false;

    if (saved == _allValue) {
      resolved = null;
    } else if (saved != null &&
        branches.any((b) => b.id == int.tryParse(saved))) {
      resolved = int.parse(saved);
    } else {
      for (final branch in branches) {
        if (branch.name.toLowerCase() == _defaultBranchName.toLowerCase()) {
          resolved = branch.id;
        }
      }
      needsSave = true;
    }

    _branches = branches;
    _branchId = resolved;
    if (needsSave) {
      await prefs.setString(_prefKey, resolved?.toString() ?? _allValue);
    }
    notifyListeners();
  }

  Future<void> select(int? branchId) async {
    if (branchId == _branchId) return;
    _branchId = branchId;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, branchId?.toString() ?? _allValue);
  }

  void _onAuthChanged() {
    if (AuthService.instance.user == null && (_loading != null || loaded)) {
      _loading = null;
      _branches = [];
      _branchId = null;
      notifyListeners();
    }
  }
}
