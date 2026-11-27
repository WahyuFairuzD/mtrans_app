import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtrans_wash/config/inspection_report_config.dart';
import 'package:mtrans_wash/models/work.dart';
import 'package:mtrans_wash/utils/checklist_grouping.dart';
import 'package:mtrans_wash/widgets/checklist_group_list.dart';

ChecklistItem item(String label, int order, {bool done = false}) =>
    ChecklistItem(
      id: 'id-$order',
      label: label,
      isRequired: true,
      isDone: done,
      sortOrder: order,
    );

/// Checklist baru sesuai laporan inspeksi: 4 eksterior + 6 interior.
final partsChecklist = [
  item('Kaca & body depan', 1, done: true),
  item('Lampu depan & belakang', 2),
  item('Body kanan, kiri & belakang', 3),
  item('Ban dan Velg', 4),
  item('Area Dasbor & Kemudi', 5, done: true),
  item('Area Pantry', 6),
  item('Smoking Area', 7),
  item('Toilet', 8),
  item('Jok & Kursi Penumpang', 9),
  item('Lantai & Kolong Kursi', 10),
];

/// Checklist lama (5 item generik) yang sudah terlanjur dipakai.
final legacyChecklist = [
  item('Body luar dibilas dan disabun', 1, done: true),
  item('Kaca dan spion bersih', 2, done: true),
  item('Velg dan ban bersih', 3, done: true),
  item('Lantai dan kursi dibersihkan', 4, done: true),
  item('Sampah di dalam bus dibuang', 5, done: true),
];

void main() {
  group('sectionOf', () {
    test('bagian eksterior dan interior dikenali', () {
      for (final part in InspectionReportConfig.exteriorParts) {
        expect(
          InspectionReportConfig.sectionOf(part),
          InspectionSection.exterior,
          reason: part,
        );
      }
      for (final part in InspectionReportConfig.interiorParts) {
        expect(
          InspectionReportConfig.sectionOf(part),
          InspectionSection.interior,
          reason: part,
        );
      }
    });

    test('spasi ganda dan huruf besar tidak mengubah bagian', () {
      expect(
        InspectionReportConfig.sectionOf('  KACA  &  body Depan '),
        InspectionSection.exterior,
      );
    });

    test('label lama tidak masuk eksterior/interior', () {
      expect(
        InspectionReportConfig.sectionOf('Body luar dibilas dan disabun'),
        InspectionSection.other,
      );
    });
  });

  group('groupChecklist', () {
    test('eksterior lebih dulu, item lain di akhir', () {
      final groups = groupChecklist([
        ...legacyChecklist.take(1),
        ...partsChecklist,
      ]);

      expect(groups.keys.toList(), [
        InspectionSection.exterior,
        InspectionSection.interior,
        InspectionSection.other,
      ]);
      expect(groups[InspectionSection.exterior]!.length, 4);
      expect(groups[InspectionSection.interior]!.length, 6);
      expect(groups[InspectionSection.other]!.single.label,
          'Body luar dibilas dan disabun');
    });

    test('checklist lama seluruhnya di bagian lainnya', () {
      final groups = groupChecklist(legacyChecklist);
      expect(groups.keys.toList(), [InspectionSection.other]);
    });
  });

  testWidgets('judul bagian tampil dan item lama tanpa judul', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChecklistGroupList(
              items: [...partsChecklist, ...legacyChecklist],
              onToggle: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('EKSTERIOR'), findsOneWidget);
    expect(find.text('INTERIOR'), findsOneWidget);
    expect(find.text('LAINNYA'), findsNothing);
    expect(find.text('Body luar dibilas dan disabun'), findsOneWidget);

    // Penghitung per bagian: 1 dari 4 eksterior, 1 dari 6 interior.
    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('1/6'), findsOneWidget);
  });

  testWidgets('mencentang item mengirim nilai baru', (tester) async {
    ChecklistItem? toggled;
    bool? value;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChecklistGroupList(
              items: partsChecklist,
              onToggle: (item, v) {
                toggled = item;
                value = v;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Toilet'));
    await tester.pump();

    expect(toggled?.label, 'Toilet');
    expect(value, isTrue);
  });

  testWidgets('hanya baca tidak menampilkan checkbox', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChecklistGroupList(items: partsChecklist, card: false),
          ),
        ),
      ),
    );

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.text('EKSTERIOR'), findsOneWidget);
  });
}
