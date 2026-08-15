import os
import json

# Fix 1
p = 'lib/features/accounting_notebook/presentation/notebook_home_screen.dart'
t = open(p, 'r', encoding='utf-8').read()
t = t.replace('getNotebookLocalizedType(context, tx.type)', 'NotebookLocalizationHelper.getNotebookLocalizedType(context, tx.type)')
if "import '../utils/notebook_localization_helper.dart';" not in t:
    t = t.replace("import '../data/accounting_notebook_provider.dart';", "import '../data/accounting_notebook_provider.dart';\nimport '../utils/notebook_localization_helper.dart';")
open(p, 'w', encoding='utf-8').write(t)

# Fix 2, 7, 8
for p in [
    'lib/features/accounting_notebook/presentation/income_expense_screen.dart',
    'lib/features/accounting_notebook/presentation/notebook_transfer_screen.dart',
    'lib/features/accounting_notebook/presentation/notebook_payment_screen.dart'
]:
    t = open(p, 'r', encoding='utf-8').read()
    t = t.replace(
        "l10n.notebookAccountBalance\n                                          .replaceAll('{balance}', selectedAccount.balance.toStringAsFixed(2))",
        "l10n.notebookAccountBalance(selectedAccount.balance.toStringAsFixed(2))"
    )
    t = t.replace(
        "l10n.notebookAccountBalance\n                                      .replaceAll('{balance}', selectedAccount.balance.toStringAsFixed(2))",
        "l10n.notebookAccountBalance(selectedAccount.balance.toStringAsFixed(2))"
    )
    t = t.replace(
        "l10n.notebookAccountBalance\n                                    .replaceAll('{balance}', selectedAccount.balance.toStringAsFixed(2))",
        "l10n.notebookAccountBalance(selectedAccount.balance.toStringAsFixed(2))"
    )
    open(p, 'w', encoding='utf-8').write(t)

# Fix 4, 5
p = 'lib/features/accounting_notebook/presentation/notebook_reports_screen.dart'
t = open(p, 'r', encoding='utf-8').read()
t = t.replace(
    "await NotebookCsvService.shareCsv(csvData, 'notebook_report_$bookStr.csv', l10n, isAr);",
    "await NotebookCsvService.shareCsv(csvData, 'notebook_report_$bookStr.csv', l10n);"
)
if "import 'package:go_router/go_router.dart';" not in t:
    t = t.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:go_router/go_router.dart';")
open(p, 'w', encoding='utf-8').write(t)

# Fix 9
p = 'lib/features/accounting_notebook/data/accounting_notebook_provider.dart'
t = open(p, 'r', encoding='utf-8').read()
if "createdAt: DateTime.now()" not in t.split('opening_balance')[1]:
    t = t.replace(
        "note: 'Opening Balance', // Fallback, will be translated in UI\n      );",
        "note: 'Opening Balance', // Fallback, will be translated in UI\n        createdAt: DateTime.now(),\n      );"
    )
open(p, 'w', encoding='utf-8').write(t)

# Fix 3, 6 (ARBs)
def add_arb(path, keys):
    with open(path, 'r', encoding='utf-8') as f:
        d = json.load(f)
    d.update(keys)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(d, f, ensure_ascii=False, indent=2)

add_arb('lib/l10n/app_ar.arb', {
    "notebookGuideDebt": "هنا يمكنك إضافة الديون أو المستحقات.",
    "notebookGuideReports": "استعرض واطبع تقارير الدفاتر من هنا."
})
add_arb('lib/l10n/app_en.arb', {
    "notebookGuideDebt": "Here you can add debts or receivables.",
    "notebookGuideReports": "View and print notebook reports here."
})
