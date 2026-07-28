import 'package:url_launcher/url_launcher.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/core/providers/settings_provider.dart';
import 'package:tajer/core/utils/date_formatter.dart';

class WhatsAppService {
  static Future<void> sendInvoice(Order order, AppCurrency currency, {double? taxPercentage, String? customerPhone}) async {
    // Determine the phone number to send to. 
    // Usually it would be from the customer object, but if they didn't provide one, they can't use this.
    // If we have customerPhone passed (e.g. from customer record), we use it.
    
    // Format the text invoice
    StringBuffer invoice = StringBuffer();
    invoice.writeln("🧾 *فاتورة مبيعات*");
    invoice.writeln("التاريخ: ${DateFormatter.formatDate(order.date)}");
    invoice.writeln("العميل: ${order.customerName ?? 'عميل عام'}");
    if (order.customerPhone != null && order.customerPhone!.isNotEmpty) {
      invoice.writeln("الهاتف: ${order.customerPhone}");
    }
    invoice.writeln("-------------------------");
    
    for (var item in order.items) {
      invoice.writeln("🔹 ${item.productName}");
      invoice.writeln("   الكمية: ${item.quantity} x السعر: ${item.price} ${currency.code}");
      invoice.writeln("   المجموع: ${item.total} ${currency.code}");
    }
    
    invoice.writeln("-------------------------");
    double subtotal = order.total;
    
    if (taxPercentage != null && taxPercentage > 0) {
      double taxAmount = subtotal * (taxPercentage / 100);
      double totalWithTax = subtotal + taxAmount;
      invoice.writeln("الإجمالي قبل الضريبة: $subtotal ${currency.code}");
      invoice.writeln("الضريبة ($taxPercentage%): $taxAmount ${currency.code}");
      invoice.writeln("الإجمالي الشامل: *${totalWithTax.toStringAsFixed(2)} ${currency.code}*");
    } else {
      invoice.writeln("الإجمالي: *${subtotal.toStringAsFixed(2)} ${currency.code}*");
    }
    
    invoice.writeln("المبلغ المدفوع: ${order.paidAmount} ${currency.code}");
    if (order.isCredit) {
      invoice.writeln("المتبقي (آجل): ${order.total - order.paidAmount} ${currency.code}");
    }
    
    invoice.writeln("-------------------------");
    invoice.writeln("شكراً لتسوقكم معنا! 🙏");

    String encodedMessage = Uri.encodeComponent(invoice.toString());
    
    // Check if phone number is available
    String targetPhone = customerPhone ?? order.customerPhone ?? '';
    
    Uri whatsappUri;
    if (targetPhone.isNotEmpty) {
      // Remove any non-numeric characters for url
      targetPhone = targetPhone.replaceAll(RegExp(r'[^\d+]'), '');
      if (!targetPhone.startsWith('+')) {
        // Assume default country code if missing, but it's better if they entered it.
        // We just pass it as is and let WhatsApp try to resolve it.
      }
      whatsappUri = Uri.parse("https://wa.me/$targetPhone?text=$encodedMessage");
    } else {
      whatsappUri = Uri.parse("https://wa.me/?text=$encodedMessage");
    }

    if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
      throw Exception("لا يمكن فتح تطبيق الواتساب. تأكد من تثبيته.");
    }
  }
}
