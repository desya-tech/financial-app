import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/category_budget.dart';
import '../services/sheets_api_service.dart';
import '../services/gemini_ocr_service.dart';

class FinanceProvider with ChangeNotifier {
  final SheetsApiService _sheetsApi = SheetsApiService();
  final GeminiOcrService _ocrService = GeminiOcrService();

  List<TransactionItem> _transactions = [];
  List<CategoryBudget> _budgets = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isInitialized = false;

  String _webAppUrl = '';
  String _geminiApiKey = '';
  String _spreadsheetUrl = '';

  List<TransactionItem> get transactions => _transactions;
  List<CategoryBudget> get budgets => _budgets;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;
  /// True only when Apps Script URL has been configured
  bool get isSetupComplete => _webAppUrl.isNotEmpty;

  String get webAppUrl => _webAppUrl;
  String get geminiApiKey => _geminiApiKey;
  String get spreadsheetUrl => _spreadsheetUrl;

  GeminiOcrService get ocrService => _ocrService;

  FinanceProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _webAppUrl = prefs.getString('webAppUrl') ?? '';
    _geminiApiKey = prefs.getString('geminiApiKey') ?? '';
    _spreadsheetUrl = prefs.getString('spreadsheetUrl') ?? '';
    
    _sheetsApi.setWebAppUrl(_webAppUrl);
    _ocrService.setApiKey(_geminiApiKey);
    
    if (_webAppUrl.isNotEmpty) {
      await fetchData();
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> saveSettings(String url, String apiKey, String spreadsheetUrl) async {
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
    
    // Also persist settings to the Excel sheet
    if (_webAppUrl.isNotEmpty) {
      _sheetsApi.saveSetting('spreadsheetUrl', spreadsheetUrl);
      // Store actual geminiApiKey in sheet for auto-load on fresh install
      if (apiKey.isNotEmpty) {
        _sheetsApi.saveSetting('geminiApiKey', apiKey);
      }
      await fetchData();
    }
  }

  Future<void> fetchData() async {
    if (_webAppUrl.isEmpty) return;
    
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
      // Sort transactions by date descending
      _transactions.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addTransaction(TransactionItem transaction) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final success = await _sheetsApi.addTransaction(transaction);
      if (success) {
        _transactions.insert(0, transaction);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addTransactions(List<TransactionItem> transactions) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final success = await _sheetsApi.addTransactions(transactions);
      if (success) {
        for (var tx in transactions.reversed) {
          _transactions.insert(0, tx);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Gagal menyimpan. Cek koneksi & pastikan Apps Script sudah di-Deploy ulang.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addBudget(CategoryBudget budget) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final success = await _sheetsApi.addBudget(budget);
      if (success) {
        _budgets.add(budget);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      return false;
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
        final index = _budgets.indexWhere((b) => b.subCategory == budget.subCategory);
        if (index != -1) {
          _budgets[index] = budget;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
      return false;
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
        _isLoading = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Analytics Helpers
  
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
        .where((t) => t.date.isAfter(startDate.subtract(const Duration(days: 1))) && 
                      t.date.isBefore(endDate.add(const Duration(days: 1))))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  List<String> getAvailableSubCategories() {
    return _budgets.map((b) => b.subCategory).toList();
  }
  
  String getCategoryForSub(String subCategory) {
    for (var b in _budgets) {
      if (b.subCategory.toLowerCase() == subCategory.toLowerCase()) {
        return b.category;
      }
    }
    return "Kebutuhan"; // Default
  }
}
