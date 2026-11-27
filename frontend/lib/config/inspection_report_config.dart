/// Bagian armada yang diperiksa Pengawas. [other] menampung item lama yang
/// tidak termasuk daftar bagian pada laporan inspeksi.
enum InspectionSection {
  exterior('Eksterior'),
  interior('Interior'),
  other('Lainnya');

  final String label;

  const InspectionSection(this.label);
}

/// Teks tetap pada laporan inspeksi cuci bus.
class InspectionReportConfig {
  InspectionReportConfig._();

  static const title = 'LAPORAN HARIAN INSPEKSI CUCI BUS';
  static const logoAsset = 'assets/images/logo_mtrans.png';

  static const qcRole = 'PIC QC Cuci Bus';
  static const operationalRole = 'PIC Operasional Mtrans';
  static const scmRole = 'SCM MTrans';

  static const createdBy = 'Dibuat Oleh,';
  static const inspectedBy = 'Diperiksa Oleh,';
  static const knownBy = 'Mengetahui,';

  static const noteLabel = 'NB';
  static const noteText = 'Bukti foto before after dikirimkan di group whatsapp';

  /// Baris legenda status pada bagian 1. [colorIndex] dipakai pewarna badge.
  static const parameters = [
    (
      badge: 'DONE',
      condition: 'Kebersihan\n95% - 100%',
      parameter:
          'Seluruh bagian bersih sempurna, bebas noda/debu/bebas bau, '
          'Before/After sesuai standar.',
      action: 'Bus siap beroperasi',
    ),
    (
      badge: 'PERBAIKAN',
      condition: 'Kebersihan\n75% - 94%',
      parameter: 'Terdapat sisa water spot minor, debu, bercak noda',
      action: 'Pencucian/pembersihan ulang minor spontan (touch-up 5-10 menit).',
    ),
    (
      badge: 'GAGAL\n(REWASH)',
      condition: 'Kebersihan < 75% /\nBeralasan Sanitasi',
      parameter:
          'Kaca buram/berbayang, kotoran minyak/oleng di pelek, bau tidak '
          'sedap di toilet, lantai lengket.',
      action: 'Pencucian ulang total (Re-Wash) & penundaan rilis armada.',
    ),
  ];

  /// Bagian yang diperiksa pada tabel rincian per armada.
  static const exteriorParts = [
    'Kaca & body depan',
    'Lampu depan & belakang',
    'Body kanan, kiri & belakang',
    'Ban dan Velg',
  ];

  static const interiorParts = [
    'Area Dasbor & Kemudi',
    'Area Pantry',
    'Smoking Area',
    'Toilet',
    'Jok & Kursi Penumpang',
    'Lantai & Kolong Kursi',
  ];

  /// Label checklist dibandingkan tanpa peduli huruf besar/kecil dan spasi ganda.
  static String normalizeLabel(String label) =>
      label.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Bagian armada untuk satu label checklist Pengawas.
  static InspectionSection sectionOf(String label) {
    final key = normalizeLabel(label);
    if (exteriorParts.any((part) => normalizeLabel(part) == key)) {
      return InspectionSection.exterior;
    }
    if (interiorParts.any((part) => normalizeLabel(part) == key)) {
      return InspectionSection.interior;
    }
    return InspectionSection.other;
  }
}
