p = 'lib/features/accounting_notebook/presentation/notebook_reports_screen.dart'
with open(p, 'r', encoding='utf-8') as f:
    t = f.read()

t = t.replace(
    "isAr: Localizations.localeOf(context).languageCode == 'ar'",
    "l10n, Localizations.localeOf(context).languageCode == 'ar'"
)
t = t.replace(
    "NotebookCsvService.generateCsv(transactions, isAr: Localizations.localeOf(context).languageCode == 'ar')",
    "NotebookCsvService.generateCsv(transactions, l10n, Localizations.localeOf(context).languageCode == 'ar')"
)
t = t.replace(
    "NotebookCsvService.shareCsv(csvData, 'notebook_report.csv', isAr: Localizations.localeOf(context).languageCode == 'ar')",
    "NotebookCsvService.shareCsv(csvData, 'notebook_report.csv', l10n)"
)

with open(p, 'w', encoding='utf-8') as f:
    f.write(t)
