import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../services/spreadsheet_reader_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class FirstSetupScreen extends StatefulWidget {
  const FirstSetupScreen({super.key});

  @override
  State<FirstSetupScreen> createState() => _FirstSetupScreenState();
}

class _FirstSetupScreenState extends State<FirstSetupScreen> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = '';
  String _errorMessage = '';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Masukkan URL Spreadsheet terlebih dahulu.');
      return;
    }

    final sheetId = SpreadsheetReaderService.extractSheetId(url);
    if (sheetId == null) {
      setState(() => _errorMessage = 'URL tidak valid. Contoh: https://docs.google.com/spreadsheets/d/...');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _statusMessage = 'Membaca pengaturan dari spreadsheet...';
    });

    try {
      final reader = SpreadsheetReaderService();
      final settings = await reader.readSettings(url);

      setState(() => _statusMessage = 'Pengaturan ditemukan. Menyambungkan...');

      final webAppUrl = settings['webAppUrl'] ?? '';
      final geminiApiKey = settings['geminiApiKey'] ?? '';

      if (webAppUrl.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Kolom "webAppUrl" belum ada di sheet Settings.\n\n'
              'Pastikan Anda sudah menjalankan fungsi setupSheets() di Apps Script dan men-Deploy ulang.';
        });
        return;
      }

      final provider = Provider.of<FinanceProvider>(context, listen: false);
      await provider.saveSettings(webAppUrl, geminiApiKey, url);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _statusMessage = '';
      });
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

              // Logo / header
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
                'Selamat Datang!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Hubungkan ke Google Spreadsheet Anda untuk mulai memantau keuangan.',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? const Color(0xFF8899BB) : Colors.grey.shade600,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // Step indicator
              _stepCard(
                number: '1',
                title: 'Buka Google Spreadsheet Anda',
                subtitle: 'Klik ikon bagikan (Share) → pilih "Anyone with link" → Copy link',
                icon: Icons.table_chart_rounded,
                color: const Color(0xFF34A853),
              ),
              const SizedBox(height: 12),
              _stepCard(
                number: '2',
                title: 'Tempel URL di bawah ini',
                subtitle: 'App akan otomatis membaca Apps Script URL & Gemini Key dari sheet Settings',
                icon: Icons.link_rounded,
                color: AppTheme.primaryGreen,
              ),

              const SizedBox(height: 32),

              // URL input
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'URL Google Spreadsheet',
                  hintText: 'https://docs.google.com/spreadsheets/d/...',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.table_chart_rounded, color: Color(0xFF34A853)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  errorText: _errorMessage.isNotEmpty ? null : null,
                ),
                maxLines: null,
                style: const TextStyle(fontSize: 13),
              ),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: AppTheme.danger, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_isLoading && _statusMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                      ),
                      const SizedBox(width: 12),
                      Text(_statusMessage, style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sambungkan & Mulai', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),

              const SizedBox(height: 20),

              // Info box
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
                        'Apps Script URL & Gemini API Key akan otomatis terbaca dari kolom "webAppUrl" & "geminiApiKey" di sheet Settings.\n\nPastikan spreadsheet sudah di-share sebagai "Anyone with link can view".',
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

  Widget _stepCard({
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
