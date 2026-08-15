import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class NotebookLocalizationHelper {
  static String getNotebookLocalizedType(BuildContext context, String type) {
    return getNotebookLocalizedTypeCustom(type, AppLocalizations.of(context)!);
  }

  static String getNotebookLocalizedTypeCustom(String type, AppLocalizations l10n) {
    switch (type) {
      case 'income': return l10n.income;
      case 'expense': return l10n.expense;
      case 'receivable': return l10n.notebookReceivable;
      case 'payable': return l10n.notebookPayable;
      case 'receivable_payment': return l10n.notebookPayment;
      case 'payable_payment': return l10n.notebookPaymentOfDebt;
      case 'account_transfer': return l10n.notebookTransfer;
      case 'opening_balance': return l10n.notebookOpeningBalance;
      default: return type;
    }
  }

  static String getAccountTypeName(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type.toLowerCase()) {
      case 'cash': return l10n.notebookAccountTypeCash;
      case 'bank': return l10n.notebookAccountTypeBank;
      case 'custody': return l10n.notebookAccountTypeCustody;
      default: return type;
    }
  }
}
