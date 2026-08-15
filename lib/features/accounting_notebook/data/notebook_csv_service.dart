import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import '../domain/notebook_transaction.dart';
import '../../../l10n/app_localizations.dart';
import '../utils/notebook_localization_helper.dart';

class NotebookCsvService {
  static String generateCsv(List<NotebookTransaction> transactions, AppLocalizations l10n, bool isAr) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln('${l10n.notebookDate},${l10n.notebookType},${l10n.amount},${l10n.note}');
    
    for (var t in transactions) {
      final dateStr = DateFormat('yyyy/MM/dd', isAr ? 'ar' : 'en').format(t.date);
      final typeStr = NotebookLocalizationHelper.getNotebookLocalizedTypeCustom(t.type, l10n);
      final amt = t.amount.toStringAsFixed(2);
      final note = (t.note ?? '').replaceAll(',', ' '); // prevent csv breaking
      buffer.writeln('$dateStr,$typeStr,$amt,$note');
    }
    
    return buffer.toString();
  }

  static Future<void> shareCsv(String csvData, String filename, AppLocalizations l10n) async {
    final bytes = utf8.encode(csvData);
    final xfile = XFile.fromData(Uint8List.fromList(bytes), mimeType: 'text/csv', name: filename);
    await Share.shareXFiles([xfile], text: l10n.notebookReportTitle);
  }
}
