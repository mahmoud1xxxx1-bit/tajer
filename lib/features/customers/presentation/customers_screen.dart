import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customer_repository.dart';
import 'add_customer_dialog.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/services/pdf_service.dart';
import '../../orders/data/order_repository.dart';

import '../../../core/providers/settings_provider.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsyncValue = ref.watch(customersStreamProvider);
    final currency = ref.watch(currencyProvider).code;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة العملاء', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: customersAsyncValue.when(
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(
              child: Text(
                'لا يوجد عملاء بعد.\nاضغط على + لإضافة عميل جديد.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
              ),
            );
          }
          return ListView.builder(
            itemCount: customers.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final customer = customers[index];
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(4),
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('حذف العميل', style: TextStyle(fontFamily: 'Tajawal')),
                      content: const Text('هل أنت متأكد من حذف هذا العميل؟', style: TextStyle(fontFamily: 'Tajawal')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(customerRepositoryProvider).deleteCustomer(customer.id);
                            Navigator.pop(context);
                          },
                          child: const Text('حذف', style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                        ),
                      ],
                    ),
                  );
                },
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      customer.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  title: Text(
                    customer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 18),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          customer.phone,
                          style: const TextStyle(fontFamily: 'Tajawal'),
                        ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${customer.totalPurchases} $currency',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (customer.totalDebt > 0)
                            Text(
                              'دين: ${customer.totalDebt} $currency',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${customer.orderCount} طلبات',
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).viewInsets.bottom,
                                ),
                                child: AddCustomerDialog(customerToEdit: customer),
                              ),
                            );
                          } else if (value == 'delete') {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('حذف العميل', style: TextStyle(fontFamily: 'Tajawal')),
                                content: const Text('هل أنت متأكد من حذف هذا العميل؟', style: TextStyle(fontFamily: 'Tajawal')),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ref.read(customerRepositoryProvider).deleteCustomer(customer.id);
                                      Navigator.pop(context);
                                    },
                                    child: const Text('حذف', style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                                  ),
                                ],
                              ),
                            );
                          } else if (value == 'print') {
                            final orders = ref.read(ordersStreamProvider).value ?? [];
                            try {
                              await PdfService.printCustomerStatement(customer, orders, currency);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('خطأ في الطباعة: $e', style: const TextStyle(fontFamily: 'Tajawal'))),
                                );
                              }
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('تعديل', style: TextStyle(fontFamily: 'Tajawal')),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'print',
                            child: Row(
                              children: [
                                Icon(Icons.print_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('طباعة كشف حساب', style: TextStyle(fontFamily: 'Tajawal')),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('حذف', style: TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal')),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final canAdd = await GuestLimitService.canAddCustomer(context, ref);
          if (!canAdd) return;

          if (context.mounted) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: const AddCustomerDialog(),
              ),
            );
          }
        },
        label: const Text('إضافة عميل', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.person_add),
      ),
    );
  }
}
