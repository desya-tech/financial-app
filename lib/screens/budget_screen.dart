import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/category_budget.dart';
import '../theme/app_theme.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  void _showBudgetDialog({CategoryBudget? budget}) {
    final isEditing = budget != null;
    final categoryController = TextEditingController(text: isEditing ? budget.category : '');
    final subCategoryController = TextEditingController(text: isEditing ? budget.subCategory : '');
    final amountController = TextEditingController(text: isEditing ? budget.budgetAmount.toStringAsFixed(0) : '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_rounded : Icons.add_rounded,
                      color: AppTheme.primaryGreen, size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Edit Kategori' : 'Tambah Kategori',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Kategori Utama'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subCategoryController,
                decoration: InputDecoration(
                  labelText: 'Sub-Kategori',
                  enabled: !isEditing,
                  helperText: isEditing ? 'Nama Sub-Kategori tidak bisa diubah' : null,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Nominal Budget (Rp)',
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text) ?? 0;
                        if (categoryController.text.isEmpty || subCategoryController.text.isEmpty) return;

                        final provider = Provider.of<FinanceProvider>(context, listen: false);
                        final newBudget = CategoryBudget(
                          category: categoryController.text,
                          subCategory: subCategoryController.text,
                          budgetAmount: amount,
                        );

                        Navigator.pop(ctx);

                        bool success;
                        if (isEditing) {
                          success = await provider.updateBudget(newBudget);
                        } else {
                          success = await provider.addBudget(newBudget);
                        }

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: success ? AppTheme.primaryGreen : AppTheme.danger,
                            content: Text(
                              success ? 'Berhasil disimpan' : 'Gagal menyimpan',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        );
                      },
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteBudget(CategoryBudget budget) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus Kategori?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Kategori "${budget.subCategory}" akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final provider = Provider.of<FinanceProvider>(context, listen: false);
      final success = await provider.deleteBudget(budget.subCategory);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? AppTheme.primaryGreen : AppTheme.danger,
          content: Text(
            success ? 'Berhasil dihapus' : 'Gagal menghapus',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Budget'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 3));
          }

          if (provider.budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryGreen, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text('Belum ada kategori budget', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Tekan tombol + untuk membuat kategori baru', style: TextStyle(color: Color(0xFF8899BB), fontSize: 13)),
                ],
              ),
            );
          }

          // Group by category
          Map<String, List<CategoryBudget>> grouped = {};
          for (var b in provider.budgets) {
            grouped.putIfAbsent(b.category, () => []).add(b);
          }

          // Total per main category
          final categorySpending = provider.getCategorySpending();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final mainCategory = grouped.keys.elementAt(index);
              final items = grouped[mainCategory]!;
              final totalBudget = items.fold(0.0, (s, b) => s + b.budgetAmount);
              final spent = categorySpending[mainCategory] ?? 0.0;
              final pct = totalBudget > 0 ? (spent / totalBudget).clamp(0.0, 1.0) : 0.0;
              final Color headerColor = pct > 0.9 ? AppTheme.danger : pct > 0.7 ? AppTheme.accentGold : AppTheme.primaryGreen;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Category header
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: headerColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        mainCategory.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: headerColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        currencyFormatter.format(totalBudget),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8899BB)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Sub-category items
                  ...items.map((b) {
                    final subSpent = provider.getSubCategorySpending(mainCategory)[b.subCategory] ?? 0.0;
                    final subPct = b.budgetAmount > 0 ? (subSpent / b.budgetAmount).clamp(0.0, 1.0) : 0.0;
                    final subColor = subPct > 0.9 ? AppTheme.danger : subPct > 0.7 ? AppTheme.accentGold : AppTheme.primaryGreen;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? AppTheme.darkCardBorder : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.subCategory, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${currencyFormatter.format(subSpent)} / ${currencyFormatter.format(b.budgetAmount)}',
                                      style: const TextStyle(color: Color(0xFF8899BB), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, size: 18),
                                    color: const Color(0xFF5B8DEF),
                                    onPressed: () => _showBudgetDialog(budget: b),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_rounded, size: 18),
                                    color: AppTheme.danger,
                                    onPressed: () => _deleteBudget(b),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: subPct,
                              minHeight: 4,
                              backgroundColor: isDark ? AppTheme.darkCardBorder : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(subColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBudgetDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kategori Baru', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
