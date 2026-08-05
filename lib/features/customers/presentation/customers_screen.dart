import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import '../../authentication/data/auth_repository.dart';
import 'add_customer_dialog.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/services/pin_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../../core/services/pdf_service.dart';
import '../../orders/data/order_repository.dart';
import '../../shifts/data/shift_repository.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  String _searchQuery = '';
  bool _filterHasDebt = false;
  String _sortOption = 'newest';
  
  bool _isSelectionMode = false;
  Set<String> _selectedCustomerIds = {};
  Set<String> _expandedFolders = {};
  bool _isInitialized = false;

  @override
  Widget build(BuildContext context) {
    
    if (!_isInitialized) {
      _expandedFolders.add(l10n.generalCustomers);
      _isInitialized = true;
    }
    final customersAsyncValue = ref.watch(customersStreamProvider);
    final currency = ref.watch(currencyProvider).code;
    final appUser = ref.watch(appUserProvider).value;
    final canManageCustomers = appUser?.hasPermission('can_manage_customers') ?? false;
    final canReceivePayments = appUser?.hasPermission('can_receive_payments') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text(l10n.selectedCount(_selectedCustomerIds.length.toString()), style: const TextStyle(fontFamily: 'Tajawal'))
            : Text(AppLocalizations.of(context)!.text55, style: const TextStyle(fontFamily: 'Tajawal')),
        leading: _isSelectionMode ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _isSelectionMode = false;
            _selectedCustomerIds.clear();
          }),
        ) : null,
        actions: [
          if (_isSelectionMode && _selectedCustomerIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.create_new_folder, color: Colors.blue),
              tooltip: 'نقل إلى مجلد',
              onPressed: () => _showMoveToFolderDialog(context, ref),
            ),
          if (!_isSelectionMode && canManageCustomers)
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'تحديد متعدد',
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
          if (!_isSelectionMode && canManageCustomers)
            IconButton(
              icon: const Icon(Icons.file_download, color: Colors.green),
              tooltip: 'تصدير لإكسل',
              onPressed: () => _exportToExcel(customersAsyncValue.value ?? []),
            ),
        ],
      ),
      body: customersAsyncValue.when(
        data: (customers) {
          var filtered = customers.where((c) {
            final matchesSearch = c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                  c.phone.contains(_searchQuery);
            final matchesDebt = !_filterHasDebt || c.totalDebt > 0;
            return matchesSearch && matchesDebt;
          }).toList();

          if (_sortOption == 'debt') {
            filtered.sort((a, b) => b.totalDebt.compareTo(a.totalDebt));
          } else if (_sortOption == 'alpha') {
            filtered.sort((a, b) => a.name.compareTo(b.name));
          } else {
            filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }

          final Map<String, List<Customer>> groupedCustomers = {};
          final List<Customer> uncategorized = [];
          
          for (var c in filtered) {
            if (c.folderName != null && c.folderName!.isNotEmpty) {
              groupedCustomers.putIfAbsent(c.folderName!, () => []).add(c);
            } else {
              uncategorized.add(c);
            }
          }

          final List<dynamic> flattenedList = [];
          for (var entry in groupedCustomers.entries) {
            flattenedList.add(entry.key);
            if (_expandedFolders.contains(entry.key)) {
              flattenedList.addAll(entry.value);
            }
          }
          if (uncategorized.isNotEmpty) {
            flattenedList.add(l10n.generalCustomers);
            if (_expandedFolders.contains(l10n.generalCustomers)) {
              flattenedList.addAll(uncategorized);
            }
          }

          return Column(
            children: [
              if (!_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          labelText: l10n.searchNamePhone,
                          labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilterChip(
                            label: Text(l10n.hasDebts, style: TextStyle(fontFamily: 'Tajawal')),
                            selected: _filterHasDebt,
                            onSelected: (val) => setState(() => _filterHasDebt = val),
                            selectedColor: Colors.red.withOpacity(0.2),
                            checkmarkColor: Colors.red,
                          ),
                          const Spacer(),
                          Text(l10n.sortBy, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12)),
                          DropdownButton<String>(
                            value: _sortOption,
                            underline: const SizedBox(),
                            items: [DropdownMenuItem(value: 'newest', child: Text('الأحدث', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
                              DropdownMenuItem(value: 'debt', child: Text(l10n.highestDebt, style: TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
                              DropdownMenuItem(value: 'alpha', child: Text(l10n.sortAlphabetical, style: TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _sortOption = val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: flattenedList.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty || _filterHasDebt ? 'لا يوجد عملاء يطابقون البحث' : AppLocalizations.of(context)!.text56,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: flattenedList.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final item = flattenedList[index];
                          
                          if (item is String) {
                            final isExpanded = _expandedFolders.contains(item);
                            final isGeneral = item == l10n.generalCustomers;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpanded) _expandedFolders.remove(item);
                                  else _expandedFolders.add(item);
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isGeneral ? Colors.grey.withOpacity(0.2) : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(isGeneral ? Icons.people : Icons.folder, color: isGeneral ? Colors.grey[700] : Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                                  ],
                                ),
                              ),
                            );
                          } else if (item is Customer) {
                            return _buildCustomerCard(item, context, ref, currency, canManageCustomers, canReceivePayments);
                          }
                          return const SizedBox();
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal')),
        ),
      ),
      floatingActionButton: canManageCustomers && !_isSelectionMode ? FloatingActionButton.extended(
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
        label: Text(AppLocalizations.of(context)!.text62, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.person_add),
      ) : null,
    );
  }

  Widget _buildCustomerCard(Customer customer, BuildContext context, WidgetRef ref, String currency, bool canManageCustomers, bool canReceivePayments) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12, left: 16),
      padding: EdgeInsets.zero,
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (_selectedCustomerIds.contains(customer.id)) {
              _selectedCustomerIds.remove(customer.id);
            } else {
              _selectedCustomerIds.add(customer.id);
            }
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (_isSelectionMode)
              Checkbox(
                value: _selectedCustomerIds.contains(customer.id),
                onChanged: (val) {
                  setState(() {
                    if (val == true) _selectedCustomerIds.add(customer.id);
                    else _selectedCustomerIds.remove(customer.id);
                  });
                },
              ),
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
                        style: const TextStyle(color: Colors.grey, fontFamily: 'Tajawal'),
                      ),
                      if (customer.phone.isNotEmpty)
                        const SizedBox(width: 8),
                      if (customer.phone.isNotEmpty)
                        InkWell(
                          onTap: () async {
                            final url = Uri.parse('whatsapp://send?phone=${customer.phone}');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
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
                                const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(l10n.whatsapp, style: TextStyle(color: Colors.green, fontSize: 10, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
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
                          '${customer.orderCount} ${Localizations.localeOf(context).languageCode == "ar" ? "طلبات" : "orders"}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (customer.creatorName != null && customer.creatorName!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${l10n.byCreator(customer.creatorName)}',
                            style: const TextStyle(fontSize: 12, color: Colors.teal, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
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
                      l10n.debtAmount(customer.totalDebt.toString(), currency),
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
                if (!_isSelectionMode)
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
                      } else if (value == 'pay_debt') {
                        _showPayDebtDialog(context, ref, customer);
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
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final appUser = ref.read(appUserProvider).value;
                                  if (appUser != null) {
                                    final pin = await PinService.getDeletePin(appUser);
                                    if (pin != null) {
                                      if (!context.mounted) return;
                                      final success = await PinConfirmationDialog.show(
                                        context, 
                                        pin,
                                        title: l10n.warningDeleteCustomer,
                                        warning: l10n.deleteCustomerWarningText,
                                      );
                                      if (!success) return;
                                    }
                                  }
                                  ref.read(customerRepositoryProvider).deleteCustomer(customer.id);
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
                              SnackBar(content: Text(l10n.printError(e.toString()), style: const TextStyle(fontFamily: 'Tajawal'))),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (canManageCustomers)
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
                      if (customer.totalDebt > 0 && canReceivePayments)
                        const PopupMenuItem(
                          value: 'pay_debt',
                          child: Row(
                            children: [
                              Icon(Icons.payments, size: 20, color: Colors.green),
                              SizedBox(width: 8),
                              Text(l10n.payDebt, style: TextStyle(fontFamily: 'Tajawal', color: Colors.green, fontWeight: FontWeight.bold)),
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
                      if (canManageCustomers)
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
  }

  void _showMoveToFolderDialog(BuildContext context, WidgetRef ref) {
    final folderController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.moveToFolder, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل اسم المجلد الجديد أو الحالي لجمع العملاء المحددين فيه:', style: TextStyle(fontFamily: 'Tajawal')),
            const SizedBox(height: 16),
            TextField(
              controller: folderController,
              decoration: const InputDecoration(
                labelText: 'اسم المجلد (مثال: عملاء الجملة)',
                labelStyle: TextStyle(fontFamily: 'Tajawal'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.leaveEmptyToRemoveFromFolder, style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final folderName = folderController.text.trim();
              await ref.read(customerRepositoryProvider).moveCustomersToFolder(
                _selectedCustomerIds.toList(),
                folderName.isEmpty ? null : folderName,
              );
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {
                  _isSelectionMode = false;
                  _selectedCustomerIds.clear();
                  if (folderName.isNotEmpty) {
                    _expandedFolders.add(folderName);
                  }
                });
              }
            },
            child: Text(l10n.move, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPayDebtDialog(BuildContext context, WidgetRef ref, Customer customer) {
    final amountController = TextEditingController(text: customer.totalDebt.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.payDebt, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.totalCustomerDebtText(customer.totalDebt.toString()), style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ المسدد من الدين',
                labelStyle: TextStyle(fontFamily: 'Tajawal'),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.text43, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final paid = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (paid <= 0) return;
              
              final user = ref.read(appUserProvider).value;
              final merchantId = user?.merchantId ?? user?.id ?? '';
              final currentShift = ref.read(currentShiftProvider(merchantId)).value;
              
              await ref.read(orderRepositoryProvider).payCustomerDebt(
                merchantId: merchantId,
                customerId: customer.id,
                amountPaid: paid,
                shiftId: currentShift?.id,
              );
              
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('تأكيد السداد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel(List<Customer> customers) async {
    
    try {
      if (customers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.noCustomersToExport, style: TextStyle(fontFamily: 'Tajawal'))),
          );
        }
        return;
      }

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Customers'];
      excel.setDefaultSheet('Customers');
      
      // Header row
      sheetObject.appendRow([
        TextCellValue('اسم العميل'),
        TextCellValue('رقم الهاتف'),
        TextCellValue(l10n.folder),
        TextCellValue('إجمالي المشتريات'),
        TextCellValue('إجمالي الديون'),
        TextCellValue('تاريخ الإضافة'),
      ]);

      // Data rows
      for (var c in customers) {
        sheetObject.appendRow([
          TextCellValue(c.name),
          TextCellValue(c.phone),
          TextCellValue(c.folderName ?? l10n.general),
          TextCellValue(c.totalPurchases.toString()),
          TextCellValue(c.totalDebt.toString()),
          TextCellValue(c.createdAt.toString().split(' ')[0]),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${directory.path}/customers_$timestamp.xlsx';
        
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
          
        await Share.shareXFiles([XFile(filePath)], text: 'قائمة العملاء');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportError(e.toString()), style: const TextStyle(fontFamily: 'Tajawal'))),
        );
      }
    }
  }
}
