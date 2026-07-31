import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customer_repository.dart';
import 'add_customer_dialog.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/services/pdf_service.dart';
import '../../orders/data/order_repository.dart';

import '../../../core/providers/settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsyncValue = ref.watch(customersStreamProvider);
    final currency = ref.watch(currencyProvider).code;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text55, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: customersAsyncValue.when(
        data: (customers) {
          if (customers.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.text56,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
              ),
            );
          }
          return ListView.builder(
            itemCount: customers.length,
            padding: EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final customer = customers[index];
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.zero,
                onTap: () {
                  // Optional: handle tap
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
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
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          customer.name.isNotEmpty ? customer.name.substring(0, 1).toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24, fontFamily: 'Tajawal'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 18),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  customer.phone,
                                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey[700], fontSize: 13),
                                ),
                                const SizedBox(width: 12),
                                if (customer.phone.isNotEmpty)
                                  InkWell(
                                    onTap: () async {
                                      String cleanedPhone = customer.phone.replaceAll(RegExp(r'[^\d+]'), '');
                                      if (cleanedPhone.isNotEmpty) {
                                        if (cleanedPhone.startsWith('0')) {
                                          cleanedPhone = cleanedPhone.substring(1);
                                          cleanedPhone = '+966$cleanedPhone'; // Default country code if missing
                                        }
                                        final url = Uri.parse('https://wa.me/$cleanedPhone');
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url, mode: LaunchMode.externalApplication);
                                        }
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.chat_bubble_outline, size: 14, color: Colors.green),
                                          const SizedBox(width: 4),
                                          const Text('واتساب', style: TextStyle(color: Colors.green, fontSize: 10, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${customer.orderCount} طلبات',
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                                  ),
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
                            '${customer.totalPurchases} $currency',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (customer.totalDebt > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'دين: ${customer.totalDebt} $currency',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            padding: EdgeInsets.zero,
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
                                    title: Text(AppLocalizations.of(context)!.text57, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                    content: Text(AppLocalizations.of(context)!.text58, style: const TextStyle(fontFamily: 'Tajawal')),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(AppLocalizations.of(context)!.text43, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          ref.read(customerRepositoryProvider).deleteCustomer(customer.id);
                                          Navigator.pop(context);
                                        },
                                        child: Text(AppLocalizations.of(context)!.text59, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (value == 'print') {
                                final orders = ref.read(ordersStreamProvider).value ?? [];
                                try {
                                  await PdfService.printCustomerStatement(context, customer, orders, currency);
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
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit, size: 20, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(AppLocalizations.of(context)!.text60, style: const TextStyle(fontFamily: 'Tajawal')),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'print',
                                child: Row(
                                  children: [
                                    const Icon(Icons.print_outlined, size: 20, color: Colors.indigo),
                                    const SizedBox(width: 8),
                                    Text(AppLocalizations.of(context)!.text61, style: const TextStyle(fontFamily: 'Tajawal')),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Text(AppLocalizations.of(context)!.text59, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
                                  ],
                                ),
                              ),
                            ],
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
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text('حدث خطأ: $e', style: TextStyle(fontFamily: 'Tajawal')),
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
        label: Text(AppLocalizations.of(context)!.text62, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        icon: Icon(Icons.person_add),
      ),
    );
  }
}
