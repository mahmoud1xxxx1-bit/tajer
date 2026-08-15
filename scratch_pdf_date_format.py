p = 'lib/features/accounting_notebook/data/notebook_pdf_service.dart'
with open(p, 'r', encoding='utf-8') as f:
    t = f.read()

t = t.replace(
    "intl.DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())",
    "intl.DateFormat('yyyy/MM/dd HH:mm', isAr ? 'ar' : 'en').format(DateTime.now())"
)
t = t.replace(
    "intl.DateFormat('yyyy/MM/dd').format(t.date)",
    "intl.DateFormat('yyyy/MM/dd', isAr ? 'ar' : 'en').format(t.date)"
)

with open(p, 'w', encoding='utf-8') as f:
    f.write(t)
