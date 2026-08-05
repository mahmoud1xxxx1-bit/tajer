import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/expense_repository.dart';
import '../../../core/services/pin_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../domain/expense.dart';
import 'package:intl/intl.dart';
import '../../authentication/domain/app_user.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final appUser = ref.watch(appUserProvider).value;
    final canManageExpenses = appUser?.hasPermission('can_manage_expenses') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text64, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: expensesAsync.when(
        data: (allExpenses) {
          final expenses = allExpenses.where((e) => e.category != 'سداد ديون موردين').toList();
          
          if (expenses.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.text65, style: TextStyle(fontFamily: 'Tajawal')));
          }
          
          final todayExpenses = <Expense>[];
          final weekExpenses = <Expense>[];
          final monthExpenses = <Expense>[];
          final yearExpenses = <Expense>[];
          final olderExpenses = <Expense>[];

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final sevenDaysAgo = today.subtract(const Duration(days: 7));
          final thirtyDaysAgo = today.subtract(const Duration(days: 30));

          for (final expense in expenses) {
            final date = expense.date;
            final expenseDay = DateTime(date.year, date.month, date.day);

            if (expenseDay.isAtSameMomentAs(today)) {
              todayExpenses.add(expense);
            } else if (expenseDay.isAfter(sevenDaysAgo) || expenseDay.isAtSameMomentAs(sevenDaysAgo)) {
              weekExpenses.add(expense);
            } else if (expenseDay.isAfter(thirtyDaysAgo) || expenseDay.isAtSameMomentAs(thirtyDaysAgo)) {
              monthExpenses.add(expense);
            } else if (date.year == now.year) {
              yearExpenses.add(expense);
            } else {
              olderExpenses.add(expense);
            }
          }

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '💡 دليل المصروفات: سجل هنا كافة مصاريف تشغيل مشروعك (مثل: إيجار، رواتب، فواتير كهرباء أو وقود). يقوم التطبيق بخصمها من إجمالي المبيعات لحساب صافي أرباحك الحقيقي بدقة.',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: GlassCard(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.text66,
                        style: TextStyle(fontSize: 18, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${expenses.fold<double>(0, (sum, expense) => sum + expense.amount)}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    if (todayExpenses.isNotEmpty)
                      _buildExpenseGroup(context, ref, 'مصروفات اليوم', todayExpenses, initiallyExpanded: true),
                    if (weekExpenses.isNotEmpty)
                      _buildExpenseGroup(context, ref, 'هذا الأسبوع', weekExpenses, 
                          subtitle: '${DateFormat('yyyy/MM/dd').format(sevenDaysAgo)} - ${DateFormat('yyyy/MM/dd').format(today.subtract(const Duration(days: 1)))}'),
                    if (monthExpenses.isNotEmpty)
                      _buildExpenseGroup(context, ref, 'هذا الشهر', monthExpenses,
                          subtitle: '${DateFormat('yyyy/MM/dd').format(thirtyDaysAgo)} - ${DateFormat('yyyy/MM/dd').format(sevenDaysAgo.subtract(const Duration(days: 1)))}'),
                    if (yearExpenses.isNotEmpty)
                      _buildExpenseGroup(context, ref, 'هذا العام (${now.year})', yearExpenses),
                    if (olderExpenses.isNotEmpty)
                      _buildExpenseGroup(context, ref, 'أقدم', olderExpenses),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: canManageExpenses ? FloatingActionButton(
        onPressed: () async {
          final canAdd = await GuestLimitService.canAddExpense(context, ref);
          if (!canAdd) return;
          if (context.mounted) _showAddExpenseDialog(context, ref);
        },
        child: Icon(Icons.add),
      ) : null,
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
          title: Text(AppLocalizations.of(context)!.text67, style: TextStyle(fontFamily: 'Tajawal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text68),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text69),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text70),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.text43),
            ),
            ElevatedButton(
              onPressed: () {
                final user = ref.read(authRepositoryProvider).currentUser;
                if (user == null) return;
                
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.text71)),
                  );
                  return;
                }
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.text72)),
                  );
                  return;
                }

                final appUser = ref.read(appUserProvider).value;
                final expense = Expense(
                  id: Uuid().v4(),
                  merchantId: ref.read(appUserProvider).value?.merchantId ?? user.uid,
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
              child: Text(AppLocalizations.of(context)!.text44),
            ),
          ],
        );
      },
    );
  }
}

Widget _buildExpenseGroup(BuildContext context, WidgetRef ref, String title, List<Expense> groupExpenses, {bool initiallyExpanded = false, String? subtitle}) {
  final totalAmount = groupExpenses.fold<double>(0, (sum, e) => sum + e.amount);
  final appUser = ref.watch(appUserProvider).value;
  final canManageExpenses = appUser?.hasPermission('can_manage_expenses') ?? false;
  
  return GlassCard(
    margin: EdgeInsets.only(bottom: 16),
    padding: EdgeInsets.zero,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        iconColor: Theme.of(context).colorScheme.primary,
        collapsedIconColor: Colors.grey,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Tajawal'),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '-${totalAmount.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 14),
              ),
            ),
          ],
        ),
        children: groupExpenses.map((expense) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.money_off, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('yyyy/MM/dd').format(expense.date),
                                style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey[700], fontSize: 11),
                              ),
                            ],
                          ),
                          if (expense.category != null && expense.category!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.category_outlined, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  expense.category!,
                                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey[700], fontSize: 11),
                                ),
                              ],
                            ),
                          if (expense.creatorName != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_pin, size: 12, color: Colors.purple.withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  expense.creatorName!,
                                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.purple.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '-${expense.amount}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (canManageExpenses) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final appUser = ref.read(appUserProvider).value;
                          if (appUser != null) {
                            final pin = await PinService.getDeletePin(appUser);
                            if (pin != null) {
                              if (!context.mounted) return;
                              final success = await PinConfirmationDialog.show(
                                context, 
                                pin,
                                title: 'تحذير: حذف مصروف',
                                warning: 'إلغاء المصروف سيؤدي إلى مسحه من التقارير المالية. هل أنت متأكد من الحذف؟',
                              );
                              if (!success) return;
                            }
                          }
                          ref.read(expenseRepositoryProvider)?.deleteExpense(expense.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ),
  );
}
