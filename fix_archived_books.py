import os
import glob

# The 6 files that need to be filtered by activeBooks (new operations)
files_to_fix = [
    "lib/features/accounting_notebook/presentation/debt_screen.dart",
    "lib/features/accounting_notebook/presentation/income_expense_screen.dart",
    "lib/features/accounting_notebook/presentation/notebook_accounts_screen.dart",
    "lib/features/accounting_notebook/presentation/notebook_categories_screen.dart",
    "lib/features/accounting_notebook/presentation/notebook_people_screen.dart",
    "lib/features/accounting_notebook/presentation/notebook_transfer_screen.dart",
]

# We need to replace:
# if (books.isEmpty) { ... }
# with:
# final activeBooks = books.where((b) => !(b.isArchived ?? false)).toList();
# if (activeBooks.isEmpty) { ... }
# And change books.first.id to activeBooks.first.id
# and books.any to activeBooks.any

def fix_active_books(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        code = f.read()
    
    if 'final activeBooks = books.where((b) => !(b.isArchived ?? false)).toList();' in code:
        return # already fixed
    
    # In debt, income, accounts(top), categories(top), people(top), transfer:
    # They all have `data: (books) { \n if (books.isEmpty) {`
    old_empty_check = "if (books.isEmpty) {"
    new_empty_check = "final activeBooks = books.where((b) => !(b.isArchived ?? false)).toList();\n          if (activeBooks.isEmpty) {"
    
    code = code.replace(old_empty_check, new_empty_check, 1) # Only replace the first one (the main body one)
    
    # Now replace the _selectedBookId logic for the first one
    code = code.replace(
        "if (_selectedBookId == null || !books.any((b) => b.id == _selectedBookId)) {",
        "if (_selectedBookId == null || !activeBooks.any((b) => b.id == _selectedBookId)) {"
    )
    code = code.replace(
        "_selectedBookId = books.first.id;",
        "_selectedBookId = activeBooks.first.id;"
    )

    # For accounts_screen & categories_screen & people_screen add dialogs:
    if "bookId == null || !books.any" in code:
        old_dialog_empty_check = "if (books.isEmpty) {"
        new_dialog_empty_check = "final activeBooks = books.where((b) => !(b.isArchived ?? false)).toList();\n          if (activeBooks.isEmpty) {"
        # We need to replace the SECOND occurrence of if (books.isEmpty) {
        # Actually it's better to just replace it manually where needed, or replace all:
        code = code.replace(
            "if (books.isEmpty) {",
            "final activeBooks = books.where((b) => !(b.isArchived ?? false)).toList();\n          if (activeBooks.isEmpty) {"
        )
        code = code.replace(
            "if (bookId == null || !books.any((b) => b.id == bookId)) {",
            "if (bookId == null || !activeBooks.any((b) => b.id == bookId)) {"
        )
        code = code.replace(
            "bookId = books.first.id;",
            "bookId = activeBooks.first.id;"
        )
        code = code.replace(
            "items: books.where((b) => !b.isArchived).map(",
            "items: activeBooks.map("
        )

    # In debt_screen, the list of items already uses books.where((b) => !b.isArchived)
    code = code.replace(
        "items: books.where((b) => !b.isArchived).map(",
        "items: activeBooks.map("
    )
    code = code.replace(
        "items: books.where((b) => !(b.isArchived ?? false)).map(",
        "items: activeBooks.map("
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(code)

for fp in files_to_fix:
    fix_active_books(fp)

# notebook_payment_screen.dart is slightly different
pmt_file = "lib/features/accounting_notebook/presentation/notebook_payment_screen.dart"
with open(pmt_file, 'r', encoding='utf-8') as f:
    code = f.read()

# notebook_payment_screen uses accounts.first.id
# final activeAccounts = allAccounts.where((a) => a.bookId == person.bookId && !(a.isArchived ?? false)).toList();
if "final activeAccounts = allAccounts.where((a) => a.bookId == person.bookId && !(a.isArchived ?? false)).toList();" not in code:
    code = code.replace(
        "final accounts = allAccounts.where((a) => a.bookId == person.bookId).toList();",
        "final accounts = allAccounts.where((a) => a.bookId == person.bookId && !(a.isArchived ?? false)).toList();"
    )
    with open(pmt_file, 'w', encoding='utf-8') as f:
        f.write(code)
