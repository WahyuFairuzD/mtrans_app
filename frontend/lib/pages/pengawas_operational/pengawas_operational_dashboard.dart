import 'package:flutter/material.dart';

import '../../models/operational_report.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/dialogs.dart';
import '../../widgets/dashboard_scaffold.dart';
import '../../widgets/entry_card.dart';
import '../../widgets/load_notice.dart';
import '../../widgets/stat_card.dart';
import 'operational_report_page.dart';
import 'report_signer_page.dart';

/// Beranda Pengawas Operational: hanya konfirmasi kondisi after dan export PDF.
class PengawasOperationalDashboard extends StatefulWidget {
  const PengawasOperationalDashboard({super.key});

  @override
  State<PengawasOperationalDashboard> createState() =>
      _PengawasOperationalDashboardState();
}

class _PengawasOperationalDashboardState
    extends State<PengawasOperationalDashboard> {
  List<ReportableBus> _buses = [];
  bool _loading = true;
  bool _loaded = false;
  String? _error;

  String get _firstName {
    final fullName = AuthService.instance.user?.fullName.trim() ?? '';
    if (fullName.isEmpty) return 'Pengawas Operational';
    return fullName.split(RegExp(r'\s+')).first;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    try {
      final buses = await ReportService.instance.fetchBuses();
      if (!mounted) return;
      setState(() {
        _buses = buses;
        _error = null;
        _loaded = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (silent) {
        showSnack(context, e.message);
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (!mounted) return;
      if (silent) {
        showSnack(context, 'Gagal memuat data. Coba lagi.');
      } else {
        setState(() => _error = 'Gagal memuat data. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openReport(ReportableBus bus) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OperationalReportPage(bus: bus)),
    );
    if (saved == true && mounted) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _buses.where((b) => !b.hasReport).toList();
    final done = _buses.where((b) => b.hasReport).toList();

    return DashboardScaffold(
      greeting: 'Halo, $_firstName',
      subtitle: 'Konfirmasi kondisi after dan buat laporan inspeksi.',
      onRefresh: () => _load(silent: true),
      bottomPadding: 40,
      children: [
        StatGrid(
          items: [
            StatCard(
              number: '${pending.length}',
              title: 'Belum Dilaporkan',
              icon: Icons.pending_actions,
              color: Colors.orange,
            ),
            StatCard(
              number: '${done.length}',
              title: 'Laporan Selesai',
              icon: Icons.task_alt,
              color: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 14),
        EntryCard(
          title: 'Nama & Tanda Tangan',
          subtitle: 'Atur penanda tangan yang tercetak di laporan',
          icon: Icons.draw_outlined,
          onTap: () => _open(const ReportSignerPage()),
        ),
        LoadNotice(
          loading: _loading,
          loaded: _loaded,
          error: _error,
          onRetry: _load,
        ),
        if (_loaded && _buses.isEmpty) ...[
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Belum ada bus yang diperiksa Pengawas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
        ..._section('Menunggu Konfirmasi After', pending),
        ..._section('Sudah Dilaporkan', done),
      ],
    );
  }

  List<Widget> _section(String title, List<ReportableBus> items) {
    if (items.isEmpty) return [];

    return [
      const SizedBox(height: 24),
      Text(
        '$title (${items.length})',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      ...items.map(
        (bus) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ReportBusCard(bus: bus, onTap: () => _openReport(bus)),
        ),
      ),
    ];
  }
}

class _ReportBusCard extends StatelessWidget {
  const _ReportBusCard({required this.bus, required this.onTap});

  final ReportableBus bus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reported = bus.hasReport;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bus.plateNumber,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (reported ? Colors.green : Colors.orange)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      reported ? 'Sudah Dilaporkan' : 'Perlu Konfirmasi',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: reported ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  bus.brandLabel,
                  bus.dateLabel,
                  if (bus.branchName != null) bus.branchName!,
                ].join(' • '),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Pengawas: ${bus.inspectionLabel}'
                      '${bus.inspectorName == null ? '' : ' • ${bus.inspectorName}'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (reported) ...[
                const SizedBox(height: 4),
                Text(
                  'Ket. final: ${bus.reportFinalStatus}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTap,
                  child: Text(reported ? 'Buka Laporan' : 'Konfirmasi After'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
