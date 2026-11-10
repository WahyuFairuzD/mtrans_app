class RecapRow {
  final String id;
  final String name;
  final int total;

  const RecapRow({required this.id, required this.name, required this.total});

  factory RecapRow.fromJson(Map<String, dynamic> j) {
    return RecapRow(
      // ID cabang berupa angka, ID petugas berupa UUID: samakan jadi teks.
      id: (j['id'] ?? '').toString(),
      name: (j['name'] as String?) ?? '-',
      total: (j['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class Recap {
  final int total;
  final double? avgWashMinutes;
  final List<RecapRow> byBranch;
  final List<RecapRow> byPegawai;

  const Recap({
    required this.total,
    required this.avgWashMinutes,
    required this.byBranch,
    required this.byPegawai,
  });

  factory Recap.fromJson(Map<String, dynamic> j) {
    List<RecapRow> rows(dynamic raw) {
      if (raw is! List) return const [];
      return raw.cast<Map<String, dynamic>>().map(RecapRow.fromJson).toList();
    }

    return Recap(
      total: (j['total'] as num?)?.toInt() ?? 0,
      avgWashMinutes: (j['avg_wash_minutes'] as num?)?.toDouble(),
      byBranch: rows(j['by_branch']),
      byPegawai: rows(j['by_pegawai']),
    );
  }
}
