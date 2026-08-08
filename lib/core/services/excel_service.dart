import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tajer/core/utils/date_formatter.dart';
import 'package:tajer/features/reports/data/reports_service.dart';

class ExcelService {
  static Future<void> exportToExcel(
    ReportsService reportsService,
    String currencyCode, {
    bool isAr = true,
    String? scopeLabel,
    bool isConsolidated = false,
    bool canViewCost = false,
  }) async {
    final excel = Excel.createExcel();

    if (excel.tables.keys.contains('Sheet1')) {
      excel.delete('Sheet1');
    }

    _createOverviewSheet(
      excel,
      reportsService,
      currencyCode,
      isAr: isAr,
      scopeLabel: scopeLabel,
      canViewCost: canViewCost,
    );
    _createSalesSheet(excel, reportsService, currencyCode, isAr: isAr);

    // Customer and supplier balances are merchant-wide master balances. They
    // are therefore exported only from the consolidated merchant report to
    // avoid presenting merchant-wide balances as if they belonged to one branch.
    if (isConsolidated) {
      _createCustomersSheet(excel, reportsService, currencyCode, isAr: isAr);
      _createSuppliersSheet(excel, reportsService, currencyCode, isAr: isAr);
    }

    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final filePath = '${directory.path}/tajer_report_$timestamp.xlsx';

    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: isAr ? 'تقرير تاجر - إكسل' : 'Tajer Report - Excel',
    );
  }

  static void _createOverviewSheet(
    Excel excel,
    ReportsService reportsService,
    String currencyCode, {
    required bool isAr,
    String? scopeLabel,
    required bool canViewCost,
  }) {
    final sheet = excel[isAr ? 'ملخص التقرير' : 'Report Summary'];

    sheet.appendRow([
      TextCellValue(isAr ? 'تقرير تاجر' : 'Tajer Report'),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'نطاق التقرير' : 'Report Scope'),
      TextCellValue(scopeLabel ?? (isAr ? 'غير محدد' : 'Not specified')),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'إجمالي المبيعات' : 'Total Sales'),
      TextCellValue('${reportsService.totalRevenue.toStringAsFixed(2)} $currencyCode'),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'صافي المبيعات قبل الضريبة' : 'Net Sales Before Tax'),
      TextCellValue('${reportsService.netSalesRevenue.toStringAsFixed(2)} $currencyCode'),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'الضريبة المحصلة' : 'Tax Collected'),
      TextCellValue('${reportsService.totalTaxCollected.toStringAsFixed(2)} $currencyCode'),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'المصروفات التشغيلية' : 'Operating Expenses'),
      TextCellValue('${reportsService.totalExpenses.toStringAsFixed(2)} $currencyCode'),
    ]);
    if (canViewCost) {
      sheet.appendRow([
        TextCellValue(isAr ? 'تكلفة البضاعة المباعة' : 'Cost of Goods Sold'),
        TextCellValue('${reportsService.totalCOGS.toStringAsFixed(2)} $currencyCode'),
      ]);
      sheet.appendRow([
        TextCellValue(isAr ? 'صافي الربح' : 'Net Profit'),
        TextCellValue('${reportsService.netProfit.toStringAsFixed(2)} $currencyCode'),
      ]);
    }
    sheet.appendRow([
      TextCellValue(isAr ? 'الدين الناتج عن مبيعات النطاق' : 'Debt from Scoped Sales'),
      TextCellValue('${reportsService.totalDebt.toStringAsFixed(2)} $currencyCode'),
    ]);

    sheet.appendRow([TextCellValue(''), TextCellValue('')]);
    sheet.appendRow([
      TextCellValue(isAr ? 'طريقة الدفع' : 'Payment Method'),
      TextCellValue(isAr ? 'الأموال المستلمة' : 'Money Received'),
    ]);

    String methodLabel(String method) {
      switch (method) {
        case 'cash':
          return isAr ? 'نقدي' : 'Cash';
        case 'card':
        case 'network':
          return isAr ? 'بطاقة / شبكة' : 'Card / Network';
        case 'transfer':
        case 'bank_transfer':
          return isAr ? 'تحويل بنكي' : 'Bank Transfer';
        default:
          return method;
      }
    }

    for (final entry in reportsService.paymentMethodsBreakdown.entries) {
      sheet.appendRow([
        TextCellValue(methodLabel(entry.key)),
        TextCellValue('${entry.value.toStringAsFixed(2)} $currencyCode'),
      ]);
    }
  }

  static void _createSalesSheet(
    Excel excel,
    ReportsService reportsService,
    String currencyCode, {
    required bool isAr,
  }) {
    final sheet = excel[isAr ? 'المبيعات' : 'Sales'];

    sheet.appendRow([
      TextCellValue(isAr ? 'رقم الطلب' : 'Order ID'),
      TextCellValue(isAr ? 'التاريخ' : 'Date'),
      TextCellValue(isAr ? 'اسم العميل' : 'Customer'),
      TextCellValue(isAr ? 'طريقة الدفع' : 'Payment Method'),
      TextCellValue(isAr ? 'الإجمالي' : 'Total'),
      TextCellValue(isAr ? 'المدفوع عند البيع' : 'Paid at Sale'),
      TextCellValue(isAr ? 'المتبقي' : 'Remaining'),
      TextCellValue(isAr ? 'الحالة' : 'Status'),
    ]);

    for (final order in reportsService.orders) {
      final shortId = order.id.length <= 8 ? order.id : order.id.substring(0, 8);
      sheet.appendRow([
        TextCellValue(shortId),
        TextCellValue(AppDateFormatter.format(order.createdAt)),
        TextCellValue(order.customerName),
        TextCellValue(_paymentMethodLabel(order.paymentMethod, order.isCredit, isAr)),
        TextCellValue('${order.total.toStringAsFixed(2)} $currencyCode'),
        TextCellValue('${order.paidAmount.toStringAsFixed(2)} $currencyCode'),
        TextCellValue('${(order.total - order.paidAmount).toStringAsFixed(2)} $currencyCode'),
        TextCellValue(_statusLabel(order.status, isAr)),
      ]);
    }
  }

  static String _paymentMethodLabel(String? method, bool isCredit, bool isAr) {
    if (isCredit) return isAr ? 'آجل' : 'Credit';
    switch (method) {
      case 'cash':
        return isAr ? 'نقدي' : 'Cash';
      case 'card':
      case 'network':
        return isAr ? 'بطاقة / شبكة' : 'Card / Network';
      case 'transfer':
      case 'bank_transfer':
        return isAr ? 'تحويل بنكي' : 'Bank Transfer';
      case 'split':
        return isAr ? 'دفع مختلط' : 'Split Payment';
      default:
        return method ?? (isAr ? 'نقدي' : 'Cash');
    }
  }

  static String _statusLabel(String status, bool isAr) {
    switch (status) {
      case 'cancelled':
        return isAr ? 'ملغي' : 'Cancelled';
      case 'completed':
        return isAr ? 'مكتمل' : 'Completed';
      case 'debt_repayment':
        return isAr ? 'تحصيل دين قديم' : 'Legacy Debt Collection';
      default:
        return status;
    }
  }

  static void _createCustomersSheet(
    Excel excel,
    ReportsService reportsService,
    String currencyCode, {
    required bool isAr,
  }) {
    final sheet = excel[isAr ? 'ديون العملاء - كل الفروع' : 'Customer Debt - All Branches'];

    sheet.appendRow([
      TextCellValue(isAr ? 'اسم العميل' : 'Customer'),
      TextCellValue(isAr ? 'الهاتف' : 'Phone'),
      TextCellValue(isAr ? 'إجمالي الدين على مستوى التاجر' : 'Merchant-wide Debt'),
    ]);

    final debtors = reportsService.customers.where((c) => c.totalDebt > 0).toList();
    for (final customer in debtors) {
      sheet.appendRow([
        TextCellValue(customer.name),
        TextCellValue(customer.phone),
        TextCellValue('${customer.totalDebt.toStringAsFixed(2)} $currencyCode'),
      ]);
    }
  }

  static void _createSuppliersSheet(
    Excel excel,
    ReportsService reportsService,
    String currencyCode, {
    required bool isAr,
  }) {
    final sheet = excel[isAr ? 'ديون الموردين - كل الفروع' : 'Supplier Debt - All Branches'];

    sheet.appendRow([
      TextCellValue(isAr ? 'اسم المورد' : 'Supplier'),
      TextCellValue(isAr ? 'الهاتف' : 'Phone'),
      TextCellValue(isAr ? 'الدين المستحق على مستوى التاجر' : 'Merchant-wide Debt'),
    ]);

    final suppliersWithDebt = reportsService.suppliers.where((s) => s.totalDebt > 0).toList();
    for (final supplier in suppliersWithDebt) {
      sheet.appendRow([
        TextCellValue(supplier.name),
        TextCellValue(supplier.phone ?? ''),
        TextCellValue('${supplier.totalDebt.toStringAsFixed(2)} $currencyCode'),
      ]);
    }
  }
}
