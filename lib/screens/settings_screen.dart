import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/finance_provider.dart';
import '../services/gemini_ocr_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _webAppUrlController = TextEditingController();
  final _geminiApiKeyController = TextEditingController();
  final _spreadsheetUrlController = TextEditingController();
  bool _isSaving = false;
  bool _obscureKey = true;
  bool _notifEnabled = false;
  GeminiUsageStats? _geminiStats;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    _webAppUrlController.text = provider.webAppUrl;
    _geminiApiKeyController.text = provider.geminiApiKey;
    _spreadsheetUrlController.text = provider.spreadsheetUrl;
    _notifEnabled = !kIsWeb;
    _loadGeminiStats();
  }

  @override
  void dispose() {
    _webAppUrlController.dispose();
    _geminiApiKeyController.dispose();
    _spreadsheetUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadGeminiStats() async {
    final stats = await GeminiOcrService().getUsageStats();
    if (mounted) setState(() => _geminiStats = stats);
  }

  void _save() async {
    setState(() => _isSaving = true);

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    await provider.saveSettings(
      _webAppUrlController.text.trim(),
      _geminiApiKeyController.text.trim(),
      _spreadsheetUrlController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryGreen,
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.black87),
              SizedBox(width: 10),
              Text('Pengaturan disimpan!', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _openSpreadsheet() async {
    final url = _spreadsheetUrlController.text.trim();
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final borderColor = isDark ? AppTheme.darkCardBorder : Colors.grey.shade200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Status card
          Consumer<FinanceProvider>(
            builder: (context, provider, _) {
              final hasUrl = provider.webAppUrl.isNotEmpty;
              final hasKey = provider.geminiApiKey.isNotEmpty;
              final hasSheet = provider.spreadsheetUrl.isNotEmpty;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status Koneksi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 12),
                    _statusRow(Icons.cloud_rounded, 'Google Apps Script', hasUrl),
                    const SizedBox(height: 8),
                    _statusRow(Icons.table_chart_rounded, 'Google Spreadsheet', hasSheet),
                    const SizedBox(height: 8),
                    _statusRow(Icons.auto_awesome_rounded, 'Gemini AI (OCR)', hasKey),
                    if (hasSheet) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Buka Spreadsheet', style: TextStyle(fontSize: 13)),
                        onPressed: _openSpreadsheet,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF34A853),
                          side: const BorderSide(color: Color(0xFF34A853)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Apps Script section
          _sectionCard(
            isDark: isDark,
            icon: Icons.code_rounded,
            iconColor: const Color(0xFF5B8DEF),
            title: 'Google Apps Script URL',
            subtitle: 'Deploy skrip sebagai Web App (Anyone) dan tempel URL-nya di sini.',
            child: TextField(
              controller: _webAppUrlController,
              decoration: const InputDecoration(
                hintText: 'https://script.google.com/macros/s/.../exec',
                hintStyle: TextStyle(fontSize: 12),
              ),
              maxLines: null,
              style: const TextStyle(fontSize: 13),
            ),
          ),

          const SizedBox(height: 16),

          // Spreadsheet URL section
          _sectionCard(
            isDark: isDark,
            icon: Icons.table_chart_rounded,
            iconColor: const Color(0xFF34A853),
            title: 'URL Google Spreadsheet',
            subtitle: 'Tempel link spreadsheet Anda agar bisa dibuka langsung dari aplikasi.',
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

          // Gemini section
          _sectionCard(
            isDark: isDark,
            icon: Icons.auto_awesome_rounded,
            iconColor: const Color(0xFFB86EF5),
            title: 'Gemini API Key',
            subtitle: 'Dapatkan API Key gratis dari Google AI Studio untuk fitur scan nota AI.',
            child: TextField(
              controller: _geminiApiKeyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),

          // Gemini AI Usage Stats card
          if (_geminiStats != null)
            _buildGeminiUsageCard(isDark, _geminiStats!),

          const SizedBox(height: 16),

          // Notification section
          if (!kIsWeb)
            Container(
              padding: const EdgeInsets.all(20),
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
                          color: AppTheme.accentGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: AppTheme.accentGold, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pengingat Harian', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            Text('Notifikasi otomatis jam 12:00 & 21:00 setiap hari', style: TextStyle(color: Color(0xFF8899BB), fontSize: 11)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _notifEnabled,
                        activeColor: AppTheme.primaryGreen,
                        onChanged: (val) async {
                          setState(() => _notifEnabled = val);
                          final svc = NotificationService();
                          if (val) {
                            final granted = await svc.requestPermission();
                            if (granted) {
                              await svc.scheduleDailyNotifications();
                              await svc.sendTestNotification();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppTheme.primaryGreen,
                                    content: Text('✅ Notifikasi dijadwalkan!', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
                                  ),
                                );
                              }
                            } else {
                              setState(() => _notifEnabled = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Izin notifikasi ditolak. Aktifkan di Pengaturan HP.')),
                                );
                              }
                            }
                          } else {
                            await svc.cancelAllNotifications();
                          }
                        },
                      ),
                    ],
                  ),
                  if (_notifEnabled) ...[  
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded, color: AppTheme.accentGold, size: 16),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Jam 12:00 - Pengingat siang\nJam 21:00 - Rekap malam\nNotifikasi muncul setiap hari otomatis.',
                              style: TextStyle(color: AppTheme.accentGold, fontSize: 12, height: 1.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          if (!kIsWeb) const SizedBox(height: 16),

          // Test notification button (only on non-web)
          if (!kIsWeb)
            OutlinedButton.icon(
              onPressed: () async {
                final svc = NotificationService();
                await svc.sendTestNotification();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppTheme.accentGold,
                      duration: Duration(seconds: 3),
                      content: Row(
                        children: [
                          Icon(Icons.notifications_active_rounded, color: Colors.black87),
                          SizedBox(width: 8),
                          Text(
                            'Notifikasi test dikirim! Cek di panel atas HP.',
                            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentGold,
                side: const BorderSide(color: AppTheme.accentGold),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.notification_add_rounded),
              label: const Text(
                'Test Notifikasi Sekarang',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Simpan & Sambungkan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),

          const SizedBox(height: 16),

          // Help card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.primaryGreen, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pastikan Apps Script Anda di-Deploy dengan:\n• Execute as: Me (Saya)\n• Who has access: Anyone (Siapa saja)\n• Versi: New Version (setiap kali ada update kode)',
                    style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, bool active) {
    return Row(
      children: [
        Icon(icon, size: 18, color: active ? AppTheme.primaryGreen : const Color(0xFF8899BB)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: active ? AppTheme.primaryGreen.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            active ? 'Terhubung' : 'Belum diset',
            style: TextStyle(
              color: active ? AppTheme.primaryGreen : const Color(0xFF8899BB),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF8899BB), fontSize: 11), maxLines: 2),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildGeminiUsageCard(bool isDark, GeminiUsageStats stats) {
    final pct = stats.usagePercent.clamp(0.0, 1.0);
    final resetTime = DateFormat('HH:mm, dd MMM', 'id_ID').format(stats.resetAt);

    Color barColor;
    String statusLabel;
    if (stats.quotaExhausted) {
      barColor = AppTheme.danger;
      statusLabel = 'Kuota habis!';
    } else if (pct > 0.8) {
      barColor = Colors.orange;
      statusLabel = 'Hampir habis';
    } else {
      barColor = AppTheme.primaryGreen;
      statusLabel = 'Normal';
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: stats.quotaExhausted
              ? AppTheme.danger.withOpacity(0.4)
              : isDark ? AppTheme.darkCardBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFB86EF5).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFB86EF5), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gemini AI - Sisa Kredit Harian',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('Free tier: ${stats.dailyLimit} request/hari',
                        style: const TextStyle(color: Color(0xFF8899BB), fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel,
                    style: TextStyle(color: barColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF2A3047) : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statChip(Icons.check_circle_outline_rounded, 'Digunakan', '${stats.usedToday}', Colors.blue),
              const SizedBox(width: 8),
              _statChip(Icons.battery_full_rounded, 'Tersisa', '~${stats.remaining}', barColor),
              const SizedBox(width: 8),
              _statChip(Icons.refresh_rounded, 'Reset', resetTime, const Color(0xFF8899BB)),
            ],
          ),
          if (stats.quotaExhausted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kuota AI hari ini habis. Scan nota tidak bisa digunakan hingga $resetTime.',
                      style: const TextStyle(color: AppTheme.danger, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label, style: const TextStyle(color: Color(0xFF8899BB), fontSize: 9), maxLines: 1),
          ],
        ),
      ),
    );
  }
}
