import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'transaction_form_screen.dart';
import 'settings_screen.dart';
import 'budget_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FinanceProvider>(context, listen: false);
      if (provider.webAppUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan atur Google Apps Script URL di Pengaturan.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Financial Freedom', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Pantau keuangan Anda', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF8899BB) : const Color(0xFF6677AA), fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 22),
            tooltip: 'Kelola Budget',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => Provider.of<FinanceProvider>(context, listen: false).fetchData(),
          ),
        ],
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Memuat data...', style: TextStyle(color: Color(0xFF8899BB))),
                ],
              ),
            );
          }

          if (provider.errorMessage.isNotEmpty) {
            return _buildErrorState(provider);
          }

          if (provider.budgets.isEmpty && provider.transactions.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchData(),
            child: CustomScrollView(
              slivers: [
                // Offline banner
                if (!provider.isOnline || provider.pendingSyncCount > 0)
                  SliverToBoxAdapter(
                    child: _buildOfflineBanner(provider),
                  ),
                SliverToBoxAdapter(
                  child: _buildHeader(context, provider),
                ),
                SliverToBoxAdapter(
                  child: _buildBudgetSection(context, provider),
                ),
                SliverToBoxAdapter(
                  child: _buildTransactionsSection(context, provider),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionFormScreen())),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildOfflineBanner(FinanceProvider provider) {
    final isOnline = provider.isOnline;
    final pending = provider.pendingSyncCount;
    final isSyncing = provider.isSyncing;

    Color bgColor;
    IconData icon;
    String message;

    if (!isOnline) {
      bgColor = const Color(0xFFFF6B35);
      icon = Icons.cloud_off_rounded;
      message = pending > 0
          ? 'Mode Offline • $pending transaksi menunggu sync'
          : 'Mode Offline • Data baru tersimpan di HP';
    } else if (isSyncing) {
      bgColor = const Color(0xFF5B8DEF);
      icon = Icons.sync_rounded;
      message = 'Menyinkronkan $pending transaksi ke Google Sheets...';
    } else {
      bgColor = AppTheme.accentGold;
      icon = Icons.cloud_upload_rounded;
      message = '$pending transaksi belum tersinkron. Tap untuk sync.';
    }

    return GestureDetector(
      onTap: (!isOnline || isSyncing) ? null : () => provider.syncQueue(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            isSyncing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            if (isOnline && !isSyncing && pending > 0)
              const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(FinanceProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 40),
            ),
            const SizedBox(height: 20),
            Text(provider.errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8899BB), fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.fetchData(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_rounded, color: AppTheme.primaryGreen, size: 50),
            ),
            const SizedBox(height: 24),
            const Text('Belum ada data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Atur URL Google Apps Script di Pengaturan untuk mulai memuat data.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8899BB), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FinanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthlySpent = provider.getTotalSpending(monthStart, now);

    // total monthly budget
    double totalBudget = provider.budgets.fold(0.0, (sum, b) => sum + b.budgetAmount);
    double remaining = totalBudget - monthlySpent;
    double pct = totalBudget > 0 ? (monthlySpent / totalBudget).clamp(0.0, 1.0) : 0.0;

    final Color barColor = pct > 0.9 ? AppTheme.danger : pct > 0.7 ? AppTheme.accentGold : AppTheme.primaryGreen;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 80, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0D2D28), const Color(0xFF0A1F3C)]
                : [const Color(0xFF00B894), const Color(0xFF0984E3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (isDark ? AppTheme.primaryGreen : const Color(0xFF00B894)).withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Colors.white60, size: 14),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(now),
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Total Pengeluaran Bulan Ini', style: TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              currencyFormatter.format(monthlySpent),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            const SizedBox(height: 20),
            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sisa Budget', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    Text(currencyFormatter.format(remaining),
                        style: TextStyle(
                          color: remaining < 0 ? AppTheme.danger : Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${(pct * 100).toStringAsFixed(0)}% dari ${currencyFormatter.format(totalBudget)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 16),
            // Mini stats row
            Row(
              children: [
                _miniStat('Mingguan', provider.getTotalSpending(now.subtract(Duration(days: now.weekday - 1)), now)),
                const SizedBox(width: 12),
                _miniStat('Tahunan', provider.getTotalSpending(DateTime(now.year, 1, 1), now)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, double amount) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              currencyFormatter.format(amount),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSection(BuildContext context, FinanceProvider provider) {
    if (provider.budgets.isEmpty) return const SizedBox.shrink();

    Map<String, double> categoryBudgets = {};
    for (var b in provider.budgets) {
      categoryBudgets[b.category] = (categoryBudgets[b.category] ?? 0) + b.budgetAmount;
    }
    final categorySpending = provider.getCategorySpending();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Budget per Kategori', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetScreen())),
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text('Kelola', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...categoryBudgets.entries.map((entry) {
            final cat = entry.key;
            final totalBudget = entry.value;
            final spent = categorySpending[cat] ?? 0.0;
            final remaining = totalBudget - spent;
            final pct = totalBudget > 0 ? (spent / totalBudget).clamp(0.0, 1.0) : 0.0;

            Color barColor = AppTheme.primaryGreen;
            if (pct > 0.9) barColor = AppTheme.danger;
            else if (pct > 0.7) barColor = AppTheme.accentGold;

            return GestureDetector(
              onTap: () => _showSubCategoryDetails(context, provider, cat, totalBudget, spent),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkCardBorder
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(color: barColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(cat, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ],
                        ),
                        Text(
                          remaining < 0
                              ? '-${currencyFormatter.format(remaining.abs())}'
                              : currencyFormatter.format(remaining),
                          style: TextStyle(
                            color: remaining < 0 ? AppTheme.danger : AppTheme.primaryGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkCardBorder
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${currencyFormatter.format(spent)} dari ${currencyFormatter.format(totalBudget)}',
                          style: const TextStyle(color: Color(0xFF8899BB), fontSize: 11),
                        ),
                        const Text(
                          'Ketuk untuk detail sub-kategori',
                          style: TextStyle(color: Color(0xFF8899BB), fontSize: 9, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTransactionsSection(BuildContext context, FinanceProvider provider) {
    final recent = provider.transactions.take(10).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transaksi Terakhir', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...recent.map((t) {
            final catColor = _catColor(t.category);
            final catIcon = _catIcon(t.category);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkCardBorder
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(catIcon, color: catColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.description.isNotEmpty ? t.description : t.subCategory,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${t.subCategory} • ${DateFormat('dd MMM yyyy').format(t.date)}',
                          style: const TextStyle(color: Color(0xFF8899BB), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '-${currencyFormatter.format(t.amount)}',
                    style: TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Color _catColor(String category) {
    switch (category.toLowerCase()) {
      case 'kebutuhan': return AppTheme.primaryGreen;
      case 'kewajiban': return const Color(0xFF5B8DEF);
      case 'cicilan': return AppTheme.accentGold;
      case 'langganan': return const Color(0xFFB86EF5);
      case 'persembahan': return const Color(0xFFFF7F7F);
      default: return const Color(0xFF8899BB);
    }
  }

  IconData _catIcon(String category) {
    switch (category.toLowerCase()) {
      case 'kebutuhan': return Icons.shopping_bag_rounded;
      case 'kewajiban': return Icons.family_restroom_rounded;
      case 'cicilan': return Icons.home_rounded;
      case 'langganan': return Icons.subscriptions_rounded;
      case 'persembahan': return Icons.volunteer_activism_rounded;
      default: return Icons.receipt_long_rounded;
    }
  }

  void _showSubCategoryDetails(BuildContext context, FinanceProvider provider, String category, double totalBudget, double totalSpent) {
    final subSpendings = provider.getSubCategorySpending(category);
    final subBudgets = provider.budgets.where((b) => b.category == category).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B2A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.only(top: 12),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _catColor(category).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_catIcon(category), color: _catColor(category), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                              Text(
                                '${currencyFormatter.format(totalSpent)} / ${currencyFormatter.format(totalBudget)}',
                                style: const TextStyle(color: Color(0xFF8899BB), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, thickness: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: subBudgets.length,
                      itemBuilder: (context, index) {
                        final b = subBudgets[index];
                        final spent = subSpendings[b.subCategory] ?? 0.0;
                        final remaining = b.budgetAmount - spent;
                        final pct = b.budgetAmount > 0 ? (spent / b.budgetAmount).clamp(0.0, 1.0) : 0.0;
                        
                        Color barColor = AppTheme.primaryGreen;
                        if (pct > 0.9) barColor = AppTheme.danger;
                        else if (pct > 0.7) barColor = AppTheme.accentGold;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(b.subCategory, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  Text(
                                    remaining < 0 
                                      ? '-${currencyFormatter.format(remaining.abs())}'
                                      : currencyFormatter.format(remaining),
                                    style: TextStyle(
                                      color: remaining < 0 ? AppTheme.danger : AppTheme.primaryGreen,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: isDark ? AppTheme.darkCardBorder : Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${currencyFormatter.format(spent)} dari ${currencyFormatter.format(b.budgetAmount)}',
                                style: const TextStyle(color: Color(0xFF8899BB), fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
