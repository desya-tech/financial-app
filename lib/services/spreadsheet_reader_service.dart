import 'dart:convert';
import 'package:http/http.dart' as http;

/// Reads the Settings sheet from a Google Spreadsheet.
/// Uses CSV export as primary (simple, reliable) and gviz JSON as fallback.
/// Spreadsheet must be shared as "Anyone with link can view".
class SpreadsheetReaderService {
  /// Extract the spreadsheet ID from a full Google Sheets URL.
  static String? extractSheetId(String url) {
    final regex = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  /// Fetch key-value pairs from the "Settings" sheet.
  Future<Map<String, String>> readSettings(String spreadsheetUrl) async {
    final sheetId = extractSheetId(spreadsheetUrl);
    if (sheetId == null || sheetId.isEmpty) {
      throw Exception(
        'URL Spreadsheet tidak valid.\nContoh: https://docs.google.com/spreadsheets/d/...',
      );
    }

    // Try CSV export first — simplest and most reliable
    try {
      return await _readViaCsv(sheetId);
    } catch (csvError) {
      // Fallback: gviz JSON
      try {
        return await _readViaGviz(sheetId);
      } catch (gvizError) {
        throw Exception(
          'Gagal membaca Settings dari spreadsheet.\n\n'
          'Pastikan:\n'
          '1. Spreadsheet di-share "Anyone with link can view"\n'
          '2. Ada sheet bernama "Settings"\n'
          '3. Kolom Key & Value sudah terisi\n\n'
          'Detail: $csvError',
        );
      }
    }
  }

  // ── CSV approach ──────────────────────────────────────────────────────────

  Future<Map<String, String>> _readViaCsv(String sheetId) async {
    final url =
        'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&sheet=Settings';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'text/csv'},
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw Exception('Timeout. Cek koneksi internet.'),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = response.body;

    // If redirected to HTML login page, CSV export is blocked
    if (body.trimLeft().startsWith('<')) {
      throw Exception('Spreadsheet tidak bisa diakses publik.');
    }

    return _parseCsv(body);
  }

  Map<String, String> _parseCsv(String csvBody) {
    final Map<String, String> result = {};
    final lines = csvBody.split('\n');

    // Skip header row (line 0)
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cells = _splitCsvLine(line);
      if (cells.length >= 2) {
        final key = cells[0].trim();
        final value = cells[1].trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          result[key] = value;
        }
      }
    }

    return result;
  }

  /// Handles quoted CSV cells properly
  List<String> _splitCsvLine(String line) {
    final List<String> cells = [];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++; // skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }

  // ── gviz JSON approach (fallback) ─────────────────────────────────────────

  Future<Map<String, String>> _readViaGviz(String sheetId) async {
    final url =
        'https://docs.google.com/spreadsheets/d/$sheetId/gviz/tq?tqx=out:json&sheet=Settings';

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 20),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    return _parseGviz(response.body);
  }

  Map<String, String> _parseGviz(String raw) {
    final jsonStart = raw.indexOf('{');
    final jsonEnd = raw.lastIndexOf('}');
    if (jsonStart == -1 || jsonEnd == -1) {
      throw Exception('Format gviz tidak dikenali.');
    }

    final Map<String, dynamic> parsed =
        json.decode(raw.substring(jsonStart, jsonEnd + 1));

    if (parsed['status'] == 'error') {
      throw Exception('Spreadsheet tidak bisa diakses publik (access denied).');
    }

    final table = parsed['table'];
    if (table == null) {
      throw Exception('Sheet Settings tidak ditemukan.');
    }

    final rows = table['rows'] as List? ?? [];
    final Map<String, String> result = {};

    for (final row in rows) {
      final cells = row['c'] as List? ?? [];
      if (cells.length >= 2) {
        // For hyperlink cells: try 'v' (value) first, fallback to 'f' (formatted)
        final key = _cellStr(cells[0]);
        final value = _cellStr(cells[1]);
        if (key.isNotEmpty && value.isNotEmpty) {
          result[key] = value;
        }
      }
    }

    return result;
  }

  /// Extract string from gviz cell — handles both plain values and hyperlink cells
  String _cellStr(dynamic cell) {
    if (cell == null) return '';
    // 'v' = raw value, 'f' = formatted display value
    final v = cell['v'];
    if (v != null && v.toString().isNotEmpty) return v.toString();
    final f = cell['f'];
    if (f != null && f.toString().isNotEmpty) return f.toString();
    return '';
  }
}
