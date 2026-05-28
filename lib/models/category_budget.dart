class CategoryBudget {
  final String category;
  final String subCategory;
  final double budgetAmount;

  CategoryBudget({
    required this.category,
    required this.subCategory,
    required this.budgetAmount,
  });

  factory CategoryBudget.fromJson(Map<String, dynamic> json) {
    return CategoryBudget(
      category: json['category'] ?? '',
      subCategory: json['subCategory'] ?? '',
      budgetAmount: double.tryParse(json['budgetAmount']?.toString() ?? '0') ?? 0,
    );
  }
}
