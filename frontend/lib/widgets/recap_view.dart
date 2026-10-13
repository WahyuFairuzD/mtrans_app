import 'package:flutter/material.dart';
import '../models/history_filter.dart';
import '../models/recap.dart';
import '../services/api_exception.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import 'stat_card.dart';

String formatMinutes(double? minutes) {
  if (minutes == null) return '-';

  final total = minutes.round();
  final h = total ~/ 60;
  final m = total % 60;

  return h > 0 ? '$h j $m m' : '$m m';
}

/// Rekap operasional untuk filter yang sedang dipilih.
class RecapView extends StatefulWidget {
  final HistoryFilter filter;

  const RecapView({super.key, required this.filter});

  @override
  State<RecapView> createState() => _RecapViewState();
}

class _RecapViewState extends State<RecapView>
    with AutomaticKeepAliveClientMixin {
  Recap? _recap;
  bool _loading = true;
  String? _error;

  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RecapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.signature != widget.filter.signature) {
      _load();
    }
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
      final recap = await HistoryService.instance.fetchRecap(widget.filter);
      if (!mounted || gen != _generation) return;

      setState(() {
        _recap = recap;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && gen == _generation) {
        setState(() => _error = 'Gagal memuat rekap. Coba lagi.');
      }
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final recap = _recap;

    if (_error != null || recap == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _error ?? 'Gagal memuat rekap.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          StatGrid(
            items: [
              StatCard(
                number: '${recap.total}',
                title: 'Total Pekerjaan',
                icon: Icons.directions_bus,
                color: Colors.blue,
              ),
              StatCard(
                number: formatMinutes(recap.avgWashMinutes),
                title: 'Rata-rata Durasi Cuci',
                icon: Icons.timer_outlined,
                color: Colors.orange,
              ),
            ],
          ),
          if (recap.total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Belum ada data pada filter ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else ...[
            _Section(title: 'Per Lokasi', rows: recap.byLocation),
            _Section(
              title: 'Per Petugas',
              rows: recap.byPegawai,
              caption:
                  'Pekerjaan dengan lebih dari 1 petugas dihitung untuk tiap petugas.',
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<RecapRow> rows;
  final String? caption;

  const _Section({required this.title, required this.rows, this.caption});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text(
            'Belum ada data.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          ...rows.map(
            (row) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${row.total} pekerjaan',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}