def r(p):
    with open(p, 'r', encoding='utf-8') as f:
        t = f.read()
    t = t.replace(
        "DateFormat.yMMMd().format(tx.date)",
        "DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(tx.date)"
    )
    with open(p, 'w', encoding='utf-8') as f:
        f.write(t)

r('lib/features/accounting_notebook/presentation/notebook_home_screen.dart')
r('lib/features/accounting_notebook/presentation/notebook_person_statement_screen.dart')

csv_path = 'lib/features/accounting_notebook/data/notebook_csv_service.dart'
with open(csv_path, 'r', encoding='utf-8') as f:
    t = f.read()
t = t.replace(
    "DateFormat('yyyy/MM/dd').format(t.date); // Will fix to proper locale later",
    "DateFormat('yyyy/MM/dd', isAr ? 'ar' : 'en').format(t.date);"
)
with open(csv_path, 'w', encoding='utf-8') as f:
    f.write(t)
