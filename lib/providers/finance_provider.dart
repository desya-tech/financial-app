import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/category_budget.dart';
import '../services/sheets_api_service.dart';
import '../services/gemini_ocr_service.dart';
import '../services/offline_queue_service.dart';

class FinanceProvider with ChangeNotifier {
  final SheetsApiService _sheetsApi = SheetsApiService();
  final GeminiOcrService _ocrService = GeminiOcrService();
  final OfflineQueueService _queue = OfflineQueueService();

  List<TransactionItem> _transactions = [];
  List<CategoryBudget> _budgets = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isInitialized = false;

  // ── Connectivity ────────────────────────────────────────────────────
  bool _isOnline = true;
  int _pendingSyncCount = 0;
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  String _webAppUrl = '';
  String _geminiApiKey = '';
  String _spreadsheetUrl = '';

  // ── Getters ─────────────────────────────────────────────────────────
  List<TransactionItem> get transactions => _transactions;
  List<CategoryBudget> get budgets => _budgets;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;
  bool get isSetupComplete => _webAppUrl.isNotEmpty;

  bool get isOnline => _isOnline;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isSyncing => _isSyncing;

  String get webAppUrl => _webAppUrl;
  String get geminiApiKey => _geminiApiKey;
  String get spreadsheetUrl => _spreadsheetUrl;

  GeminiOcrService get ocrService => _ocrService;

  // ── Init ─────────────────────────────────────────────────────────────
  FinanceProvider() {
    _loadSettings();
    _initConnectivity();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _initConnectivity() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final wasOffline = !_isOnline;
      _isOnline = results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);
      notifyListeners();

      // Auto-sync when connection is restored
      if (wasOffline && _isOnline && _pendingSyncCount > 0) {
        _syncQueue();
      }
    });

    // Check initial state
    Connectivity().checkConnectivity().then((results) {
      _isOnline = results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);
      notifyListeners();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _webAppUrl = prefs.getString('webAppUrl') ?? '';
    _geminiApiKey = prefs.getString('geminiApiKey') ?? '';
    _spreadsheetUrl = prefs.getString('spreadsheetUrl') ?? '';

    _sheetsApi.setWebAppUrl(_webAppUrl);
    _ocrService.setApiKey(_geminiApiKey);

    // Load pending count from queue
    _pendingSyncCount = await _queue.pendingCount();

    if (_webAppUrl.isNotEmpty) {
      await fetchData();
      // Try to sync any queued items after loading
      if (_pendingSyncCount > 0 && _isOnline) {
        await _syncQueue();
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  // ── Settings ─────────────────────────────────────────────────────────
  Future<void> saveSettings(
      String url, String apiKey, String spreadsheetUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webAppUrl', url);
    await prefs.setString('geminiApiKey', apiKey);
    await prefs.setString('spreadsheetUrl', spreadsheetUrl);

    _webAppUrl = url;
    _geminiApiKey = apiKey;
    _spreadsheetUrl = spreadsheetUrl;
    _sheetsApi.setWebAppUrl(_webAppUrl);
    _ocrService.setApiKey(_geminiApiKey);

    notifyListeners();

    if (_webAppUrl.isNotEmpty) {
      _sheetsApi.saveSetting('spreadsheetUrl', spreadsheetUrl);
      if (apiKey.isNotEmpty) {
        _sheetsApi.saveSetting('geminiApiKey', apiKey);
      }
      await fetchData();
    }
  }

  // ── Fetch from sheet ──────────────────────────────────────────────────
  Future<void> fetchData() async {
    if (_webAppUrl.isEmpty || !_isOnline) return;

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final data = await _sheetsApi.fetchData();
      _transactions = data['transactions'];
      _budgets = data['budgets'];
      if ((data['spreadsheetUrl'] as String).isNotEmpty) {
        _spreadsheetUrl = data['spreadsheetUrl'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('spreadsheetUrl', _spreadsheetUrl);
      }
      _transactions.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Add transactions (offline-aware) ──────────────────────────────────
  /// Returns true = saved (online or offline).
  /// Returns false = error.
  /// [savedOffline] will be set to true if saved to local queue.
  Future<({bool success, bool savedOffline})> addTransactions(
      List<TransactionItem> transactions) async {
    // Always add to local list immediately (optimistic UI)
    for (var tx in transactions.reversed) {
      _transactions.insert(0, tx);
    }
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();

    // OFFLINE → queue for later
    if (!_isOnline) {
      await _queue.enqueue(transactions);
      _pendingSyncCount = await _queue.pendingCount();
      notifyListeners();
      return (success: true, savedOffline: true);
    }

    // ONLINE → push to sheet
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final success = await _sheetsApi.addTransactions(transactions);
      _isLoading = false;
      if (!success) {
        _errorMessage =
            'Gagal menyimpan ke server. Cek koneksi & Apps Script.';
        // Keep in local list but also queue for retry
        await _queue.enqueue(transactions);
        _pendingSyncCount = await _queue.pendingCount();
      }
      notifyListeners();
      return (success: success, savedOffline: !success);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      // Queue for retry
      await _queue.enqueue(transactions);
      _pendingSyncCount = await _queue.pendingCount();
      notifyListeners();
      return (success: false, savedOffline: true);
    }
  }

  // ── Sync offline queue ────────────────────────────────────────────────
  Future<void> syncQueue() => _syncQueue();

  Future<void> _syncQueue() async {
    if (_isSyncing || !_isOnline || _webAppUrl.isEmpty) return;

    final pending = await _queue.peekAll();
    if (pending.isEmpty) {
      _pendingSyncCount = 0;
      notifyListeners();
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final success = await _sheetsApi.addTransactions(pending);
      if (success) {
        await _queue.popAll(); // clear queue
        _pendingSyncCount = 0;
      }
    } catch (_) {
      // Will retry next time online
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ── Budget CRUD ───────────────────────────────────────────────────────
  Future<bool> addBudget(CategoryBudget budget) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final success = await _sheetsApi.addBudget(budget);
      if (success) {
        _budgets.add(budget);
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBudget(CategoryBudget budget) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final success = await _sheetsApi.updateBudget(budget);
      if (success) {
        final index =
            _budgets.indexWhere((b) => b.subCategory == budget.subCategory);
        if (index != -1) _budgets[index] = budget;
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBudget(String subCategory) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final success = await _sheetsApi.deleteBudget(subCategory);
      if (success) {
        _budgets.removeWhere((b) => b.subCategory == subCategory);
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Analytics Helpers ─────────────────────────────────────────────────
  Map<String, double> getCategorySpending() {
    Map<String, double> spending = {};
    for (var tx in _transactions) {
      spending[tx.category] = (spending[tx.category] ?? 0) + tx.amount;
    }
    return spending;
  }

  Map<String, double> getSubCategorySpending(String category) {
    Map<String, double> spending = {};
    for (var tx in _transactions.where((t) => t.category == category)) {
      spending[tx.subCategory] = (spending[tx.subCategory] ?? 0) + tx.amount;
    }
    return spending;
  }

  double getTotalSpending(DateTime startDate, DateTime endDate) {
    return _transactions
        .where((t) =>
            t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            t.date.isBefore(endDate.add(const Duration(days: 1))))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  List<String> getAvailableSubCategories() =>
      _budgets.map((b) => b.subCategory).toList();

  String getCategoryForSub(String subCategory) {
    for (var b in _budgets) {
      if (b.subCategory.toLowerCase() == subCategory.toLowerCase()) {
        return b.category;
      }
    }
    return 'Kebutuhan';
  }
}
