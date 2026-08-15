import 'package:flutter/widgets.dart';

class NotebookTerminology {
  const NotebookTerminology._();

  static bool _isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  static String accountsReceivable(BuildContext context) =>
      _isArabic(context) ? 'الذمم المدينة (لي)' : 'Accounts Receivable';

  static String accountsPayable(BuildContext context) =>
      _isArabic(context) ? 'الذمم الدائنة (عليّ)' : 'Accounts Payable';

  static String totalAccountsReceivable(BuildContext context) =>
      _isArabic(context)
          ? 'إجمالي الذمم المدينة (لي)'
          : 'Total Accounts Receivable';

  static String totalAccountsPayable(BuildContext context) =>
      _isArabic(context)
          ? 'إجمالي الذمم الدائنة (عليّ)'
          : 'Total Accounts Payable';

  static String receivePayment(BuildContext context) =>
      _isArabic(context) ? 'تحصيل' : 'Receive Payment';

  static String makePayment(BuildContext context) =>
      _isArabic(context) ? 'سداد' : 'Make Payment';

  static String partialReceivePayment(BuildContext context) =>
      _isArabic(context) ? 'تحصيل جزئي' : 'Partial Collection';

  static String fullReceivePayment(BuildContext context) =>
      _isArabic(context) ? 'تحصيل كامل' : 'Full Collection';

  static String partialMakePayment(BuildContext context) =>
      _isArabic(context) ? 'سداد جزئي' : 'Partial Payment';

  static String fullMakePayment(BuildContext context) =>
      _isArabic(context) ? 'سداد كامل' : 'Full Payment';

  static String totalAccountBalance(BuildContext context) =>
      _isArabic(context) ? 'إجمالي أرصدة الحسابات' : 'Total Account Balance';

  static String receivablesPayablesSection(BuildContext context) =>
      _isArabic(context)
          ? 'الذمم وأرصدة الحسابات الحالية'
          : 'Current Receivables, Payables & Account Balances';

  static String booksGuide(BuildContext context) => _isArabic(context)
      ? 'أنشئ دفترًا مستقلًا لكل نشاط تريد متابعة أمواله بشكل منفصل، مثل البوفيه أو المصروفات الشخصية.'
      : 'Create a separate book for each activity you want to track independently, such as your store or personal expenses.';
}
