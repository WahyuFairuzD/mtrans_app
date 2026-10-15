/// Satu barang di daftar stok.
class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final int quantity;

  factory StockItem.fromJson(Map<String, dynamic> json) => StockItem(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    unit: json['unit'] as String,
    quantity: (json['quantity'] as num).toInt(),
  );
}
class StockMovement {
  const StockMovement({
    required this.id,
    required this.itemId,
    required this.item,
    required this.unit,
    required this.amount,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.person,
    required this.time,
    required this.message,
  });

  final int id;
  final String itemId;
  final String item;
  final String unit;
  final int amount;
  final int quantityBefore;
  final int quantityAfter;
  final String person;
  final DateTime time;
  final String message;

  bool get isAddition => amount > 0;

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
    id: (json['id'] as num).toInt(),
    itemId: json['item_id'] as String,
    item: json['item_name'] as String,
    unit: (json['unit'] as String?) ?? '',
    amount: (json['amount'] as num).toInt(),
    quantityBefore: (json['quantity_before'] as num).toInt(),
    quantityAfter: (json['quantity_after'] as num).toInt(),
    person: (json['created_by_name'] as String?) ?? 'Pengguna',
    time: _toWib(json['created_at'] as String),
    message: (json['message'] as String?) ?? '',
  );
}
typedef StockChange = ({StockItem item, StockMovement? movement});

DateTime _toWib(String iso) =>
    DateTime.parse(iso).toUtc().add(const Duration(hours: 7));