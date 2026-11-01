class Branch {
  const Branch({required this.id, required this.name});

  final int id;
  final String name;

  factory Branch.fromJson(Map<String, dynamic> json) =>
      Branch(id: (json['id'] as num).toInt(), name: json['name'] as String);
}
