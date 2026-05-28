import 'dart:convert';
import 'package:http/http.dart' as http;

/// Reads the Settings sheet from a Google Spreadsheet using the public
/// gviz/tq CSV export – no API key required, only needs the sheet to be
/// shared as "Anyone with link can view".
class SpreadsheetReaderService {
  /// Extract the spreadsheet ID from a full Google Sheets URL.
  static String? extractSheetId(String url) {
    final regex = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  /// Fetch key-value pairs from the "Settings" sheet.
  /// Returns a Map<String, String> with all key→value pairs.
  Future<Map<String, String>> readSettings(String spreadsheetUrl) async {
    final sheetId = extractSheetId(spreadsheetUrl);
    if (sheetId == null || sheetId.isEmpty) {
      throw Exception('URL Spreadsheet tidak valid. Pastikan format URL benar.');
    }

    // Use gviz/tq to export Settings sheet as JSON – works for public sheets
    final url =
        'https://docs.google.com/spreadsheets/d/$sheetId/gviz/tq?tqx=out:json&sheet=Settings';

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Timeout. Cek koneksi internet.'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal membaca spreadsheet (HTTP ${response.statusCode}). '
        'Pastikan spreadsheet di-share sebagai "Anyone with link can view".',
      );
    }

    return _parseGvizResponse(response.body);
  }

  Map<String, String> _parseGvizResponse(String raw) {
    // gviz response starts with: /*O_o*/ google.visualization.Query.setResponse({...});
    // Strip that wrapper to get pure JSON
    final jsonStart = raw.indexOf('{');
    final jsonEnd = raw.lastIndexOf('}');
    if (jsonStart == -1 || jsonEnd == -1) {
      throw Exception(
        'Format respons tidak dikenali. '
        'Pastikan spreadsheet memiliki sheet bernama "Settings" dan bisa diakses publik.',
      );
    }

    final jsonStr = raw.substring(jsonStart, jsonEnd + 1);
    final Map<String, dynamic> parsed = json.decode(jsonStr);

    final table = parsed['table'];
    if (table == null) {
      throw Exception('Sheet "Settings" tidak ditemukan atau kosong.');
    }

    final rows = table['rows'] as List? ?? [];
    final Map<String, String> settings = {};

    for (final row in rows) {
      final cells = row['c'] as List? ?? [];
      if (cells.length >= 2) {
        final key = cells[0]?['v']?.toString() ?? '';
        final value = cells[1]?['v']?.toString() ?? '';
        if (key.isNotEmpty) {
          settings[key] = value;
        }
      }
    }

    return settings;
  }
}
