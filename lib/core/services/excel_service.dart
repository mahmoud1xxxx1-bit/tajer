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
    _createOrderDetailsSheet(excel, reportsService, currencyCode);
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
    Sheet sheetObject = excel['المبيعات - Sales'];
    
    // Headers
    sheetObject.appendRow([
      TextCellValue('رقم الطلب (Order ID)'),
      TextCellValue('التاريخ (Date)'),
      TextCellValue('اسم العميل (Customer Name)'),
      TextCellValue('نوع الدفع (Payment Type)'),
      TextCellValue('الإجمالي (Total)'),
      TextCellValue('المدفوع (Paid)'),
      TextCellValue('المتبقي (Remaining)'),
      TextCellValue('الحالة (Status)'),
      TextCellValue('الموظف (Employee)'),
    ]);

    for (var order in reportsService.orders) {
      sheetObject.appendRow([
        TextCellValue(order.id.substring(0, 8)),
        TextCellValue(AppDateFormatter.format(order.createdAt)),
        TextCellValue(order.customerName),
        TextCellValue(order.isCredit ? 'آجل / Credit' : 'نقدي / Cash'),
        TextCellValue('${order.total}'),
        TextCellValue('${order.paidAmount}'),
        TextCellValue('${order.total - order.paidAmount}'),
        TextCellValue(order.status),
        TextCellValue(order.creatorName ?? 'التاجر'),
      ]);
    }
  }

  static void _createOrderDetailsSheet(Excel excel, ReportsService reportsService, String currencyCode) {
    Sheet sheetObject = excel['تفاصيل الفواتير - Order Details'];
    
    // Headers
    sheetObject.appendRow([
      TextCellValue('رقم الطلب (Order ID)'),
      TextCellValue('التاريخ (Date)'),
      TextCellValue('اسم المنتج (Product Name)'),
      TextCellValue('الكمية (Quantity)'),
      TextCellValue('سعر البيع (Sell Price)'),
      TextCellValue('الإجمالي (Total)'),
    ]);

    for (var order in reportsService.orders) {
      if (order.status == 'cancelled') continue;
      for (var item in order.items) {
        sheetObject.appendRow([
          TextCellValue(order.id.substring(0, 8)),
          TextCellValue(AppDateFormatter.format(order.createdAt)),
          TextCellValue(item.productName),
          TextCellValue('${item.quantity}'),
          TextCellValue('${item.price}'),
          TextCellValue('${item.total}'),
        ]);
      }
    }
  }

  static void _createProductsSheet(Excel excel, ReportsService reportsService, String currencyCode) {
    Sheet sheetObject = excel['المنتجات والمخزون - Products'];
    
    sheetObject.appendRow([
      TextCellValue('اسم المنتج (Product Name)'),
      TextCellValue('التصنيف (Category)'),
      TextCellValue('الباركود (Barcode)'),
      TextCellValue('التكلفة (Cost Price)'),
      TextCellValue('سعر البيع (Sell Price)'),
      TextCellValue('الكمية المتوفرة (Stock Qty)'),
      TextCellValue('قيمة المخزون (Stock Value)'),
    ]);

    for (var product in reportsService.products) {
      sheetObject.appendRow([
        TextCellValue(product.name),
        TextCellValue(product.categoryId ?? ''),
        TextCellValue(product.barcode ?? ''),
        TextCellValue('${product.costPrice ?? 0.0}'),
        TextCellValue('${product.price}'),
        TextCellValue('${product.quantity}'),
        TextCellValue('${product.quantity * product.price}'),
      ]);
    }
  }

  static void _createCustomersSheet(Excel excel, ReportsService reportsService, String currencyCode) {
    Sheet sheetObject = excel['العملاء والديون - Customers'];
    
    sheetObject.appendRow([
      TextCellValue('اسم العميل (Customer Name)'),
      TextCellValue('الهاتف (Phone)'),
      TextCellValue('إجمالي الديون ($currencyCode)'),
    ]);

    final debtors = reportsService.customers.where((c) => c.totalDebt > 0).toList();
    for (var customer in debtors) {
      sheetObject.appendRow([
        TextCellValue(customer.name),
        TextCellValue(customer.phone),
        TextCellValue('${customer.totalDebt}'),
      ]);
    }
  }

  static void _createSuppliersSheet(Excel excel, ReportsService reportsService, String currencyCode) {
    Sheet sheetObject = excel['الموردين - Suppliers'];
    
    sheetObject.appendRow([
      TextCellValue('اسم المورد (Supplier Name)'),
      TextCellValue('الهاتف (Phone)'),
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
