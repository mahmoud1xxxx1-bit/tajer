import os

d = 'lib/features/accounting_notebook/presentation'
t = "l10n.localeName == 'ar' ? 'استرجاع هذا العنصر سيجعله متاحًا في العمليات الجديدة.' : 'Restoring this item will make it available for new operations.'"
r = 'l10n.notebookRestoreWarning'

for f in os.listdir(d):
    if f.endswith('.dart'):
        path = os.path.join(d, f)
        with open(path, 'r', encoding='utf-8') as file:
            content = file.read()
        if t in content:
            content = content.replace(t, r)
            with open(path, 'w', encoding='utf-8') as file:
                file.write(content)
