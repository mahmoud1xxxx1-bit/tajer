import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import '../domain/notebook_transaction.dart';
// Note: for Web, downloading CSV requires html package, but share_plus handles mobile.

class NotebookCsvService {
  static String generateCsv(List<NotebookTransaction> transactions, {bool isAr = true}) {
    final buffer = StringBuffer();
    // Headers
    if (isAr) {
      buffer.writeln('التاريخ,النوع,المبلغ,ملاحظة');
    } else {
      buffer.writeln('Date,Type,Amount,Note');
    }
    
    for (var t in transactions) {
      final dateStr = DateFormat('yyyy/MM/dd').format(t.date);
      final typeStr = _getTypeName(t.type, isAr);
      final amt = t.amount.toStringAsFixed(2);
      final note = (t.note ?? '').replaceAll(',', ' '); // prevent csv breaking
      buffer.writeln('$dateStr,$typeStr,$amt,$note');
    }
    
    return buffer.toString();
  }

  static Future<void> shareCsv(String csvData, String filename) async {
    final bytes = utf8.encode(csvData);
    final xfile = XFile.fromData(Uint8List.fromList(bytes), mimeType: 'text/csv', name: filename);
    await Share.shareXFiles([xfile], text: 'Accounting Report');
  }

  static String _getTypeName(String type, bool isAr) {
    switch(type) {
      case 'income': return isAr ? 'دخل' : 'Income';
      case 'expense': return isAr ? 'مصروف' : 'Expense';
      case 'receivable': return isAr ? 'دين لنا' : 'Receivable';
      case 'payable': return isAr ? 'دين علينا' : 'Payable';
      case 'receivable_payment': return isAr ? 'سداد دين لنا' : 'Receivable Payment';
      case 'payable_payment': return isAr ? 'سداد دين علينا' : 'Payable Payment';
      case 'account_transfer': return isAr ? 'تحويل حساب' : 'Transfer';
      default: return type;
    }
  }
}
