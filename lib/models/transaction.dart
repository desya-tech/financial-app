class TransactionItem {
  final String id;
  final DateTime timestamp;
  final DateTime date;
  final String category;
  final String subCategory;
  final double amount;
  final String description;

  TransactionItem({
    required this.id,
    required this.timestamp,
    required this.date,
    required this.category,
    required this.subCategory,
    required this.amount,
    required this.description,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      category: json['category'] ?? '',
      subCategory: json['subCategory'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'date': date.toIso8601String(),
    'category': category,
    'subCategory': subCategory,
    'amount': amount,
    'description': description,
  };
}
