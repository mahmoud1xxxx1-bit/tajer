import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class DebtScreen extends ConsumerStatefulWidget {
  final bool
      isOwedToMe; // true = I lend money (Receivable), false = I borrow money (Payable)
  const DebtScreen({super.key, required this.isOwedToMe});

  @override
  ConsumerState<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends ConsumerState<DebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedPersonId;
  String? _selectedBookId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.isOwedToMe ? l10n.moneyOwedToMe : l10n.moneyIOwe;
    final peopleAsync = ref.watch(notebookPeopleProvider);
    final booksAsync = ref.watch(notebookBooksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: booksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              Center(child: Text('${l10n.genericErrorPrefix}: $err')),
          data: (books) {
            final activeBooks =
                books.where((b) => !(b.isArchived)).toList();
            if (activeBooks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.notebookEmptyBooks,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.push('/notebook/books'),
                      child: Text(l10n.notebookCreateBookCTA),
                    )
                  ],
                ),
              );
            }
            if (_selectedBookId == null ||
                !activeBooks.any((b) => b.id == _selectedBookId)) {
              _selectedBookId = activeBooks.first.id;
            }

            return peopleAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: Text('${l10n.genericErrorPrefix}: $err')),
                data: (allPeople) {
                  final people = allPeople
                      .where((p) =>
                          p.bookId == _selectedBookId &&
                          !(p.isArchived))
                      .toList();
                  if (people.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.notebookPeopleCreateFirst,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.push('/notebook/people'),
                            child: Text(l10n.add),
                          )
                        ],
                      ),
                    );
                  }

                  if (_selectedPersonId == null ||
                      !people.any((p) => p.id == _selectedPersonId)) {
                    _selectedPersonId = people.first.id;
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.notebookGuideDebt,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedBookId,
                            decoration:
                                InputDecoration(labelText: l10n.notebookBooks),
                            items: books
                                .map((b) => DropdownMenuItem(
                                    value: b.id, child: Text(b.name)))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedBookId = val),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedPersonId,
                            decoration: InputDecoration(labelText: l10n.person),
                            items: people
                                .map((p) => DropdownMenuItem(
                                    value: p.id, child: Text(p.name)))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedPersonId = val),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            decoration: InputDecoration(labelText: l10n.amount),
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.isEmpty)
                                return l10n.notebookRequired;
                              if (double.tryParse(val) == null ||
                                  double.parse(val) <= 0)
                                return l10n.notebookInvalidAmount;
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _noteController,
                            decoration: InputDecoration(labelText: l10n.note),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  final amt =
                                      double.parse(_amountController.text);
                                  final svc =
                                      ref.read(accountingNotebookProvider);

                                  try {
                                    await svc.createDebt(
                                        bookId: _selectedBookId!,
                                        personId: _selectedPersonId!,
                                        amount: amt,
                                        isOwedToMe: widget.isOwedToMe,
                                        note: _noteController.text);
                                    if (mounted) context.pop();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                '${l10n.genericErrorPrefix}: $e')));
                                  }
                                }
                              },
                              child: Text(l10n.save),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                });
          }),
    );
  }
}
