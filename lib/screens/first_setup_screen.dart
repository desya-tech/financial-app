import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class FirstSetupScreen extends StatefulWidget {
  const FirstSetupScreen({super.key});

  @override
  State<FirstSetupScreen> createState() => _FirstSetupScreenState();
}

class _FirstSetupScreenState extends State<FirstSetupScreen> {
  final _scriptUrlController = TextEditingController();
  final _spreadsheetUrlController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  bool _isSaving = false;
  bool _obscureKey = true;

  @override
  void dispose() {
    _scriptUrlController.dispose();
    _spreadsheetUrlController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final scriptUrl = _scriptUrlController.text.trim();
    if (scriptUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Apps Script URL wajib diisi!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    await provider.saveSettings(
      scriptUrl,
      _geminiKeyController.text.trim(),
      _spreadsheetUrlController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Header
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryGreen, Color(0xFF0984E3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.35),
                      blurRadius: 20, offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 36),
              ),

              const SizedBox(height: 24),
              const Text(
                'Pengaturan Awal',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Isi data berikut untuk mulai menggunakan aplikasi.',
                style: TextStyle(
                  fontSize: 15, height: 1.5,
                  color: isDark ? const Color(0xFF8899BB) : Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 36),

              // Apps Script URL
              _fieldCard(
                isDark: isDark,
                icon: Icons.code_rounded,
                iconColor: const Color(0xFF5B8DEF),
                title: 'Google Apps Script URL',
                subtitle: 'Deploy skrip sebagai Web App (Anyone) dan tempel URL-nya.',
                child: TextField(
                  controller: _scriptUrlController,
                  decoration: const InputDecoration(
                    hintText: 'https://script.google.com/macros/s/.../exec',
                    hintStyle: TextStyle(fontSize: 12),
                  ),
                  maxLines: null,
                  style: const TextStyle(fontSize: 13),
                ),
              ),

              const SizedBox(height: 16),

              // Spreadsheet URL
              _fieldCard(
                isDark: isDark,
                icon: Icons.table_chart_rounded,
                iconColor: const Color(0xFF34A853),
                title: 'URL Google Spreadsheet',
                subtitle: 'Link spreadsheet agar bisa dibuka langsung dari aplikasi.',
                child: TextField(
                  controller: _spreadsheetUrlController,
                  decoration: const InputDecoration(
                    hintText: 'https://docs.google.com/spreadsheets/d/...',
                    hintStyle: TextStyle(fontSize: 12),
                  ),
                  maxLines: null,
                  style: const TextStyle(fontSize: 13),
                ),
              ),

              const SizedBox(height: 16),

              // Gemini API Key
              _fieldCard(
                isDark: isDark,
                icon: Icons.auto_awesome_rounded,
                iconColor: const Color(0xFFB86EF5),
                title: 'Gemini API Key',
                subtitle: 'Dapatkan API Key gratis dari Google AI Studio untuk fitur scan nota.',
                child: TextField(
                  controller: _geminiKeyController,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    hintText: 'AIzaSy...',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Simpan & Mulai',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B8DEF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF5B8DEF).withOpacity(0.25)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF5B8DEF), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Semua pengaturan bisa diubah kapan saja melalui menu Pengaturan di halaman utama.',
                        style: TextStyle(color: Color(0xFF5B8DEF), fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(subtitle,
                        style: const TextStyle(color: Color(0xFF8899BB), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
