import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/expense_repository.dart';
import '../../../core/services/pin_service.dart';
import '../../../core/services/activity_logger.dart';
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
          final expenses = allExpenses.where((e) => !e.isSupplierPayment).toList();
          
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
                        '${expenses.where((e) => !e.isCancelled).fold<double>(0, (sum, expense) => sum + expense.amount)}',
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
        heroTag: null,
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
    String paymentMethod = 'cash';
    bool isFromShiftDrawer = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('طريقة الدفع', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text('كاش'),
                        selected: paymentMethod == 'cash',
                        onSelected: (selected) {
                          if (selected) setState(() => paymentMethod = 'cash');
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Text('شبكة/حوالة'),
                        selected: paymentMethod == 'network',
                        onSelected: (selected) {
                          if (selected) setState(() => paymentMethod = 'network');
                        },
                      ),
                    ),
                  ],
                ),
                if (paymentMethod == 'cash') ...[
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: isFromShiftDrawer ? Colors.red.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isFromShiftDrawer ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                    ),
                    child: CheckboxListTile(
                      title: Text('خصم من درج الوردية الحالي؟', style: TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                      subtitle: Text(
                        isFromShiftDrawer ? 'سيتم تقليل إجمالي الكاش في الوردية' : 'لن يتم تغيير كاش الوردية',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: isFromShiftDrawer ? Colors.red : Colors.grey),
                      ),
                      value: isFromShiftDrawer,
                      onChanged: (val) {
                        setState(() => isFromShiftDrawer = val ?? true);
                      },
                      activeColor: Colors.red,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
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
                  paymentMethod: paymentMethod,
                  date: DateTime.now(),
                  creatorId: appUser?.id,
                  creatorName: appUser?.name ?? 'غير معروف',
                  createdAt: DateTime.now(),
                  isFromShiftDrawer: isFromShiftDrawer,
                );

                ref.read(expenseRepositoryProvider)?.addExpense(expense);
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.text44),
            ),
          ],
        );
        });
      },
    );
  }
}

Widget _buildExpenseGroup(BuildContext context, WidgetRef ref, String title, List<Expense> groupExpenses, {bool initiallyExpanded = false, String? subtitle}) {
  final totalAmount = groupExpenses.where((e) => !e.isCancelled).fold<double>(0, (sum, e) => sum + e.amount);
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontFamily: 'Tajawal', 
                          fontSize: 14,
                          decoration: expense.isCancelled ? TextDecoration.lineThrough : null,
                          color: expense.isCancelled ? Colors.grey : null,
                        ),
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
                          if (expense.paymentMethod == 'network')
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.credit_card, size: 10, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text('شبكة', style: TextStyle(fontFamily: 'Tajawal', color: Colors.blue, fontSize: 10)),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: expense.isFromShiftDrawer ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.money, size: 10, color: expense.isFromShiftDrawer ? Colors.red : Colors.green),
                                  SizedBox(width: 4),
                                  Text(expense.isFromShiftDrawer ? 'كاش (من الدرج)' : 'كاش (من الخارج)', style: TextStyle(fontFamily: 'Tajawal', color: expense.isFromShiftDrawer ? Colors.red : Colors.green, fontSize: 10)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (expense.isCancelled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('ملغي', style: TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                      ),
                    Text(
                      '-${expense.amount}',
                      style: TextStyle(
                        color: expense.isCancelled ? Colors.grey : Colors.red, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 14,
                        decoration: expense.isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (canManageExpenses && !expense.isCancelled) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final appUser = ref.read(appUserProvider).value;
                          if (appUser != null) {
                            final pin = await PinService.getDeletePin(appUser);
                            if (pin != null) {
                              if (!context.mounted) return;
                              final isAr = Localizations.localeOf(context).languageCode == 'ar';
                              
                              final now = DateTime.now();
                              final expenseDate = expense.date;
                              if (now.year != expenseDate.year || now.month != expenseDate.month || now.day != expenseDate.day) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isAr ? 'أمان: لا يمكن إلغاء مصروف قديم بعد إغلاق الوردية.' : 'Security: Cannot cancel an expense from a previous closed shift.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              final success = await PinConfirmationDialog.show(
                                context, 
                                pin,
                                title: isAr ? 'تأكيد: إلغاء مصروف' : 'Warning: Cancel Expense',
                                warning: isAr 
                                  ? 'تحذير: سيتم شطب المصروف من تقارير الأرباح والخسائر، وإعادة مبلغه إلى الدرج إذا كان قد سُحب منه.'
                                  : 'Warning: This expense will be removed from P&L reports and its amount returned to the drawer if applicable.',
                              );
                              if (!success) return;
                            }
                          }
                          final cancelledExpense = expense.copyWith(isCancelled: true);
                          ref.read(expenseRepositoryProvider)?.updateExpense(cancelledExpense);
                          ActivityLogger.log(
                            user: appUser,
                            actionType: 'Cancel Expense|إلغاء مصروف',
                            description: 'Cancelled expense "${expense.title}" for ${expense.amount}|تم إلغاء المصروف "${expense.title}" بقيمة ${expense.amount}',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.cancel_outlined, color: Colors.orange, size: 16),
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
