import 'package:flutter/material.dart';

import '../../models/bus_wash.dart';
import '../../services/app_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bus_card.dart';
import '../../widgets/history_button.dart';
import '../../widgets/stat_card.dart';
import 'input_bus_page.dart';

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(
    top: Radius.circular(20),
  ),
);

const _h = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.bold,
);

class PengawasDashboard extends StatefulWidget {
  const PengawasDashboard({super.key});

  @override
  State<PengawasDashboard> createState() =>
      _PengawasDashboardState();
}

class _PengawasDashboardState extends State<PengawasDashboard> {
  final AppData _appData = AppData.instance;

  @override
  void initState() {
    super.initState();

    _appData.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _appData.removeListener(_onDataChanged);

    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;

    setState(() {});
  }


  // DATA


  List<BusWash> _by(List<WashStatus> statuses) {
    return _appData.buses
        .where(
          (bus) => statuses.contains(bus.status),
        )
        .toList();
  }

  void _update(
    BusWash oldBus,
    BusWash newBus,
  ) {
    _appData.updateBus(
      oldBus,
      newBus,
    );
  }


  // INPUT BUS


  Future<void> _addBus() async {
    final result = await Navigator.push<BusWash>(
      context,
      MaterialPageRoute(
        builder: (_) => const InputBusPage(),
      ),
    );

    if (result == null || !mounted) return;

    _appData.addBus(result);
  }


  // PENUGASAN


  Future<void> _assign(BusWash bus) async {
    final result = await showModalBottomSheet<List<Employee>>(
      context: context,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => _AssignSheet(
        bus: bus,
        employees: _appData.employees,
      ),
    );

    if (result == null || !mounted) return;

    _update(
      bus,
      bus.copyWith(
        status: WashStatus.menungguDikerjakan,
        employees: result,
      ),
    );
  }


  // PEMERIKSAAN


  Future<void> _inspect(BusWash bus) async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: _sheetShape,
      builder: (_) => _InspectSheet(
        bus: bus,
      ),
    );

    if (note == null || !mounted) return;

    _update(
      bus,
      bus.copyWith(
        status: WashStatus.selesai,
        inspectionNote: note.isEmpty
            ? 'Tidak ada catatan.'
            : note,
        inspectionTime: nowText(),
      ),
    );
  }


  // BUS KELUAR


  Future<void> _exit(BusWash bus) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Catat bus keluar?',
        ),
        content: Text(
          '${bus.plateNumber} meninggalkan lokasi sekarang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              ctx,
              false,
            ),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              true,
            ),
            child: const Text('Ya, Catat'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    _update(
      bus,
      bus.copyWith(
        status: WashStatus.unitKeluar,
        exitTime: nowText(),
      ),
    );
  }


  // SECTION


  List<Widget> _section(
    String title,
    List<BusWash> items, [
    String? actionLabel,
    void Function(BusWash)? onAction,
  ]) {
    if (items.isEmpty) return [];

    return [
      const SizedBox(height: 24),

      Text(
        '$title (${items.length})',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 12),

      ...items.map(
        (bus) => Padding(
          padding: const EdgeInsets.only(
            bottom: 10,
          ),
          child: BusCard(
            bus: bus,
            actionLabel: actionLabel,
            onAction: onAction == null
                ? null
                : () => onAction(bus),
          ),
        ),
      ),
    ];
  }


  // BUILD


  @override
  Widget build(BuildContext context) {
    final toAssign = _by([
      WashStatus.terdaftar,
    ]);

    final running = _by([
      WashStatus.menungguDikerjakan,
      WashStatus.dalamPengerjaan,
    ]);

    final toInspect = _by([
      WashStatus.menungguPemeriksaan,
    ]);

    final toExit = _by([
      WashStatus.selesai,
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MTRANS',
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.person_outline,
            ),
          ),
        ],
      ),

      // ========================================================
      // INPUT BUS
      // ========================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBus,
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Input Bus Datang',
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          96,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Halo, Pengawas 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Kelola bus masuk, penugasan, dan pemeriksaan.',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // STATISTIK
            // ==================================================

            StatGrid(
              items: [
                StatCard(
                  number: '${toAssign.length}',
                  title: 'Perlu Ditugaskan',
                  icon: Icons.assignment_ind_outlined,
                  color: Colors.blueGrey,
                ),

                StatCard(
                  number: '${running.length}',
                  title: 'Berjalan',
                  icon: Icons.autorenew,
                  color: Colors.orange,
                ),

                StatCard(
                  number: '${toInspect.length}',
                  title: 'Perlu Diperiksa',
                  icon: Icons.fact_check_outlined,
                  color: Colors.purple,
                ),

                StatCard(
                  number: '${toExit.length}',
                  title: 'Siap Keluar',
                  icon: Icons.exit_to_app,
                  color: Colors.green,
                ),
              ],
            ),

            // ==================================================
            // PERLU DITUGASKAN
            // ==================================================

            ..._section(
              'Perlu Ditugaskan',
              toAssign,
              'Tugaskan Petugas',
              _assign,
            ),

            // ==================================================
            // SEDANG BERJALAN
            // ==================================================

            ..._section(
              'Sedang Berjalan',
              running,
            ),

            // ==================================================
            // PEMERIKSAAN
            // ==================================================

            ..._section(
              'Menunggu Pemeriksaan',
              toInspect,
              'Periksa Hasil',
              _inspect,
            ),

            // ==================================================
            // SIAP KELUAR
            // ==================================================

            ..._section(
              'Siap Keluar',
              toExit,
              'Catat Bus Keluar',
              _exit,
            ),

            const SizedBox(height: 24),

            const HistoryButton(),
          ],
        ),
      ),
    );
  }
}

// SHEET: PENUGASAN

class _AssignSheet extends StatefulWidget {
  final BusWash bus;
  final List<Employee> employees;

  const _AssignSheet({
    required this.bus,
    required this.employees,
  });

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  final Set<Employee> _selected = {};

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
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // TITLE
              // ==================================================

              Text(
                'Tugaskan ${widget.bus.plateNumber}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Pilih petugas / tim yang mengerjakan.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // DAFTAR PEGAWAI - SCROLLABLE
              // ==================================================

              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.employees.length,
                  itemBuilder: (context, index) {
                    final employee = widget.employees[index];

                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity:
                          ListTileControlAffinity.leading,
                      value: _selected.contains(employee),
                      title: Text(employee.name),
                      subtitle: Text(employee.role),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(employee);
                          } else {
                            _selected.remove(employee);
                          }
                        });
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // BUTTON
              // ==================================================

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () {
                          Navigator.pop(
                            context,
                            _selected.toList(),
                          );
                        },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    child: Text(
                      'Simpan Penugasan',
                    ),
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

// SHEET: PEMERIKSAAN

class _InspectSheet extends StatefulWidget {
  final BusWash bus;

  const _InspectSheet({
    required this.bus,
  });

  @override
  State<_InspectSheet> createState() => _InspectSheetState();
}

class _InspectSheetState extends State<_InspectSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pemeriksaan ${bus.plateNumber}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                bus.brand,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Checklist',
                style: _h,
              ),

              const SizedBox(height: 10),

              ChecklistList(
                items: bus.checklist,
              ),

              const SizedBox(height: 16),

              const Text(
                'Foto sesudah cuci',
                style: _h,
              ),

              const SizedBox(height: 10),

              WashPhoto(
                bus: bus,
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _note,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText:
                      'Catatan pemeriksaan (opsional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _note.text.trim(),
                  ),
                  child: const Text(
                    'Simpan Pemeriksaan',
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