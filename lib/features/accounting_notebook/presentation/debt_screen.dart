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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.isOwedToMe ? l10n.moneyOwedToMe : l10n.moneyIOwe;
    final peopleAsync = ref.watch(notebookPeopleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: peopleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${AppLocalizations.of(context)!.genericErrorPrefix}: $err')),
        data: (people) {
          if (people.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.notebookPeopleCreateFirst));
          }
          if (_selectedPersonId == null) _selectedPersonId = people.first.id;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedPersonId,
                    decoration: InputDecoration(labelText: l10n.person),
                    items: people.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                    onChanged: (val) => setState(() => _selectedPersonId = val),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(labelText: l10n.amount),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (double.tryParse(val) == null || double.parse(val) <= 0) return 'Invalid amount';
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
                          final amt = double.parse(_amountController.text);
                          final svc = ref.read(accountingNotebookProvider);
                          
                          try {
                            await svc.createDebt(
                              bookId: 'default_book',
                              personId: _selectedPersonId!,
                              amount: amt,
                              isOwedToMe: widget.isOwedToMe,
                              note: _noteController.text,
                            );
                            if (mounted) context.pop();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.genericErrorPrefix}: $e')));
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
        }
      ),
    );
  }
}
