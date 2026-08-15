import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class NotebookLocalizationHelper {
  static String getNotebookLocalizedType(BuildContext context, String type) {
    return getNotebookLocalizedTypeCustom(type, AppLocalizations.of(context)!);
  }

  static String getNotebookLocalizedTypeCustom(
      String type, AppLocalizations l10n) {
    final isAr = l10n.localeName.toLowerCase().startsWith('ar');
    switch (type) {
      case 'income':
        return l10n.income;
      case 'expense':
        return l10n.expense;
      case 'receivable':
        return isAr ? 'الذمم المدينة (لي)' : 'Accounts Receivable';
      case 'payable':
        return isAr ? 'الذمم الدائنة (عليّ)' : 'Accounts Payable';
      case 'receivable_payment':
        return isAr ? 'تحصيل' : 'Receive Payment';
      case 'payable_payment':
        return isAr ? 'سداد' : 'Make Payment';
      case 'account_transfer':
        return l10n.notebookTransfer;
      case 'opening_balance':
        return l10n.notebookOpeningBalance;
      default:
        return type;
    }
  }

  static String getAccountTypeName(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type.toLowerCase()) {
      case 'cash':
        return l10n.notebookAccountTypeCash;
      case 'bank':
        return l10n.notebookAccountTypeBank;
      case 'custody':
        return l10n.notebookAccountTypeCustody;
      default:
        return type;
    }
  }
}
