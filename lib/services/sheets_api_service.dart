import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import '../models/category_budget.dart';

class SheetsApiService {
  String? webAppUrl;

  SheetsApiService({this.webAppUrl});

  void setWebAppUrl(String url) {
    webAppUrl = url;
  }

  /// Build a GET URL with query parameters – avoids CORS preflight entirely.
  Uri _getUrl(Map<String, String> params) {
    final base = Uri.parse(webAppUrl!);
    return base.replace(queryParameters: {...base.queryParameters, ...params});
  }

  Future<bool> _getAction(Map<String, String> params) async {
    final response = await http.get(_getUrl(params));
    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return true;
        // Apps Script returned an error response
        throw Exception(data['message'] ?? 'Server error: status=${data['status']}');
      } catch (e) {
        if (e is Exception) rethrow;
        // JSON decode failed - probably a redirect HTML page (not redeployed)
        throw Exception('Response tidak valid. Pastikan Apps Script sudah di-Deploy ulang sebagai New Version.');
      }
    }
    throw Exception('HTTP ${response.statusCode} - Cek koneksi & URL Apps Script.');
  }

  Future<Map<String, dynamic>> fetchData() async {
    if (webAppUrl == null || webAppUrl!.isEmpty) {
      throw Exception('Apps Script Web App URL is not set.');
    }

    try {
      final response = await http.get(_getUrl({'action': 'get_data'}));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'success') {
          List<TransactionItem> transactions = (data['transactions'] as List)
              .map((item) => TransactionItem.fromJson(item))
              .toList();

          List<CategoryBudget> budgets = (data['budgets'] as List)
              .map((item) => CategoryBudget.fromJson(item))
              .toList();

          return {
            'transactions': transactions,
            'budgets': budgets,
            'spreadsheetUrl': data['spreadsheetUrl'] ?? '',
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch data');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch data: $e');
    }
  }

  Future<bool> addTransactions(List<TransactionItem> transactions) async {
    if (webAppUrl == null || webAppUrl!.isEmpty) {
      throw Exception('Apps Script Web App URL is not set.');
    }

    try {
      final txList = transactions.map((t) => {
        'date': t.date.toIso8601String(),
        'category': t.category,
        'subCategory': t.subCategory,
        'amount': t.amount,
        'description': t.description,
      }).toList();

      // NOTE: Do NOT manually Uri.encodeComponent here.
      // _getUrl uses Uri.replace(queryParameters:) which auto-encodes values.
      return await _getAction({
        'action': 'add_transactions',
        'data': json.encode(txList),
      });
    } catch (e) {
      throw Exception('Failed to add transactions: $e');
    }
  }

  Future<bool> addTransaction(TransactionItem transaction) async {
    if (webAppUrl == null || webAppUrl!.isEmpty) {
      throw Exception('Apps Script Web App URL is not set.');
    }

    try {
      return await _getAction({
        'action': 'add_transaction',
        'date': transaction.date.toIso8601String(),
        'category': transaction.category,
        'subCategory': transaction.subCategory,
        'amount': transaction.amount.toString(),
        'description': transaction.description,
      });
    } catch (e) {
      throw Exception('Failed to add transaction: $e');
    }
  }

  Future<bool> addBudget(CategoryBudget budget) async {
    if (webAppUrl == null || webAppUrl!.isEmpty) throw Exception('Apps Script Web App URL is not set.');
    try {
      return await _getAction({
        'action': 'add_budget',
        'category': budget.category,
        'subCategory': budget.subCategory,
        'budgetAmount': budget.budgetAmount.toString(),
      });
    } catch (e) {
      throw Exception('Failed to add budget: $e');
    }
  }

  Future<bool> updateBudget(CategoryBudget budget) async {
    if (webAppUrl == null || webAppUrl!.isEmpty) throw Exception('Apps Script Web App URL is not set.');
    try {
      return await _getAction({
        'action': 'update_budget',
        'subCategory': budget.subCategory,
        'budgetAmount': budget.budgetAmount.toString(),
      });
    } catch (e) {
      throw Exception('Failed to update budget: $e');
    }
  }

  Future<bool> deleteBudget(String subCategory) async {
    if (webAppUrl == null || webAppUrl!.isEmpty) throw Exception('Apps Script Web App URL is not set.');
    try {
      return await _getAction({
        'action': 'delete_budget',
        'subCategory': subCategory,
      });
    } catch (e) {
      throw Exception('Failed to delete budget: $e');
    }
  }

  Future<bool> saveSetting(String key, String value) async {
    if (webAppUrl == null || webAppUrl!.isEmpty) return false;
    try {
      return await _getAction({
        'action': 'save_settings',
        'key': key,
        'value': value,
      });
    } catch (_) {
      return false;
    }
  }
}
