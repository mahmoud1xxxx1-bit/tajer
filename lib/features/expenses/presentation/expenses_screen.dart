import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';
import 'package:intl/intl.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text_64, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.text_65, style: TextStyle(fontFamily: 'Tajawal')));
          }
          
          final totalExpenses = expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
          
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: GlassCard(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.text_66,
                        style: TextStyle(fontSize: 18, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$totalExpenses',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.money_off, color: Colors.orange, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat('yyyy/MM/dd').format(expense.date),
                                            style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey[700], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      if (expense.category != null && expense.category!.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.category_outlined, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              expense.category!,
                                              style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey[700], fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      if (expense.creatorName != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.person_pin, size: 14, color: Colors.purple.withOpacity(0.7)),
                                            const SizedBox(width: 4),
                                            Text(
                                              expense.creatorName!,
                                              style: TextStyle(fontFamily: 'Tajawal', color: Colors.purple.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '-${expense.amount}',
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('حذف المصروف', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                        content: const Text('هل أنت متأكد من حذف هذا المصروف؟', style: TextStyle(fontFamily: 'Tajawal')),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              ref.read(expenseRepositoryProvider)?.deleteExpense(expense.id);
                                              Navigator.pop(context);
                                            },
                                            child: const Text('حذف', style: TextStyle(color: Colors.red, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final canAdd = await GuestLimitService.canAddExpense(context, ref);
          if (!canAdd) return;
          if (context.mounted) _showAddExpenseDialog(context, ref);
        },
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.text_67, style: TextStyle(fontFamily: 'Tajawal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text_68),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text_69),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text_70),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.text_43),
            ),
            ElevatedButton(
              onPressed: () {
                final user = ref.read(authRepositoryProvider).currentUser;
                if (user == null) return;
                
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.text_71)),
                  );
                  return;
                }
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.text_72)),
                  );
                  return;
                }

                final appUser = ref.read(appUserProvider).value;
                final expense = Expense(
                  id: const Uuid().v4(),
                  merchantId: user.uid,
                  title: titleController.text.trim(),
                  amount: amount,
                  category: categoryController.text.trim(),
                  date: DateTime.now(),
                  creatorId: appUser?.id,
                  creatorName: appUser?.name ?? 'غير معروف',
                  createdAt: DateTime.now(),
                );

                ref.read(expenseRepositoryProvider)?.addExpense(expense);
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.text_44),
            ),
          ],
        );
      },
    );
  }
}

