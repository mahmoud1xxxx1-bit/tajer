import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/products/domain/product.dart';

class ExcelImportService {
  static Future<List<Product>?> pickAndParseProductsExcel(String merchantId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      var bytes = file.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      
      List<Product> products = [];
      final uuid = const Uuid();

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table]!;
        // Skip header row
        for (int i = 1; i < sheet.rows.length; i++) {
          var row = sheet.rows[i];
          if (row.isEmpty || row[0] == null || row[0]!.value == null) continue;
          
          final name = row[0]?.value?.toString() ?? '';
          if (name.trim().isEmpty) continue;
          
          final barcode = row.length > 1 ? row[1]?.value?.toString() : null;
          final priceStr = row.length > 2 ? row[2]?.value?.toString() ?? '0' : '0';
          final costStr = row.length > 3 ? row[3]?.value?.toString() ?? '0' : '0';
          final qtyStr = row.length > 4 ? row[4]?.value?.toString() ?? '0' : '0';
          final category = row.length > 5 ? row[5]?.value?.toString() : null;

          final price = double.tryParse(priceStr) ?? 0.0;
          final costPrice = double.tryParse(costStr) ?? 0.0;
          final quantity = int.tryParse(qtyStr.split('.').first) ?? 0;

          products.add(
            Product(
              id: uuid.v4(),
              merchantId: merchantId,
              name: name,
              price: price,
              costPrice: costPrice > 0 ? costPrice : null,
              quantity: quantity,
              barcode: barcode,
              categoryId: category,
              modifiers: const [],
              recipe: const [],
              isManufacturedOnDemand: false,
              isArchived: false,
              taxMode: TaxMode.store,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
      return products;
    }
    return null;
  }

  static Future<void> downloadTemplate() async {
    var excel = Excel.createExcel();
    if (excel.tables.keys.contains('Sheet1')) {
      excel.delete('Sheet1');
    }
    
    Sheet sheetObject = excel['Products Template'];
    
    // Headers
    sheetObject.appendRow([
      TextCellValue('اسم المنتج (إلزامي)'),
      TextCellValue('الباركود (اختياري)'),
      TextCellValue('سعر البيع (إلزامي)'),
      TextCellValue('سعر التكلفة (اختياري)'),
      TextCellValue('الكمية (اختياري)'),
      TextCellValue('التصنيف (اختياري)'),
    ]);
    
    // Example row
    sheetObject.appendRow([
      TextCellValue('منتج تجريبي'),
      TextCellValue('123456789'),
      TextCellValue('15.5'),
      TextCellValue('10.0'),
      TextCellValue('50'),
      TextCellValue('تصنيف عام'),
    ]);

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String filePath = '${directory.path}/tajer_products_template.xlsx';
      
      File file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      await Share.shareXFiles([XFile(filePath)], text: 'قالب استيراد المنتجات - تاجر');
    }
  }
}
