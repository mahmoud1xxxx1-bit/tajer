import os

for p in [
    'lib/features/accounting_notebook/presentation/income_expense_screen.dart',
    'lib/features/accounting_notebook/presentation/notebook_transfer_screen.dart',
    'lib/features/accounting_notebook/presentation/notebook_payment_screen.dart'
]:
    t = open(p, 'r', encoding='utf-8').read()
    
    # income_expense_screen has:
    # final msg = l10n.notebookInsufficientBalance
    #                                       .replaceAll('{balance}', selectedAccount.balance.toStringAsFixed(2))
    #                                       .replaceAll('{amount}', amt.toStringAsFixed(2));
    
    if "l10n.notebookInsufficientBalance" in t and "replaceAll" in t:
        # replace the whole block by splitting or regex, or just replace string manually
        # let's be safe and use regex
        import re
        t = re.sub(
            r"l10n\.notebookInsufficientBalance\s*\.replaceAll\('\{balance\}',([^)]+)\)\s*\.replaceAll\('\{amount\}',([^)]+)\)",
            r"l10n.notebookInsufficientBalance(\2, \1)",
            t
        )
        open(p, 'w', encoding='utf-8').write(t)

