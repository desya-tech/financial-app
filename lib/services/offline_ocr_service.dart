import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OfflineOcrService {
  /// Extracts text from an image and tries to do a basic heuristic extraction.
  /// Because ML Kit just returns flat text, we can't reliably build JSON items.
  /// We'll return a single transaction with all text as description,
  /// and try to find the largest number as the "Total" amount.
  Future<Map<String, dynamic>> extractReceiptInfoOffline(XFile imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      String fullText = recognizedText.text;
      
      // Basic heuristic: find largest number in the text
      // We look for numbers like 15000, 15.000, 15,000
      final regExp = RegExp(r'\b\d{1,3}(?:[.,]\d{3})*\b');
      final matches = regExp.allMatches(fullText);
      
      double maxAmount = 0;
      for (final match in matches) {
        String numStr = match.group(0) ?? '0';
        numStr = numStr.replaceAll(RegExp(r'[.,]'), '');
        double val = double.tryParse(numStr) ?? 0;
        if (val > maxAmount) {
          maxAmount = val;
        }
      }

      // We don't know the exact date from raw text reliably, use today.
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // We package the entire text into one single description line.
      // The user can edit it manually.
      return {
        "date": dateStr,
        "items": [
          {
            "description": "Hasil Scan Offline:\n${fullText.replaceAll('\n', ' / ')}",
            "amount": maxAmount,
            "subCategory": "Lainnya" // Default
          }
        ]
      };
    } finally {
      textRecognizer.close();
    }
  }
}
