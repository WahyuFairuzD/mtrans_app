class PegawaiItem {
  final String id;
  final String fullName;

  const PegawaiItem({required this.id, required this.fullName});

  factory PegawaiItem.fromJson(Map<String, dynamic> j) {
    return PegawaiItem(
      id: j['id'] as String,
      fullName: (j['full_name'] as String?) ?? '-',
    );
  }
}

class JobAssignment {
  final List<String> pegawaiIds;
  final String instructions;

  const JobAssignment({
    required this.pegawaiIds,
    required this.instructions,
  });
}