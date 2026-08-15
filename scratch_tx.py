import os

filepath = r"C:\Users\loved\gamex1\tajer\lib\features\accounting_notebook\presentation\notebook_transactions_screen.dart"
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

old_str = """    final categoriesAsync = ref.watch(notebookCategoriesProvider);

    return Scaffold"""

new_str = """    final categoriesAsync = ref.watch(notebookCategoriesProvider);

    final accounts = accountsAsync.value?.where((a) => _selectedBookId == null || a.bookId == _selectedBookId).toList() ?? [];
    final people = peopleAsync.value?.where((p) => _selectedBookId == null || p.bookId == _selectedBookId).toList() ?? [];
    final categories = categoriesAsync.value?.where((c) => _selectedBookId == null || c.bookId == _selectedBookId).toList() ?? [];

    return Scaffold"""

content = content.replace(old_str, new_str)

old_str2 = """                            ...accountsAsync.maybeWhen(
                              data: (accs) => accs.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))),
                              orElse: () => [],
                            )"""
new_str2 = """                            ...accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis)))"""
content = content.replace(old_str2, new_str2)

old_str3 = """                            ...peopleAsync.maybeWhen(
                              data: (pep) => pep.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                              orElse: () => [],
                            )"""
new_str3 = """                            ...people.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)))"""
content = content.replace(old_str3, new_str3)

old_str4 = """                            ...categoriesAsync.maybeWhen(
                              data: (cats) => cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                              orElse: () => [],
                            )"""
new_str4 = """                            ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)))"""
content = content.replace(old_str4, new_str4)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
