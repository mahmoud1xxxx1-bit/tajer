import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/pin_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../authentication/domain/app_user.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/supplier_repository.dart';
import 'package:tajer/core/utils/app_snackbar.dart';
import '../data/supplier_transaction_repository.dart';
import '../domain/supplier.dart';
import '../domain/supplier_transaction.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../../core/services/activity_logger.dart';

class SupplierDetailsScreen extends ConsumerWidget {
  final Supplier supplier;

  const SupplierDetailsScreen({super.key, required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the specific supplier to get real-time totalDebt updates
    final suppliers = ref.watch(suppliersStreamProvider).value ?? [];
    final currentSupplier = suppliers.firstWhere((s) => s.id == supplier.id, orElse: () => supplier);
    
    final transactionsAsync = ref.watch(supplierTransactionsStreamProvider(supplier.id));
    final currentCurrency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final canManageInventory = appUser?.hasPermission('can_manage_inventory') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentSupplier.name, style: const TextStyle(fontFamily: 'Tajawal')),
        actions: [
          if (canManageInventory)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditSupplierDialog(context, ref, currentSupplier),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: currentSupplier.totalDebt > 0 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        currentSupplier.totalDebt > 0 ? Icons.money_off : Icons.check_circle,
                        color: currentSupplier.totalDebt > 0 ? Colors.red : Colors.green,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الديون المستحقة',
                            style: TextStyle(fontSize: 14, color: Colors.grey[700], fontFamily: 'Tajawal'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${currentSupplier.totalDebt} ${currentCurrency.code}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: currentSupplier.totalDebt > 0 ? Colors.red : Colors.green,
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
          
          // Transactions List
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(child: Text('لا يوجد سجل حركات لهذا المورد', style: TextStyle(fontFamily: 'Tajawal')));
                }

                // Group by Date (ignoring time)
                final grouped = <String, List<SupplierTransaction>>{};
                for (var t in transactions) {
                  final dateStr = DateFormat('yyyy-MM-dd').format(t.date);
                  if (!grouped.containsKey(dateStr)) {
                    grouped[dateStr] = [];
                  }
                  grouped[dateStr]!.add(t);
                }

                final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final dateStr = sortedDates[index];
                    final dayTransactions = grouped[dateStr]!;
                    
                    return GlassCard(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ExpansionTile(
                        initiallyExpanded: index == 0,
                        title: Text(
                          dateStr,
                          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                        ),
                        children: dayTransactions.map((t) {
                          final isPayment = t.type == 'payment';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPayment ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              child: Icon(
                                isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              t.description, 
                              style: TextStyle(
                                fontFamily: 'Tajawal', 
                                fontSize: 14,
                                decoration: t.isCancelled ? TextDecoration.lineThrough : null,
                                color: t.isCancelled ? Colors.grey : null,
                              )
                            ),
                            subtitle: Text(
                              DateFormat('hh:mm a').format(t.date) + (t.isCancelled ? ' (ملغي)' : ''), 
                              style: TextStyle(
                                fontSize: 12,
                                color: t.isCancelled ? Colors.red : null,
                              )
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!t.isCancelled && appUser?.hasPermission('can_manage_inventory') == true)
                                      InkWell(
                                        onTap: () async {
                                          final appUser = ref.read(appUserProvider).value;
                                          if (appUser != null) {
                                            final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                            final success = await PinConfirmationDialog.requirePinOrSetup(
                                              context, 
                                              appUser,
                                              title: isAr ? 'تحذير: إلغاء العملية' : 'Warning: Cancel Transaction',
                                              warning: isAr 
                                                ? 'سيتم إلغاء العملية وإعادة حساب المديونية. ' + (isPayment ? '(تنبيه: ستحتاج لإلغاء المصروف من شاشة المصروفات أيضاً)' : '')
                                                : 'Transaction will be cancelled and debt recalculated.',
                                            );
                                            if (!success) return;
                                          }
                                          if (isPayment) {
                                            final expensesOpt = ref.read(expensesStreamProvider).value;
                                            if (expensesOpt != null) {
                                              final matchingExpenses = expensesOpt.where((e) => 
                                                e.isSupplierPayment && 
                                                e.amount == t.amount && 
                                                e.title.contains(supplier.name) &&
                                                !e.isCancelled &&
                                                e.date.difference(t.date).inMinutes.abs() < 5
                                              );
                                              if (matchingExpenses.isNotEmpty) {
                                                try {
                                                  await ref.read(expenseRepositoryProvider)?.cancelExpense(matchingExpenses.first);
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''), style: const TextStyle(fontFamily: 'Tajawal')), backgroundColor: Colors.red));
                                                  }
                                                  return; // Stop the whole reversal if expense is in a closed shift
                                                }
                                              }
                                            }
                                          }
                                          
                                          final updatedTransaction = t.copyWith(isCancelled: true);
                                          ref.read(supplierTransactionRepositoryProvider)?.updateTransaction(updatedTransaction);
                                          
                                          // Update supplier debt
                                          final newDebt = currentSupplier.totalDebt + (isPayment ? t.amount : -t.amount);
                                          ref.read(supplierRepositoryProvider)?.updateSupplier(currentSupplier.copyWith(totalDebt: newDebt));

                                          
                                          ActivityLogger.log(
                                            user: appUser,
                                            actionType: 'Cancel Supplier Transaction|إلغاء عملية مورد',
                                            description: 'Cancelled ${isPayment ? "payment" : "debt"} of ${t.amount} for supplier ${currentSupplier.name}',
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
                                    const SizedBox(width: 8),
                                    Text(
                                      '${isPayment ? "-" : "+"}${t.amount} ${currentCurrency.code}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Tajawal',
                                        decoration: t.isCancelled ? TextDecoration.lineThrough : null,
                                        color: t.isCancelled ? Colors.grey : (isPayment ? Colors.green : Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isPayment && t.paymentMethod != null)
                                  Container(
                                    margin: EdgeInsets.only(top: 4),
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: t.paymentMethod == 'network' ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      t.paymentMethod == 'network' ? 'شبكة' : 'كاش',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: t.paymentMethod == 'network' ? Colors.blue : Colors.orange,
                                        fontFamily: 'Tajawal'
                                      ),
                                    ),
                                  )
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('خطأ: $e')),
            ),
          ),
        ],
      ),
      bottomNavigationBar: canManageInventory ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddDebtDialog(context, ref, currentSupplier),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة دين', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showPaySupplierDebtDialog(context, ref, currentSupplier),
                  icon: const Icon(Icons.payment),
                  label: const Text('تسديد دفعة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ) : null,
    );
  }

  void _showAddDebtDialog(BuildContext context, WidgetRef ref, Supplier currentSupplier) {
    final amountController = TextEditingController();
    final descController = TextEditingController(text: 'إضافة مديونية جديدة');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة دين جديد للمورد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'البيان / التفاصيل', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount <= 0) return;
              
              final user = ref.read(appUserProvider).value;
              final merchantId = user?.merchantId ?? user?.id ?? '';
              
              // 1. Update Supplier
              final updatedSupplier = currentSupplier.copyWith(totalDebt: currentSupplier.totalDebt + amount);
              await ref.read(supplierRepositoryProvider)?.updateSupplier(updatedSupplier);
              
              // 2. Add Transaction
              final tx = SupplierTransaction(
                id: const Uuid().v4(),
                supplierId: currentSupplier.id,
                merchantId: merchantId,
                amount: amount,
                type: 'debt_addition',
                description: descController.text.isEmpty ? 'إضافة دين' : descController.text,
                date: DateTime.now(),
                createdAt: DateTime.now(),
              );
              await ref.read(supplierTransactionRepositoryProvider)?.addTransaction(tx);
              
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('إضافة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPaySupplierDebtDialog(BuildContext context, WidgetRef ref, Supplier currentSupplier) {
    final amountController = TextEditingController(text: currentSupplier.totalDebt.toString());
    String paymentMethod = 'cash';
    bool isFromShiftDrawer = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
        title: const Text('تسديد ديون المورد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إجمالي دين المورد: ${currentSupplier.totalDebt}', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ المدفوع للمورد',
                labelStyle: TextStyle(fontFamily: 'Tajawal'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('طريقة الدفع:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('كاش', style: TextStyle(fontFamily: 'Tajawal')),
                    selected: paymentMethod == 'cash',
                    onSelected: (val) {
                      if (val) setState(() => paymentMethod = 'cash');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('شبكة/حوالة', style: TextStyle(fontFamily: 'Tajawal')),
                    selected: paymentMethod == 'network',
                    onSelected: (val) {
                      if (val) setState(() => paymentMethod = 'network');
                    },
                  ),
                ),
              ],
            ),
            if (paymentMethod == 'cash') ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: isFromShiftDrawer ? Colors.red.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isFromShiftDrawer ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                ),
                child: CheckboxListTile(
                  title: const Text('خصم من درج الوردية الحالي؟', style: TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                  subtitle: Text(
                    isFromShiftDrawer ? 'سيتم تقليل الكاش في الوردية' : 'لن يتم تغيير كاش الوردية',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: isFromShiftDrawer ? Colors.red : Colors.grey),
                  ),
                  value: isFromShiftDrawer,
                  onChanged: (val) {
                    setState(() => isFromShiftDrawer = val ?? true);
                  },
                  activeColor: Colors.red,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final paid = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (paid <= 0) return;
              
              if (paid > currentSupplier.totalDebt) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('مبلغ السداد لا يمكن أن يتجاوز دين المورد المستحق.', style: TextStyle(fontFamily: 'Tajawal')),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await ref.read(supplierRepositoryProvider)?.paySupplierDebt(
                  supplierId: currentSupplier.id,
                  amountPaid: paid,
                );
              } catch (e) {
                if (context.mounted) AppSnackbar.showError(context, e);
                return;
              }
              
              final user = ref.read(appUserProvider).value;
              final merchantId = user?.merchantId ?? user?.id ?? '';
              
              // 1. Register as Supplier Transaction
              final tx = SupplierTransaction(
                id: const Uuid().v4(),
                supplierId: currentSupplier.id,
                merchantId: merchantId,
                amount: paid,
                type: 'payment',
                paymentMethod: paymentMethod,
                description: 'دفعة سداد ديون للمورد' + (paymentMethod == 'cash' ? (isFromShiftDrawer ? ' (من الدرج)' : ' (خارج الدرج)') : ''),
                date: DateTime.now(),
                createdAt: DateTime.now(),
              );
              await ref.read(supplierTransactionRepositoryProvider)?.addTransaction(tx);
              
              // 2. Register as Expense
              final expense = Expense(
                id: const Uuid().v4(),
                merchantId: merchantId,
                amount: paid,
                isSupplierPayment: true,
                paymentMethod: paymentMethod,
                date: DateTime.now(),
                createdAt: DateTime.now(),
                title: 'دفعة سداد ديون للمورد: ${currentSupplier.name}',
                creatorName: user?.name ?? 'المدير',
                isFromShiftDrawer: isFromShiftDrawer,
              );
              await ref.read(expenseRepositoryProvider)?.addExpense(expense);
              
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('سداد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      )),
    );
  }

  void _showEditSupplierDialog(BuildContext context, WidgetRef ref, Supplier currentSupplier) {
    final nameController = TextEditingController(text: currentSupplier.name);
    final phoneController = TextEditingController(text: currentSupplier.phone);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل بيانات المورد', style: TextStyle(fontFamily: 'Tajawal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم المورد'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final appUser = ref.read(appUserProvider).value;
                if (appUser != null) {
                  final isAr = Localizations.localeOf(context).languageCode == 'ar';
                  final title = currentSupplier.isActive 
                    ? (isAr ? 'تأكيد: إلغاء المورد' : 'Warning: Cancel Supplier')
                    : (isAr ? 'تأكيد: استعادة المورد' : 'Confirm: Restore Supplier');
                  final warning = currentSupplier.isActive
                    ? (isAr ? 'سيتم شطب المورد من القائمة. لن يتم مسح بياناته السابقة.' : 'Supplier will be crossed out. Data will remain.')
                    : (isAr ? 'سيتم استعادة المورد وإزالة الشطب.' : 'Supplier will be restored.');
                    
                  final success = await PinConfirmationDialog.requirePinOrSetup(
                    context, 
                    appUser,
                    title: title,
                    warning: warning,
                  );
                  if (!success) return;
                }
                final updatedSupplier = currentSupplier.copyWith(isActive: !currentSupplier.isActive);
                ref.read(supplierRepositoryProvider)?.updateSupplier(updatedSupplier);
                if (context.mounted) Navigator.pop(context); // Close details screen too
              },
              child: Text(
                currentSupplier.isActive ? 'إلغاء المورد' : 'استعادة المورد', 
                style: TextStyle(color: currentSupplier.isActive ? Colors.red : Colors.green)
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;
                final updatedSupplier = currentSupplier.copyWith(
                  name: nameController.text,
                  phone: phoneController.text,
                );
                ref.read(supplierRepositoryProvider)?.updateSupplier(updatedSupplier);
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }
}
