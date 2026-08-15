import 'dart:io';

void replaceFile(String path, String from, String to) {
  var file = File(path);
  if (!file.existsSync()) return;
  var content = file.readAsStringSync();
  if (content.contains(from)) {
    file.writeAsStringSync(content.replaceAll(from, to));
  }
}

void main() {
  // 1. Notebook Accounts Screen
  replaceFile('lib/features/accounting_notebook/presentation/notebook_accounts_screen.dart', 
    'if (accounts.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.notebookNoAccountsFound));',
    '''
    final booksAsync = ref.watch(notebookBooksProvider);
          if (accounts.isEmpty) {
            return booksAsync.maybeWhen(
              data: (books) {
                if (books.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l10n.notebookEmptyBooks, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.push('/notebook/books'),
                          child: Text(l10n.notebookCreateBookCTA),
                        )
                      ],
                    ),
                  );
                }
                return Center(child: Text(l10n.notebookNoAccountsFound));
              },
              orElse: () => Center(child: Text(l10n.notebookNoAccountsFound)),
            );
          }
    '''
  );

  replaceFile('lib/features/accounting_notebook/presentation/notebook_accounts_screen.dart',
    'final books = ref.read(notebookBooksProvider).value ?? [];\n\n    showDialog(',
    '''
    showDialog(
'''
  );

  replaceFile('lib/features/accounting_notebook/presentation/notebook_accounts_screen.dart',
    '''
                DropdownButtonFormField<String?>(initialValue: bookId,
                  decoration: InputDecoration(labelText: l10n.notebookBook),
                  items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setState(() => bookId = val),
                ),
''',
    '''
                Consumer(
                  builder: (context, ref, child) {
                    final books = ref.watch(notebookBooksProvider).value ?? [];
                    if (books.isEmpty) {
                      return Text(l10n.notebookEmptyBooks, style: const TextStyle(color: Colors.red));
                    }
                    // Auto-select if only 1 book
                    if (books.length == 1 && bookId == null) {
                      bookId = books.first.id;
                    }
                    return DropdownButtonFormField<String?>(
                      value: bookId,
                      decoration: InputDecoration(labelText: l10n.notebookBook),
                      items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (val) => setState(() => bookId = val),
                    );
                  },
                ),
'''
  );

  replaceFile('lib/features/accounting_notebook/presentation/notebook_accounts_screen.dart',
    'import \'package:flutter_riverpod/flutter_riverpod.dart\';',
    'import \'package:flutter_riverpod/flutter_riverpod.dart\';\nimport \'package:go_router/go_router.dart\';'
  );


  // 2. Notebook People Screen
  replaceFile('lib/features/accounting_notebook/presentation/notebook_people_screen.dart', 
    'if (people.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.notebookNoPeopleFound));',
    '''
    final booksAsync = ref.watch(notebookBooksProvider);
          if (people.isEmpty) {
            return booksAsync.maybeWhen(
              data: (books) {
                if (books.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l10n.notebookEmptyBooks, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.push('/notebook/books'),
                          child: Text(l10n.notebookCreateBookCTA),
                        )
                      ],
                    ),
                  );
                }
                return Center(child: Text(l10n.notebookNoPeopleFound));
              },
              orElse: () => Center(child: Text(l10n.notebookNoPeopleFound)),
            );
          }
    '''
  );

  replaceFile('lib/features/accounting_notebook/presentation/notebook_people_screen.dart',
    'final books = ref.read(notebookBooksProvider).value ?? [];\n\n    showDialog(',
    '''
    showDialog(
'''
  );

  replaceFile('lib/features/accounting_notebook/presentation/notebook_people_screen.dart',
    '''
                DropdownButtonFormField<String?>(initialValue: bookId,
                  decoration: InputDecoration(labelText: l10n.notebookBook),
                  items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setState(() => bookId = val),
                ),
''',
    '''
                Consumer(
                  builder: (context, ref, child) {
                    final books = ref.watch(notebookBooksProvider).value ?? [];
                    if (books.isEmpty) {
                      return Text(l10n.notebookEmptyBooks, style: const TextStyle(color: Colors.red));
                    }
                    if (books.length == 1 && bookId == null) {
                      bookId = books.first.id;
                    }
                    return DropdownButtonFormField<String?>(
                      value: bookId,
                      decoration: InputDecoration(labelText: l10n.notebookBook),
                      items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (val) => setState(() => bookId = val),
                    );
                  },
                ),
'''
  );

  replaceFile('lib/features/accounting_notebook/presentation/notebook_people_screen.dart',
    'import \'package:flutter_riverpod/flutter_riverpod.dart\';',
    'import \'package:flutter_riverpod/flutter_riverpod.dart\';\nimport \'package:go_router/go_router.dart\';'
  );


  // 3. Notebook Categories Screen
  replaceFile('lib/features/accounting_notebook/presentation/notebook_categories_screen.dart', 
    'if (categories.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.notebookNoCategoriesFound));',
    '''
    final booksAsync = ref.watch(notebookBooksProvider);
          if (categories.isEmpty) {
            return booksAsync.maybeWhen(
              data: (books) {
                if (books.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l10n.notebookEmptyBooks, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.push('/notebook/books'),
                          child: Text(l10n.notebookCreateBookCTA),
                        )
                      ],
                    ),
                  );
                }
                return Center(child: Text(l10n.notebookNoCategoriesFound));
              },
              orElse: () => Center(child: Text(l10n.notebookNoCategoriesFound)),
            );
          }
    '''
  );

  replaceFile('lib/features/accounting_notebook/presentation/notebook_categories_screen.dart',
    'final books = ref.read(notebookBooksProvider).value ?? [];\n\n    showDialog(',
    '''
    showDialog(
'''
  );

  replaceFile('lib/features/accounting_notebook/presentation/notebook_categories_screen.dart',
    '''
                DropdownButtonFormField<String?>(initialValue: bookId,
                  decoration: InputDecoration(labelText: l10n.notebookBook),
                  items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setState(() => bookId = val),
                ),
''',
    '''
                Consumer(
                  builder: (context, ref, child) {
                    final books = ref.watch(notebookBooksProvider).value ?? [];
                    if (books.isEmpty) {
                      return Text(l10n.notebookEmptyBooks, style: const TextStyle(color: Colors.red));
                    }
                    if (books.length == 1 && bookId == null) {
                      bookId = books.first.id;
                    }
                    return DropdownButtonFormField<String?>(
                      value: bookId,
                      decoration: InputDecoration(labelText: l10n.notebookBook),
                      items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (val) => setState(() => bookId = val),
                    );
                  },
                ),
'''
  );

  replaceFile('lib/features/accounting_notebook/presentation/notebook_categories_screen.dart',
    'import \'package:flutter_riverpod/flutter_riverpod.dart\';',
    'import \'package:flutter_riverpod/flutter_riverpod.dart\';\nimport \'package:go_router/go_router.dart\';'
  );
}
