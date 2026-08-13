import 'package:tajer/l10n/app_localizations.dart';
import 'dart:async';
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
import '../../shifts/data/shift_repository.dart';
import 'package:tajer/core/utils/app_snackbar.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final appUser = ref.watch(appUserProvider).value;
    final canManageExpenses = appUser?.hasPermission('can_manage_expenses') ?? false;
    
    final repository = ref.watch(expenseRepositoryProvider);
    final query = repository?.queryExpenses();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text64, style: const TextStyle(fontFamily: 'Tajawal')),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isAr
                        ? '💡 دليل المصروفات: سجل هنا كافة مصاريف تشغيل مشروعك (مثل: إيجار، رواتب، فواتير كهرباء أو وقود). يقوم التطبيق بخصمها من إجمالي المبيعات لحساب صافي أرباحك الحقيقي بدقة.'
                        : '💡 Expenses Guide: Log all operational expenses here (e.g., rent, salaries, utility bills). The app accurately deducts them from gross sales to calculate true net profit.',
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: query == null
                ? const Center(child: CircularProgressIndicator())
                : FirestoreListView<Expense>(
                    query: query,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    emptyBuilder: (context) => Center(
                      child: Text(AppLocalizations.of(context)!.text65, style: const TextStyle(fontFamily: 'Tajawal')),
                    ),
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text('خطأ: $error', style: const TextStyle(fontFamily: 'Tajawal')),
                    ),
                    itemBuilder: (context, doc) {
                      final expense = doc.data();
                      if (expense.isSupplierPayment) return const SizedBox.shrink(); // Hide supplier payments from general expenses view
                      
                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
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
                                      if (expense.creatorName != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.person_outline, size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              expense.creatorName!,
                                              style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey[700], fontSize: 11),
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
                                  '-${expense.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: expense.isCancelled ? Colors.grey : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal',
                                    decoration: expense.isCancelled ? TextDecoration.lineThrough : null,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    expense.category ?? '',
                                    style: const TextStyle(color: Colors.blue, fontSize: 10, fontFamily: 'Tajawal'),
                                  ),
                                ),
                              ],
                            ),
                            if (canManageExpenses && !expense.isCancelled) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: AppLocalizations.of(context)!.text74,
                                onPressed: () async {
                                  final currentAppUser = ref.read(appUserProvider).value;
                                  if (currentAppUser != null) {
                                    final correctPin = await PinService.getDeletePin(currentAppUser);
                                    if (correctPin != null && correctPin.isNotEmpty) {
                                      if (context.mounted) {
                                        final success = await PinConfirmationDialog.show(
                                          context, 
                                          correctPin,
                                          title: AppLocalizations.of(context)!.text74,
                                          warning: AppLocalizations.of(context)!.text75,
                                        );
                                        if (success == true) {
                                          if (context.mounted) _cancelExpense(context, ref, expense);
                                        }
                                      }
                                    } else {
                                      if (context.mounted) _showCancelConfirmationDialog(context, ref, expense);
                                    }
                                  } else {
                                    if (context.mounted) _showCancelConfirmationDialog(context, ref, expense);
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: canManageExpenses
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () async {
                final canAdd = await GuestLimitService.canAddExpense(context, ref);
                if (!canAdd) return;
                if (context.mounted) _showAddExpenseDialog(context, ref);
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showCancelConfirmationDialog(BuildContext context, WidgetRef ref, Expense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.text74, style: const TextStyle(fontFamily: 'Tajawal')),
        content: Text(AppLocalizations.of(context)!.text75, style: const TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.text43),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelExpense(context, ref, expense);
            },
            child: Text(AppLocalizations.of(context)!.text74),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelExpense(BuildContext context, WidgetRef ref, Expense expense) async {
    try {
      await ref.read(expenseRepositoryProvider)?.cancelExpense(expense);
      if (context.mounted) {
        AppSnackbar.showSuccess(context, 'تم إلغاء المصروف بنجاح');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, e.toString());
      }
    }
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    String paymentMethod = 'cash';
    bool isFromShiftDrawer = true;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.text67, style: const TextStyle(fontFamily: 'Tajawal')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text68),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text69),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text70),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('طريقة الدفع', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('كاش'),
                            selected: paymentMethod == 'cash',
                            onSelected: isLoading
                                ? null
                                : (selected) {
                                    if (selected) setState(() => paymentMethod = 'cash');
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('شبكة/حوالة'),
                            selected: paymentMethod == 'network',
                            onSelected: isLoading
                                ? null
                                : (selected) {
                                    if (selected) setState(() => paymentMethod = 'network');
                                  },
                          ),
                        ),
                      ],
                    ),
                    if (paymentMethod == 'cash') ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: isFromShiftDrawer ? Colors.red.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isFromShiftDrawer
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : Colors.grey.withValues(alpha: 0.3)),
                        ),
                        child: CheckboxListTile(
                          title: const Text('خصم من درج الوردية الحالي؟', style: TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                          subtitle: Text(
                            isFromShiftDrawer ? 'سيتم تقليل إجمالي الكاش في الوردية' : 'لن يتم تغيير كاش الوردية',
                            style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                color: isFromShiftDrawer ? Colors.red : Colors.grey),
                          ),
                          value: isFromShiftDrawer,
                          onChanged: isLoading
                              ? null
                              : (val) {
                                  setState(() => isFromShiftDrawer = val ?? true);
                                },
                          activeColor: Colors.red,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!isLoading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.text43),
                  ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
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

                          setState(() => isLoading = true);

                          final appUser = ref.read(appUserProvider).value;
                          final expense = Expense(
                            id: const Uuid().v4(),
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

                          try {
                            await ref.read(expenseRepositoryProvider)?.addExpense(expense).timeout(const Duration(seconds: 1));
                          } catch (e) {
                            if (e is! TimeoutException && !e.toString().contains('TimeoutException')) {
                              if (context.mounted) {
                                AppSnackbar.showError(context, e.toString());
                                setState(() => isLoading = false);
                              }
                              return;
                            }
                          }

                          if (context.mounted) Navigator.pop(context);
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(AppLocalizations.of(context)!.text44),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
