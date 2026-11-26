import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/branch.dart';
import '../models/staff_account.dart';
import '../services/api_exception.dart';
import '../services/staff_service.dart';
import '../theme/app_theme.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Form akun Pengawas atau Petugas Cuci. [account] null = akun baru,
/// terisi = ubah akun. Mengembalikan akun hasil simpan, atau null bila ditutup.
Future<StaffAccount?> showStaffFormSheet(
  BuildContext context, {
  required List<Branch> branches,
  StaffAccount? account,
}) {
  return showModalBottomSheet<StaffAccount>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _StaffFormSheet(branches: branches, account: account),
  );
}

class _StaffFormSheet extends StatefulWidget {
  const _StaffFormSheet({required this.branches, this.account});

  final List<Branch> branches;
  final StaffAccount? account;

  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  final TextEditingController _password = TextEditingController();

  late UserRole _role;
  int? _branchId;
  late bool _active;
  bool _obscure = true;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.account != null;

  /// Pengawas Operational bekerja lintas cabang, jadi cabangnya boleh kosong.
  bool get _branchOptional => _role == UserRole.pengawasOperational;

  bool get _valid {
    final phone = _phone.text.trim();
    return _name.text.trim().length >= 2 &&
        (phone.isEmpty || phone.length >= 8) &&
        (_branchId != null || _branchOptional) &&
        (_isEdit ||
            (_emailPattern.hasMatch(_email.text.trim()) &&
                _password.text.length >= 8)) &&
        !_saving;
  }

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _name = TextEditingController(text: account?.fullName ?? '');
    _email = TextEditingController(text: account?.email ?? '');
    _phone = TextEditingController(text: account?.phone ?? '');
    _role = account?.role ?? UserRole.pegawai;
    _active = account?.isActive ?? true;
    // Cabang lama yang sudah tidak ada dianggap belum dipilih.
    final branchId = account?.branchId;
    _branchId = widget.branches.any((b) => b.id == branchId) ? branchId : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_valid) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final service = StaffService.instance;
      final saved = _isEdit
          ? await service.updateStaff(
              widget.account!.id,
              fullName: _name.text.trim(),
              phone: _phone.text.trim(),
              role: _role,
              branchId: _branchId,
              isActive: _active,
            )
          : await service.createStaff(
              fullName: _name.text.trim(),
              email: _email.text.trim().toLowerCase(),
              password: _password.text,
              phone: _phone.text.trim(),
              role: _role,
              branchId: _branchId,
            );

      if (!mounted) return;
      Navigator.pop<StaffAccount>(context, saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? 'Ubah Akun' : 'Akun Baru',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                onChanged: (_) => setState(() {}),
                decoration: filledInputDecoration('Nama Lengkap').copyWith(
                  hintText: 'Contoh: Budi Santoso',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                // Email adalah identitas login, tidak diubah dari sini.
                enabled: !_saving && !_isEdit,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                maxLength: 254,
                onChanged: (_) => setState(() {}),
                decoration: filledInputDecoration('Email').copyWith(
                  hintText: 'nama@email.com',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                maxLength: 20,
                onChanged: (_) => setState(() {}),
                decoration: filledInputDecoration('No. HP (opsional)').copyWith(
                  hintText: '08xxxxxxxxxx',
                  counterText: '',
                ),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  enabled: !_saving,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 72,
                  onChanged: (_) => setState(() {}),
                  decoration: filledInputDecoration('Password').copyWith(
                    hintText: 'Minimal 8 karakter',
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Peran', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  UserRole.pengawas,
                  UserRole.pengawasOperational,
                  UserRole.pegawai,
                ].map((role) {
                  return ChoiceChip(
                    avatar: Icon(
                      switch (role) {
                        UserRole.pengawas => Icons.manage_accounts_outlined,
                        UserRole.pengawasOperational => Icons.fact_check_outlined,
                        _ => Icons.cleaning_services_outlined,
                      },
                      size: 18,
                    ),
                    label: Text(role.label),
                    selected: _role == role,
                    onSelected: _saving ? null : (_) => setState(() => _role = role),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Cabang', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (_branchOptional)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Pengawas Operational memantau semua cabang. Pilih cabang hanya bila akun ini memang dikhususkan untuk satu cabang.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_branchOptional)
                    ChoiceChip(
                      avatar: const Icon(Icons.public, size: 18),
                      label: const Text('Semua cabang'),
                      selected: _branchId == null,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _branchId = null),
                    ),
                  ...widget.branches.map((branch) {
                    return ChoiceChip(
                      avatar: const Icon(Icons.location_on_outlined, size: 18),
                      label: Text(branch.name),
                      selected: _branchId == branch.id,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _branchId = branch.id),
                    );
                  }),
                ],
              ),
              if (_isEdit) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _active,
                  onChanged: _saving ? null : (v) => setState(() => _active = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Akun aktif'),
                  subtitle: const Text(
                    'Akun nonaktif tidak bisa login dan tidak muncul di daftar petugas.',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _valid ? _submit : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEdit ? 'Simpan Perubahan' : 'Buat Akun'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
