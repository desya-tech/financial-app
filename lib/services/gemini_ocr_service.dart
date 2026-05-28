import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiUsageStats {
  final int usedToday;
  final int dailyLimit;
  final bool quotaExhausted;
  final DateTime resetAt;

  const GeminiUsageStats({
    required this.usedToday,
    required this.dailyLimit,
    required this.quotaExhausted,
    required this.resetAt,
  });

  int get remaining => (dailyLimit - usedToday).clamp(0, dailyLimit);
  double get usagePercent => usedToday / dailyLimit;
}

class GeminiOcrService {
  String? apiKey;

  static const int _freeDailyLimit = 1500; // Gemini Flash free tier
  static const String _kUsageKey = 'gemini_usage_count';
  static const String _kUsageDateKey = 'gemini_usage_date';
  static const String _kQuotaExhaustedKey = 'gemini_quota_exhausted';

  GeminiOcrService({this.apiKey});

  void setApiKey(String key) {
    apiKey = key;
  }

  // ── Usage Stats ─────────────────────────────────────────────────────
  Future<GeminiUsageStats> getUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final savedDate = prefs.getString(_kUsageDateKey) ?? '';

    // Reset counter if it's a new day
    if (savedDate != today) {
      await prefs.setInt(_kUsageKey, 0);
      await prefs.setString(_kUsageDateKey, today);
      await prefs.setBool(_kQuotaExhaustedKey, false);
    }

    final used = prefs.getInt(_kUsageKey) ?? 0;
    final exhausted = prefs.getBool(_kQuotaExhaustedKey) ?? false;

    // Next reset is at midnight (or next day 00:00 WIB)
    final now = DateTime.now();
    final resetAt = DateTime(now.year, now.month, now.day + 1);

    return GeminiUsageStats(
      usedToday: used,
      dailyLimit: _freeDailyLimit,
      quotaExhausted: exhausted,
      resetAt: resetAt,
    );
  }

  Future<void> _incrementUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final savedDate = prefs.getString(_kUsageDateKey) ?? '';
    if (savedDate != today) {
      await prefs.setString(_kUsageDateKey, today);
      await prefs.setInt(_kUsageKey, 1);
    } else {
      final count = (prefs.getInt(_kUsageKey) ?? 0) + 1;
      await prefs.setInt(_kUsageKey, count);
    }
  }

  Future<void> _markQuotaExhausted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kQuotaExhaustedKey, true);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> extractReceiptInfo(XFile imageFile, List<String> availableSubCategories) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('Gemini API Key is not set. Please set it in Settings.');
    }

    try {
      GenerativeModel model = GenerativeModel(
        model: 'gemini-3.5-flash',
        apiKey: apiKey!,
      );

      final imageBytes = await imageFile.readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);

      final prompt = '''
Analyze this receipt image. Extract all individual items purchased as a list.
For each item, extract:
1. "description": A short description of the item.
2. "amount": The price/total for that item (as a number).
3. "subCategory": Choose the most appropriate sub-category from this exact list: ${availableSubCategories.join(', ')}. If none matches well, use "Lainnya".

Also extract the overall date of the transaction (in YYYY-MM-DD format if possible).

Respond STRICTLY in JSON format without any markdown blocks or backticks. Example:
{
  "date": "2024-05-28",
  "items": [
    {
      "description": "Makan KFC",
      "amount": 50000,
      "subCategory": "Makan"
    },
    {
      "description": "Buku tulis",
      "amount": 15000,
      "subCategory": "Lainnya"
    }
  ]
}
''';

      final content = [
        Content.multi([TextPart(prompt), imagePart])
      ];

      GenerateContentResponse response;
      try {
        response = await model.generateContent(content);
      } catch (e) {
        if (e.toString().contains('is not found') || e.toString().contains('not supported')) {
          try {
            final modelsResponse = await http.get(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'));
            if (modelsResponse.statusCode == 200) {
               final modelsData = json.decode(modelsResponse.body);
               final modelsList = modelsData['models'] as List;
               String? fallbackModel;
               
               for (var m in modelsList) {
                 final name = m['name'] as String;
                 if (name.contains('flash') && !name.contains('lite') && !name.contains('tts') && !name.contains('audio') && !name.contains('preview')) {
                    fallbackModel = name.replaceFirst('models/', '');
                    break;
                 }
               }
               
               if (fallbackModel == null && modelsList.isNotEmpty) {
                 // Absolute fallback: pick any model that has "flash" or "pro"
                 for (var m in modelsList) {
                   final name = m['name'] as String;
                   if (name.contains('flash') || name.contains('pro')) {
                     fallbackModel = name.replaceFirst('models/', '');
                     break;
                   }
                 }
               }
               
               if (fallbackModel != null) {
                 model = GenerativeModel(model: fallbackModel, apiKey: apiKey!);
                 response = await model.generateContent(content);
               } else {
                 throw Exception('No multimodal model found in your account. Available: ${modelsList.map((e) => e['name']).join(', ')}');
               }
            } else {
               throw Exception('Failed to fetch models list: ${modelsResponse.body}');
            }
          } catch (inner) {
            throw Exception('Original error: $e. Auto-discovery failed: $inner');
          }
        } else {
          rethrow;
        }
      }
      
      final responseText = response.text?.trim() ?? '{}';
      
      // Clean up markdown if Gemini still returns it
      var cleanJson = responseText;
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final data = json.decode(cleanJson);
      await _incrementUsage(); // Track successful call
      return data;
      
    } catch (e) {
      final errStr = e.toString();
      // Detect quota exhaustion (429 / RESOURCE_EXHAUSTED)
      if (errStr.contains('429') ||
          errStr.contains('RESOURCE_EXHAUSTED') ||
          errStr.contains('quota')) {
        await _markQuotaExhausted();
        throw Exception('Kuota Gemini AI hari ini habis. Coba lagi besok atau upgrade ke paket berbayar.');
      }
      throw Exception('Failed to extract receipt info: $e');
    }
  }
}
