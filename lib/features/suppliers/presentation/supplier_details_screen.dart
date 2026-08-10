import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../../core/services/activity_logger.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/presentation/branch_context.dart';
import '../../expenses/data/expense_repository.dart';
import '../../shifts/data/shift_repository.dart';
import '../data/supplier_repository.dart';
import '../data/supplier_transaction_repository.dart';
import '../domain/supplier.dart';
import '../domain/supplier_transaction.dart';
import 'purchase_invoice_screen.dart';

class SupplierDetailsScreen extends ConsumerWidget {
  final Supplier supplier;

  const SupplierDetailsScreen({super.key, required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers =
        ref.watch(suppliersStreamProvider).value ?? const <Supplier>[];
    final currentSupplier = suppliers.firstWhere(
      (s) => s.id == supplier.id,
      orElse: () => supplier,
    );
    final transactionsAsync =
        ref.watch(supplierTransactionsStreamProvider(supplier.id));
    final currentCurrency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final activeBranchId = ref.watch(selectedBranchIdProvider);
    final canManageInventory =
        appUser?.hasPermission('can_manage_inventory') ?? false;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(currentSupplier.name,
            style: const TextStyle(fontFamily: 'Tajawal')),
        actions: [
          if (canManageInventory)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () =>
                  _showEditSupplierDialog(context, ref, currentSupplier),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (activeBranchId != null ? (currentSupplier.branchDebts[activeBranchId] ?? 0) : currentSupplier.totalDebt) > 0
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        (activeBranchId != null ? (currentSupplier.branchDebts[activeBranchId] ?? 0) : currentSupplier.totalDebt) > 0
                            ? Icons.money_off
                            : Icons.check_circle,
                        color: (activeBranchId != null ? (currentSupplier.branchDebts[activeBranchId] ?? 0) : currentSupplier.totalDebt) > 0
                            ? Colors.red
                            : Colors.green,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? 'الديون المستحقة' : 'Outstanding Debt',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontFamily: 'Tajawal',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${activeBranchId != null ? (currentSupplier.branchDebts[activeBranchId] ?? 0) : currentSupplier.totalDebt} ${currentCurrency.code}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: (activeBranchId != null ? (currentSupplier.branchDebts[activeBranchId] ?? 0) : currentSupplier.totalDebt) > 0
                                  ? Colors.red
                                  : Colors.green,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(isAr ? 'خطأ: $e' : 'Error: $e')),
              data: (transactions) {
                final activeTransactions = activeBranchId == null
                    ? transactions
                    : transactions.where((t) => t.branchId == activeBranchId).toList();

                if (activeTransactions.isEmpty) {
                  return Center(
                    child: Text(
                      isAr
                          ? 'لا يوجد سجل حركات لهذا المورد'
                          : 'No transactions for this supplier',
                      style: const TextStyle(fontFamily: 'Tajawal'),
                    ),
                  );
                }

                final grouped = <String, List<SupplierTransaction>>{};
                for (final transaction in activeTransactions) {
                  final key = DateFormat('yyyy-MM-dd').format(transaction.date);
                  grouped
                      .putIfAbsent(key, () => <SupplierTransaction>[])
                      .add(transaction);
                }
                final dates = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  itemCount: dates.length,
                  itemBuilder: (context, index) {
                    final date = dates[index];
                    return GlassCard(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ExpansionTile(
                        initiallyExpanded: index == 0,
                        title: Text(
                          date,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: grouped[date]!.map((transaction) {
                          final isPayment = transaction.type == 'payment';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPayment
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              child: Icon(
                                isPayment
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              transaction.description,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                decoration: transaction.isCancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: transaction.isCancelled
                                    ? Colors.grey
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              '${DateFormat('hh:mm a').format(transaction.date)}${transaction.isCancelled ? (isAr ? ' (ملغي)' : ' (Cancelled)') : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    transaction.isCancelled ? Colors.red : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!transaction.isCancelled &&
                                    canManageInventory)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: isAr
                                        ? 'إلغاء العملية'
                                        : 'Cancel transaction',
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      color: Colors.orange,
                                      size: 18,
                                    ),
                                    onPressed: () => _cancelTransaction(
                                      context,
                                      ref,
                                      currentSupplier,
                                      transaction,
                                    ),
                                  ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isPayment ? '-' : '+'}${transaction.amount} ${currentCurrency.code}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Tajawal',
                                        decoration: transaction.isCancelled
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: transaction.isCancelled
                                            ? Colors.grey
                                            : (isPayment
                                                ? Colors.green
                                                : Colors.red),
                                      ),
                                    ),
                                    if (isPayment &&
                                        transaction.paymentMethod != null)
                                      Text(
                                        transaction.paymentMethod == 'network'
                                            ? (isAr
                                                ? 'شبكة/حوالة'
                                                : 'Card/Transfer')
                                            : (isAr ? 'كاش' : 'Cash'),
                                        style: const TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: canManageInventory
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _showAddDebtDialog(context, ref, currentSupplier),
                            icon: const Icon(Icons.add),
                            label: Text(
                              isAr ? 'إضافة دين' : 'Add Debt',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.error,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onError,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showPaySupplierDebtDialog(
                                context, ref, currentSupplier),
                            icon: const Icon(Icons.payment),
                            label: Text(
                              isAr ? 'تسديد دفعة' : 'Pay Debt',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PurchaseInvoiceScreen(
                                supplier: currentSupplier,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long),
                        label: Text(
                          isAr ? 'فاتورة شراء' : 'Purchase Invoice',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _cancelTransaction(
    BuildContext context,
    WidgetRef ref,
    Supplier currentSupplier,
    SupplierTransaction transaction,
  ) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final appUser = ref.read(appUserProvider).value;
    if (appUser != null) {
      final confirmed = await PinConfirmationDialog.requirePinOrSetup(
        context,
        appUser,
        title: isAr ? 'تحذير: إلغاء العملية' : 'Warning: Cancel Transaction',
        warning: isAr
            ? 'سيتم إلغاء العملية وإعادة حساب مديونية المورد.'
            : 'The transaction will be cancelled and supplier debt recalculated.',
      );
      if (!confirmed) return;
    }

    try {
      final repository = ref.read(supplierRepositoryProvider);
      if (repository == null) return;

      if (transaction.type == 'payment' &&
          transaction.expenseId != null &&
          transaction.expenseId!.isNotEmpty) {
        await repository.reverseSupplierPayment(
          supplierId: currentSupplier.id,
          transactionId: transaction.id,
        );
      } else if (transaction.type == 'payment') {
        // Legacy v107 payments did not persist an exact expenseId. Preserve
        // the validated compatibility path only for those historical records.
        final expenses = ref.read(expensesStreamProvider).value;
        if (expenses != null) {
          final matching = expenses.where(
            (expense) =>
                expense.isSupplierPayment &&
                expense.amount == transaction.amount &&
                expense.title.contains(currentSupplier.name) &&
                !expense.isCancelled &&
                expense.date.difference(transaction.date).inMinutes.abs() < 5,
          );
          if (matching.isNotEmpty) {
            await ref
                .read(expenseRepositoryProvider)
                ?.cancelExpense(matching.first);
          }
        }
        await ref
            .read(supplierTransactionRepositoryProvider)
            ?.updateTransaction(
              transaction.copyWith(isCancelled: true),
            );
        await repository.updateSupplier(
          currentSupplier.copyWith(
            totalDebt: currentSupplier.totalDebt + transaction.amount,
          ),
        );
      } else {
        await ref
            .read(supplierTransactionRepositoryProvider)
            ?.updateTransaction(
              transaction.copyWith(isCancelled: true),
            );
        final newDebt = currentSupplier.totalDebt - transaction.amount;
        await repository.updateSupplier(
          currentSupplier.copyWith(totalDebt: newDebt < 0 ? 0 : newDebt),
        );
      }

      ActivityLogger.log(
        user: appUser,
        actionType: 'Cancel Supplier Transaction|إلغاء عملية مورد',
        description:
            'Cancelled ${transaction.type} of ${transaction.amount} for supplier ${currentSupplier.name}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddDebtDialog(
    BuildContext context,
    WidgetRef ref,
    Supplier currentSupplier,
  ) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final amountController = TextEditingController();
    final descriptionController = TextEditingController(
      text: isAr ? 'إضافة مديونية جديدة' : 'New supplier debt',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isAr ? 'إضافة دين جديد للمورد' : 'Add Supplier Debt',
          style: const TextStyle(
              fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isAr ? 'المبلغ' : 'Amount',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: isAr ? 'البيان / التفاصيل' : 'Description / Details',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim()) ?? 0;
              if (amount <= 0) return;
              final user = ref.read(appUserProvider).value;
              final merchantId =
                  user == null ? '' : currentEffectiveMerchantId(user);
              final branchId = ref.read(selectedBranchIdProvider);

              final updatedSupplier = currentSupplier.copyWith(
                totalDebt: currentSupplier.totalDebt + amount,
              );
              await ref
                  .read(supplierRepositoryProvider)
                  ?.updateSupplier(updatedSupplier);

              await ref
                  .read(supplierTransactionRepositoryProvider)
                  ?.addTransaction(
                    SupplierTransaction(
                      id: const Uuid().v4(),
                      supplierId: currentSupplier.id,
                      merchantId: merchantId,
                      branchId: branchId,
                      amount: amount,
                      type: 'debt_addition',
                      description: descriptionController.text.trim().isEmpty
                          ? (isAr ? 'إضافة دين' : 'Debt added')
                          : descriptionController.text.trim(),
                      date: DateTime.now(),
                      createdAt: DateTime.now(),
                    ),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(isAr ? 'إضافة' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _showPaySupplierDebtDialog(
    BuildContext context,
    WidgetRef ref,
    Supplier currentSupplier,
  ) {
    final activeBranchId = ref.read(selectedBranchIdProvider);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final amountController = TextEditingController(
      text: (activeBranchId != null ? (currentSupplier.branchDebts[activeBranchId] ?? 0.0) : currentSupplier.totalDebt).toString(),
    );
    String paymentMethod = 'cash';
    bool isFromShiftDrawer = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isAr ? 'تسديد ديون المورد' : 'Pay Supplier Debt',
            style: const TextStyle(
                fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isAr ? 'إجمالي دين المورد' : 'Supplier total debt'}: ${activeBranchId != null ? (currentSupplier.branchDebts[activeBranchId] ?? 0.0) : currentSupplier.totalDebt}',
                style: const TextStyle(
                    fontFamily: 'Tajawal', fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isAr
                      ? 'المبلغ المدفوع للمورد'
                      : 'Amount paid to supplier',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isAr ? 'طريقة الدفع:' : 'Payment method:',
                style: const TextStyle(
                    fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(isAr ? 'كاش' : 'Cash'),
                      selected: paymentMethod == 'cash',
                      onSelected: (value) {
                        if (value) setState(() => paymentMethod = 'cash');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(isAr ? 'شبكة/حوالة' : 'Card/Transfer'),
                      selected: paymentMethod == 'network',
                      onSelected: (value) {
                        if (value) setState(() => paymentMethod = 'network');
                      },
                    ),
                  ),
                ],
              ),
              if (paymentMethod == 'cash') ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isAr
                        ? 'خصم من درج الوردية الحالي؟'
                        : 'Deduct from current shift drawer?',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14),
                  ),
                  subtitle: Text(
                    isFromShiftDrawer
                        ? (isAr
                            ? 'سيتم تقليل الكاش في الوردية'
                            : 'Shift cash will be reduced')
                        : (isAr
                            ? 'لن يتم تغيير كاش الوردية'
                            : 'Shift cash will not change'),
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                  ),
                  value: isFromShiftDrawer,
                  onChanged: (value) => setState(
                    () => isFromShiftDrawer = value ?? true,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isAr ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final paid = double.tryParse(amountController.text.trim()) ?? 0;
                if (paid <= 0) return;
                final maxDebt = activeBranchId != null ? (currentSupplier.branchDebts[activeBranchId] ?? 0.0) : currentSupplier.totalDebt;
                if (paid > maxDebt) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isAr
                            ? 'مبلغ السداد لا يمكن أن يتجاوز دين المورد المستحق في هذا الفرع.'
                            : 'Payment cannot exceed the supplier outstanding debt in this branch.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final user = ref.read(appUserProvider).value;
                final merchantId =
                    user == null ? '' : currentEffectiveMerchantId(user);
                final branchId = ref.read(selectedBranchIdProvider);
                final currentShift =
                    ref.read(currentShiftProvider(merchantId)).value;
                final needsShift = paymentMethod == 'cash' && isFromShiftDrawer;

                if (needsShift && currentShift == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isAr
                            ? 'لا يمكن خصم سداد المورد من الدرج بدون وردية مفتوحة في هذا الفرع.'
                            : 'Open a shift in this branch before deducting supplier payment from the drawer.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await ref
                      .read(supplierRepositoryProvider)
                      ?.settleSupplierDebt(
                        supplierId: currentSupplier.id,
                        supplierName: currentSupplier.name,
                        amountPaid: paid,
                        paymentMethod: paymentMethod,
                        isFromShiftDrawer: isFromShiftDrawer,
                        branchId: branchId,
                        transactionId: const Uuid().v4(),
                        expenseId: const Uuid().v4(),
                        occurredAt: DateTime.now(),
                        shiftId: needsShift ? currentShift!.id : null,
                        creatorId: user?.id,
                        creatorName: user?.name,
                      );

                  ActivityLogger.log(
                    user: user,
                    actionType: 'Supplier Debt Payment|سداد دين مورد',
                    description:
                        'Paid $paid to supplier ${currentSupplier.name} in branch $branchId|تم سداد $paid للمورد ${currentSupplier.name} في الفرع $branchId',
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceAll('Exception: ', ''),
                          style: const TextStyle(fontFamily: 'Tajawal'),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(isAr ? 'سداد' : 'Pay'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSupplierDialog(
    BuildContext context,
    WidgetRef ref,
    Supplier currentSupplier,
  ) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final nameController = TextEditingController(text: currentSupplier.name);
    final phoneController = TextEditingController(text: currentSupplier.phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isAr ? 'تعديل بيانات المورد' : 'Edit Supplier',
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: isAr ? 'اسم المورد' : 'Supplier name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: isAr ? 'رقم الهاتف' : 'Phone number',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final appUser = ref.read(appUserProvider).value;
              if (appUser != null) {
                final confirmed = await PinConfirmationDialog.requirePinOrSetup(
                  context,
                  appUser,
                  title: currentSupplier.isActive
                      ? (isAr
                          ? 'تأكيد: إلغاء المورد'
                          : 'Warning: Cancel Supplier')
                      : (isAr
                          ? 'تأكيد: استعادة المورد'
                          : 'Confirm: Restore Supplier'),
                  warning: currentSupplier.isActive
                      ? (isAr
                          ? 'سيتم شطب المورد من القائمة. لن يتم مسح بياناته السابقة.'
                          : 'Supplier will be crossed out. Historical data will remain.')
                      : (isAr
                          ? 'سيتم استعادة المورد وإزالة الشطب.'
                          : 'Supplier will be restored.'),
                );
                if (!confirmed) return;
              }
              await ref.read(supplierRepositoryProvider)?.updateSupplier(
                    currentSupplier.copyWith(
                        isActive: !currentSupplier.isActive),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              currentSupplier.isActive
                  ? (isAr ? 'إلغاء المورد' : 'Cancel Supplier')
                  : (isAr ? 'استعادة المورد' : 'Restore Supplier'),
              style: TextStyle(
                color: currentSupplier.isActive ? Colors.red : Colors.green,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await ref.read(supplierRepositoryProvider)?.updateSupplier(
                    currentSupplier.copyWith(
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                    ),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(isAr ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }
}
