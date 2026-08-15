import 'package:excel/excel.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/notebook_transaction.dart';

class NotebookExcelService {
  static Future<void> exportToExcel(
      List<NotebookTransaction> transactions, String title, String currencyCode,
      {bool isAr = true}) async {
    var excel = Excel.createExcel();

    // Remove the default sheet
    if (excel.tables.keys.contains('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Sheet name must not exceed 31 chars for Excel
    String sheetName = title;
    if (sheetName.length > 30) {
      sheetName = sheetName.substring(0, 30);
    }
    _createTransactionsSheet(
        excel, transactions, sheetName, currencyCode, isAr);

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath =
          '${directory.path}/notebook_report_$timestamp.xlsx';

      File file = File(filePath);
      await file.writeAsBytes(fileBytes);

      await Share.shareXFiles([XFile(filePath)], text: title);
    }
  }

  static void _createTransactionsSheet(
      Excel excel,
      List<NotebookTransaction> transactions,
      String sheetName,
      String currencyCode,
      bool isAr) {
    Sheet sheetObject = excel[sheetName];

    // Headers
    sheetObject.appendRow([
      TextCellValue(isAr ? 'التاريخ (Date)' : 'Date'),
      TextCellValue(isAr ? 'النوع (Type)' : 'Type'),
      TextCellValue(isAr ? 'المبلغ ($currencyCode)' : 'Amount'),
      TextCellValue(isAr ? 'ملاحظة (Note)' : 'Note'),
    ]);

    double totalIncome = 0;
    double totalExpense = 0;

    for (var t in transactions) {
      if (t.type == 'income') totalIncome += t.amount;
      if (t.type == 'expense') totalExpense += t.amount;

      sheetObject.appendRow([
        TextCellValue(intl.DateFormat('yyyy/MM/dd').format(t.date)),
        TextCellValue(_getTypeName(t.type, isAr)),
        TextCellValue('${t.amount}'),
        TextCellValue(t.note ?? ''),
      ]);
    }

    // Summary at the end
    sheetObject.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('')
    ]);
    sheetObject.appendRow([
      TextCellValue(isAr ? 'إجمالي الدخل (Total Income)' : 'Total Income'),
      TextCellValue('$totalIncome'),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    sheetObject.appendRow([
      TextCellValue(
          isAr ? 'إجمالي المصروفات (Total Expenses)' : 'Total Expenses'),
      TextCellValue('$totalExpense'),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    sheetObject.appendRow([
      TextCellValue(isAr ? 'صافي الرصيد (Net Balance)' : 'Net Balance'),
      TextCellValue('${totalIncome - totalExpense}'),
      TextCellValue(''),
      TextCellValue(''),
    ]);
  }

  static String _getTypeName(String type, bool isAr) {
    switch (type) {
      case 'income':
        return isAr ? 'دخل / Income' : 'Income';
      case 'expense':
        return isAr ? 'مصروف / Expense' : 'Expense';
      case 'receivable':
        return isAr ? 'دين لنا / Receivable' : 'Receivable';
      case 'payable':
        return isAr ? 'دين علينا / Payable' : 'Payable';
      case 'receivable_payment':
        return isAr ? 'سداد دين لنا / Rec. Payment' : 'Receivable Payment';
      case 'payable_payment':
        return isAr ? 'سداد دين علينا / Pay. Payment' : 'Payable Payment';
      case 'account_transfer':
        return isAr ? 'تحويل حساب / Transfer' : 'Transfer';
      default:
        return type;
    }
  }
}
