import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Localization Integrity Tests', () {
    test('Arabic ARB file is valid JSON and contains no Mojibake', () {
      final file = File('lib/l10n/app_ar.arb');
      expect(file.existsSync(), isTrue, reason: 'app_ar.arb must exist');

      final content = file.readAsStringSync(encoding: utf8);
      
      // Should parse successfully
      late Map<String, dynamic> json;
      try {
        json = jsonDecode(content);
      } catch (e) {
        fail('app_ar.arb is not a valid JSON: $e');
      }

      // Check all values for corruption
      int errorCount = 0;
      final corruptPatterns = [
        'Ø', 'Ù', 'Ã', 'Â', 'â', '\uFFFD',
      ];

      for (final entry in json.entries) {
        // Skip metadata keys
        if (entry.key.startsWith('@')) continue;

        final value = entry.value.toString();

        // Check for specific mojibake characters
        for (final pattern in corruptPatterns) {
          if (value.contains(pattern)) {
            print('Corrupt value found at key "${entry.key}": $value');
            errorCount++;
            break;
          }
        }

        // Check for '????' replacing Arabic
        if (value.contains('????') && !value.contains('؟')) {
           // We might use multiple question marks genuinely, but usually not 4 in a row replacing a whole word
           if (RegExp(r'^\?+$').hasMatch(value) || value.contains('????')) {
              print('Corrupt missing value found at key "${entry.key}": $value');
              errorCount++;
           }
        }
      }

      expect(errorCount, equals(0), reason: 'Found $errorCount corrupted values in app_ar.arb');
    });
  });
}
