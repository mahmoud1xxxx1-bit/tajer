import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/supplier_repository.dart';
import '../data/supplier_transaction_repository.dart';
import '../domain/supplier.dart';
import '../domain/supplier_transaction.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';

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
                    
                    return Card(
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
                                color: isPayment ? Colors.green : Colors.red,
                                size: 20,
                              ),
                            ),
                            title: Text(t.description, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14)),
                            subtitle: Text(DateFormat('hh:mm a').format(t.date), style: const TextStyle(fontSize: 12)),
                            trailing: Text(
                              '${isPayment ? "-" : "+"}${t.amount} ${currentCurrency.code}',
                              style: TextStyle(
                                color: isPayment ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal'
                              ),
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
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.red,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              
              final newDebt = (currentSupplier.totalDebt - paid) < 0 ? 0.0 : (currentSupplier.totalDebt - paid);
              final updatedSupplier = currentSupplier.copyWith(totalDebt: newDebt);
              await ref.read(supplierRepositoryProvider)?.updateSupplier(updatedSupplier);
              
              final user = ref.read(appUserProvider).value;
              final merchantId = user?.merchantId ?? user?.id ?? '';
              
              // 1. Register as Supplier Transaction
              final tx = SupplierTransaction(
                id: const Uuid().v4(),
                supplierId: currentSupplier.id,
                merchantId: merchantId,
                amount: paid,
                type: 'payment',
                description: 'دفعة سداد ديون للمورد',
                date: DateTime.now(),
                createdAt: DateTime.now(),
              );
              await ref.read(supplierTransactionRepositoryProvider)?.addTransaction(tx);
              
              // 2. Register as Expense
              final expense = Expense(
                id: const Uuid().v4(),
                merchantId: merchantId,
                amount: paid,
                category: 'سداد ديون موردين',
                date: DateTime.now(),
                createdAt: DateTime.now(),
                title: 'دفعة سداد ديون للمورد: ${currentSupplier.name}',
                creatorName: user?.name ?? 'المدير',
              );
              await ref.read(expenseRepositoryProvider)?.addExpense(expense);
              
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('تأكيد السداد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
              onPressed: () {
                ref.read(supplierRepositoryProvider)?.deleteSupplier(currentSupplier.id);
                Navigator.pop(context);
                Navigator.pop(context); // Close details screen too
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
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
