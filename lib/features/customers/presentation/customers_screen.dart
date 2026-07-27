import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customer_repository.dart';
import 'add_customer_dialog.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsyncValue = ref.watch(customersStreamProvider);

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
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(customer.name.substring(0, 1)),
                  ),
                  title: Text(
                    customer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                  ),
                  subtitle: Text(
                    customer.phone,
                    style: const TextStyle(fontFamily: 'Tajawal'),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${customer.totalPurchases} ريال',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${customer.orderCount} طلبات',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
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
        onPressed: () {
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
        },
        label: const Text('إضافة عميل', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.person_add),
      ),
    );
  }
}
