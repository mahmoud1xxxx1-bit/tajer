import 'package:excel/excel.dart';
import 'package:tajer/features/reports/data/reports_service.dart';
import 'package:tajer/core/utils/date_formatter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcelService {
  static Future<void> exportToExcel(ReportsService reportsService, String currencyCode) async {
    var excel = Excel.createExcel();
    
    // Remove the default sheet
    if (excel.tables.keys.contains('Sheet1')) {
      excel.delete('Sheet1');
    }

    _createSalesSheet(excel, reportsService, currencyCode);
    _createProductsSheet(excel, reportsService, currencyCode);
    _createCustomersSheet(excel, reportsService, currencyCode);
    _createSuppliersSheet(excel, reportsService, currencyCode);

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath = '${directory.path}/tajer_report_$timestamp.xlsx';
      
      File file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      await Share.shareXFiles([XFile(filePath)], text: 'تقرير متجر تاجر - إكسل');
    }
  }

  static void _createSalesSheet(Excel excel, ReportsService reportsService, String currencyCode) {
    Sheet sheetObject = excel['المبيعات'];
    
    // Headers
    sheetObject.appendRow([
      TextCellValue('رقم الطلب'),
      TextCellValue('التاريخ'),
      TextCellValue('اسم العميل'),
      TextCellValue('نوع الدفع'),
      TextCellValue('الإجمالي'),
      TextCellValue('المدفوع'),
      TextCellValue('المتبقي'),
      TextCellValue('الحالة'),
    ]);

    for (var order in reportsService.orders) {
      sheetObject.appendRow([
        TextCellValue(order.id.substring(0, 8)),
        TextCellValue(DateFormatter.formatDate(order.createdAt)),
        TextCellValue(order.customerName),
        TextCellValue(order.isCredit ? 'آجل' : 'نقدي'),
        TextCellValue('${order.total}'),
        TextCellValue('${order.paidAmount}'),
        TextCellValue('${order.total - order.paidAmount}'),
        TextCellValue(order.status),
      ]);
    }
  }

  static void _createProductsSheet(Excel excel, ReportsService reportsService, String currencyCode) {
    Sheet sheetObject = excel['المنتجات والمخزون'];
    
    sheetObject.appendRow([
      TextCellValue('اسم المنتج'),
      TextCellValue('التصنيف'),
      TextCellValue('السعر'),
      TextCellValue('الكمية المتوفرة'),
      TextCellValue('قيمة المخزون'),
    ]);

    for (var product in reportsService.products) {
      sheetObject.appendRow([
        TextCellValue(product.name),
        TextCellValue(product.categoryId ?? ''),
        TextCellValue('${product.price}'),
        TextCellValue('${product.quantity}'),
        TextCellValue('${product.quantity * product.price}'),
      ]);
    }
  }

  static void _createCustomersSheet(Excel excel, ReportsService reportsService, String currencyCode) {
    Sheet sheetObject = excel['العملاء والديون'];
    
    sheetObject.appendRow([
      TextCellValue('اسم العميل'),
      TextCellValue('الهاتف'),
      TextCellValue('إجمالي الديون ($currencyCode)'),
    ]);

    final debtors = reportsService.customers.where((c) => c.totalDebt > 0).toList();
    for (var customer in debtors) {
      sheetObject.appendRow([
        TextCellValue(customer.name),
        TextCellValue(customer.phone ?? ''),
        TextCellValue('${customer.totalDebt}'),
      ]);
    }
  }

  static void _createSuppliersSheet(Excel excel, ReportsService reportsService, String currencyCode) {
    Sheet sheetObject = excel['الموردين'];
    
    sheetObject.appendRow([
      TextCellValue('اسم المورد'),
      TextCellValue('الهاتف'),
      TextCellValue('الديون المستحقة للمورد ($currencyCode)'),
    ]);

    final suppliersWithDebt = reportsService.suppliers.where((s) => s.totalDebt > 0).toList();
    for (var supplier in suppliersWithDebt) {
      sheetObject.appendRow([
        TextCellValue(supplier.name),
        TextCellValue(supplier.phone ?? ''),
        TextCellValue('${supplier.totalDebt}'),
      ]);
    }
  }
}
