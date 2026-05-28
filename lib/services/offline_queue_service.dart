import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

const _kQueueKey = 'offline_queue';

/// Stores transactions that were added while offline.
/// Call [pendingCount] to check how many are waiting.
/// Call [popAll] to retrieve & clear the queue for syncing.
class OfflineQueueService {
  static final OfflineQueueService _i = OfflineQueueService._();
  factory OfflineQueueService() => _i;
  OfflineQueueService._();

  /// Number of transactions pending sync.
  Future<int> pendingCount() async {
    final list = await _load();
    return list.length;
  }

  /// Add a list of transactions to the offline queue.
  Future<void> enqueue(List<TransactionItem> txs) async {
    final existing = await _load();
    final encoded = txs.map((t) => t.toJson()).toList();
    existing.addAll(encoded);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kQueueKey, json.encode(existing));
  }

  /// Returns all pending transactions and CLEARS the queue.
  Future<List<TransactionItem>> popAll() async {
    final list = await _load();
    if (list.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kQueueKey);
    return list
        .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Peek at pending transactions without clearing.
  Future<List<TransactionItem>> peekAll() async {
    final list = await _load();
    return list
        .map((e) => TransactionItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<dynamic>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQueueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return json.decode(raw) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }
}
