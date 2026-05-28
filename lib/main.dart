import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/finance_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/first_setup_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  // Initialize notifications (skipped on web automatically)
  if (!kIsWeb) {
    final notifService = NotificationService();
    await notifService.init();
    await notifService.requestPermission();
    await notifService.scheduleDailyNotifications();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
      ],
      child: const FinancialFreedomApp(),
    ),
  );
}

class FinancialFreedomApp extends StatelessWidget {
  const FinancialFreedomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Financial Freedom',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppRouter(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
    );
  }
}

/// Router: shows loading → FirstSetupScreen (if no URL) or DashboardScreen
class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        // Still loading settings from SharedPreferences
        if (!provider.isInitialized) {
          return const _SplashScreen();
        }

        // Not configured yet → first-time setup
        if (!provider.isSetupComplete) {
          return const FirstSetupScreen();
        }

        // All good → main dashboard
        return const DashboardScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGreen, Color(0xFF0984E3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            const Text('Financial Freedom',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            const Text('Memuat pengaturan...', style: TextStyle(color: Color(0xFF8899BB))),
            const SizedBox(height: 24),
            const CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryGreen),
          ],
        ),
      ),
    );
  }
}
