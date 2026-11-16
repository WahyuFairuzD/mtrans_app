import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/branch.dart';
import '../../models/staff_account.dart';
import '../../services/api_exception.dart';
import '../../services/master_service.dart';
import '../../services/staff_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/dialogs.dart';
import '../../widgets/error_state.dart';
import '../../widgets/staff_form_sheet.dart';

/// Kelola Akun (Owner): tambah dan ubah akun Pengawas serta Petugas Cuci.
class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  List<StaffAccount> _accounts = [];
  List<Branch> _branches = [];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final gen = ++_generation;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        StaffService.instance.fetchStaff(query: _search.text),
        if (_branches.isEmpty) MasterService.instance.fetchBranches(),
      ]);
      if (!mounted || gen != _generation) return;
      setState(() {
        _accounts = results[0] as List<StaffAccount>;
        if (results.length > 1) _branches = results[1] as List<Branch>;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && gen == _generation) {
        setState(() => _error = 'Gagal memuat akun. Coba lagi.');
      }
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _openForm([StaffAccount? account]) async {
    if (_branches.isEmpty) {
      showSnack(context, 'Data cabang belum termuat. Tarik untuk memuat ulang.');
      return;
    }
    final saved = await showStaffFormSheet(
      context,
      branches: _branches,
      account: account,
    );
    if (saved == null || !mounted) return;

    showSnack(
      context,
      account == null ? 'Akun berhasil dibuat.' : 'Akun berhasil diperbarui.',
    );
    await _load(silent: true);
  }

  String _branchName(int? id) {
    for (final branch in _branches) {
      if (branch.id == id) return branch.name;
    }
    return 'Tanpa cabang';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Akun')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Akun Baru'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: filledInputDecoration('Cari nama, email, atau no. HP')
                  .copyWith(
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _accounts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(40),
              children: [
                Text(
                  _search.text.trim().isEmpty
                      ? 'Belum ada akun. Tekan "Akun Baru" untuk menambah.'
                      : 'Akun tidak ditemukan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              itemCount: _accounts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _StaffTile(
                account: _accounts[i],
                branchName: _branchName(_accounts[i].branchId),
                onTap: () => _openForm(_accounts[i]),
              ),
            ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.account,
    required this.branchName,
    required this.onTap,
  });

  final StaffAccount account;
  final String branchName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactive = !account.isActive;
    final isPengawas = account.role == UserRole.pengawas;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEAF2FF),
                child: Icon(
                  isPengawas
                      ? Icons.manage_accounts_outlined
                      : Icons.cleaning_services_outlined,
                  color: inactive ? Colors.grey : AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: inactive ? AppColors.textSecondary : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${account.role.label} · $branchName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (account.email.isNotEmpty)
                      Text(
                        account.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (inactive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Nonaktif',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
