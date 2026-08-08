import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Arabic localization does not contain placeholder question marks', () {
    final arb = jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
        as Map<String, dynamic>;

    final corruptedEntries = arb.entries.where((entry) {
      if (entry.key.startsWith('@') || entry.value is! String) return false;
      return (entry.value as String).contains('???');
    }).toList();

    expect(corruptedEntries, isEmpty);
  });
}
