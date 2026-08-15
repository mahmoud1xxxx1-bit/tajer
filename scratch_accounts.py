import os

base_dir = r"C:\Users\loved\gamex1\tajer\lib\features\accounting_notebook\presentation"

def replace_in_file(filename, old_str, new_str):
    filepath = os.path.join(base_dir, filename)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if old_str in content:
        content = content.replace(old_str, new_str)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filename}")
    else:
        print(f"Pattern not found in {filename}")

replace_in_file(
    "notebook_accounts_screen.dart",
    """  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = 'Cash';
    String? bookId;
    final l10n = AppLocalizations.of(context)!;
    final books = ref.read(notebookBooksProvider).value ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.notebookAddAccount),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(initialValue: bookId,
                  decoration: InputDecoration(labelText: l10n.notebookBook),
                  items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setState(() => bookId = val),
                ),""",
    """  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => const _AddAccountDialog(),
    );
  }
}

class _AddAccountDialog extends ConsumerStatefulWidget {
  const _AddAccountDialog();
  @override
  ConsumerState<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends ConsumerState<_AddAccountDialog> {
  final nameCtrl = TextEditingController();
  final balanceCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  String type = 'Cash';
  String? bookId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final booksAsync = ref.watch(notebookBooksProvider);

    return AlertDialog(
      title: Text(l10n.notebookAddAccount),
      content: booksAsync.when(
        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Text('${l10n.genericErrorPrefix}: $err'),
        data: (books) {
          if (books.isEmpty) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.notebookEmptyBooks),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/notebook/books');
                  },
                  child: Text(l10n.notebookCreateBookCTA),
                )
              ],
            );
          }

          if (bookId == null || !books.any((b) => b.id == bookId)) {
            bookId = books.first.id;
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  value: bookId,
                  decoration: InputDecoration(labelText: l10n.notebookBook),
                  items: books.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setState(() => bookId = val),
                ),"""
)

replace_in_file(
    "notebook_accounts_screen.dart",
    """              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  if (bookId == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(l10n.notebookCreateBookFirst)));
                    return;
                  }
                  final bal = double.tryParse(balanceCtrl.text) ?? 0.0;
                  ref.read(accountingNotebookProvider).createAccount(
                    name: nameCtrl.text.trim(),
                    type: type,
                    openingBalance: bal,
                    bookId: bookId!,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );""",
    """              ],
            ),
          );
        }
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: () {
            if (nameCtrl.text.trim().isNotEmpty && bookId != null) {
              final bal = double.tryParse(balanceCtrl.text) ?? 0.0;
              ref.read(accountingNotebookProvider).createAccount(
                name: nameCtrl.text.trim(),
                type: type,
                openingBalance: bal,
                bookId: bookId!,
              );
              Navigator.pop(context);
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );"""
)

