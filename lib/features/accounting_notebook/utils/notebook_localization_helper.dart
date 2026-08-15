import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

String getNotebookLocalizedType(BuildContext context, String type) {
  final l10n = AppLocalizations.of(context)!;
  switch (type) {
    case 'income': return l10n.income;
    case 'expense': return l10n.expense;
    case 'receivable': return l10n.notebookReceivable ;
    case 'payable': return l10n.notebookPayable ;
    case 'receivable_payment': return l10n.notebookPayment ;
    case 'payable_payment': return l10n.notebookPaymentOfDebt ;
    case 'account_transfer': return l10n.notebookTransfer ;
    default: return type;
  }
}
