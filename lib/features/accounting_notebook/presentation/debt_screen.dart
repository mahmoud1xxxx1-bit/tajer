import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../data/accounting_notebook_provider.dart';

class DebtScreen extends ConsumerStatefulWidget {
  final bool isOwedToMe;
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
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _selectBook(String id) {
    ref.read(notebookCurrentBookIdProvider.notifier).state = id;
    setState(() {
      _selectedBookId = id;
      _selectedPersonId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.isOwedToMe ? l10n.moneyOwedToMe : l10n.moneyIOwe;
    final booksAsync = ref.watch(notebookBooksProvider);
    final peopleAsync = ref.watch(notebookPeopleProvider);
    final sharedBookId = ref.watch(notebookCurrentBookIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.genericErrorPrefix)),
        data: (books) {
          final activeBooks = books.where((b) => !b.isArchived).toList();
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
                  ),
                ],
              ),
            );
          }

          final candidate = _selectedBookId ?? sharedBookId;
          final selectedBookId = activeBooks.any((b) => b.id == candidate)
              ? candidate!
              : activeBooks.first.id;
          _selectedBookId = selectedBookId;

          return ListView(
            padding: const EdgeInsets.all(16),
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
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.notebookGuideDebt,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedBookId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.notebookBook),
                items: activeBooks
                    .map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) _selectBook(value);
                },
              ),
              const SizedBox(height: 16),
              peopleAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.genericErrorPrefix)),
                data: (allPeople) {
                  final people = allPeople
                      .where((p) => p.bookId == selectedBookId && !p.isArchived)
                      .toList();

                  if (people.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Text(l10n.notebookPeopleCreateFirst,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              ref
                                  .read(notebookCurrentBookIdProvider.notifier)
                                  .state = selectedBookId;
                              context.push('/notebook/people');
                            },
                            child: Text(l10n.add),
                          ),
                        ],
                      ),
                    );
                  }

                  if (_selectedPersonId == null ||
                      !people.any((p) => p.id == _selectedPersonId)) {
                    _selectedPersonId = people.first.id;
                  }

                  return Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedPersonId,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: l10n.person),
                          items: people
                              .map((p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(p.name,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedPersonId = value),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          decoration: InputDecoration(labelText: l10n.amount),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (value) {
                            final amount = double.tryParse(value ?? '');
                            if (value == null || value.trim().isEmpty) {
                              return l10n.notebookRequired;
                            }
                            if (amount == null || amount <= 0) {
                              return l10n.notebookInvalidAmount;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _noteController,
                          decoration: InputDecoration(labelText: l10n.note),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (!_formKey.currentState!.validate()) return;
                              try {
                                await ref.read(accountingNotebookProvider).createDebt(
                                      bookId: selectedBookId,
                                      personId: _selectedPersonId!,
                                      amount:
                                          double.parse(_amountController.text),
                                      isOwedToMe: widget.isOwedToMe,
                                      note: _noteController.text.trim(),
                                    );
                                if (mounted) context.pop();
                              } catch (_) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(l10n.genericErrorPrefix)),
                                );
                              }
                            },
                            child: Text(l10n.save),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
