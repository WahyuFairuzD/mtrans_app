import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/vehicle_type.dart';
import '../../services/api_exception.dart';
import '../../services/price_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/dialogs.dart';
import '../../utils/invoice_format.dart';
import '../../widgets/error_state.dart';

const _maxPrice = 10000000;

/// Setting > Harga: harga cuci per jenis kendaraan (khusus Owner).
class PriceSettingsPage extends StatefulWidget {
  const PriceSettingsPage({super.key});

  @override
  State<PriceSettingsPage> createState() => _PriceSettingsPageState();
}

class _PriceSettingsPageState extends State<PriceSettingsPage> {
  final Map<VehicleType, TextEditingController> _controllers = {
    for (final type in VehicleType.values) type: TextEditingController(),
  };

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final prices = await PriceService.instance.fetchPrices();
      if (!mounted) return;
      for (final type in VehicleType.values) {
        _controllers[type]!.text = '${prices[type]}';
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Gagal memuat harga. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// null bila ada isian yang kosong atau di luar batas.
  PriceList? _parse() {
    final prices = <VehicleType, int>{};
    for (final type in VehicleType.values) {
      final value = int.tryParse(_controllers[type]!.text.trim());
      if (value == null || value < 0 || value > _maxPrice) return null;
      prices[type] = value;
    }
    return prices;
  }

  Future<void> _save() async {
    final prices = _parse();
    if (prices == null) {
      showSnack(context, 'Isi semua harga dengan angka 0 sampai 10.000.000.');
      return;
    }

    setState(() => _saving = true);
    try {
      await PriceService.instance.savePrices(prices);
      if (!mounted) return;
      showSnack(context, 'Harga disimpan.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (_) {
      if (mounted) showSnack(context, 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Harga')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Harga')),
        body: ErrorState(message: _loadError!, onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Harga')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Harga cuci per kendaraan. Berlaku sama untuk semua cabang dan layanan.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final type in VehicleType.values) ...[
            TextField(
              controller: _controllers[type],
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: filledInputDecoration(type.label).copyWith(
                prefixIcon: Icon(type.icon),
                prefixText: 'Rp ',
                helperText: _helper(_controllers[type]!.text),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.brand),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Harga baru hanya berlaku untuk invoice yang dibuat setelah ini. Invoice yang sudah dibuat tidak berubah.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
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
                    : const Text('Simpan Harga'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _helper(String raw) {
    final value = int.tryParse(raw.trim());
    return value == null ? null : formatRupiah(value);
  }
}
