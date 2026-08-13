import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/supplier_repository.dart';
import '../domain/supplier.dart';
import 'package:flutter/cupertino.dart';
import 'supplier_details_screen.dart';
import '../data/supplier_transaction_repository.dart';
import '../domain/supplier_transaction.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _searchQuery = '';
  bool _filterHasDebt = false;
  String _sortOption = 'newest';

  @override
  Widget build(BuildContext context) {
    final currentCurrency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final canManageInventory = appUser?.hasPermission('can_manage_inventory') ?? false;

    final repository = ref.watch(supplierRepositoryProvider);
    final query = repository?.querySuppliers(
      searchQuery: _searchQuery,
      hasDebt: _filterHasDebt,
      sortBy: _sortOption,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text122, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.searchNamePhone,
                    labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilterChip(
                      label: Text(AppLocalizations.of(context)!.hasDebts, style: TextStyle(fontFamily: 'Tajawal')),
                      selected: _filterHasDebt,
                      onSelected: (val) => setState(() => _filterHasDebt = val),
                      selectedColor: Colors.red.withValues(alpha: 0.2),
                      checkmarkColor: Colors.red,
                    ),
                    const Spacer(),
                    Text(AppLocalizations.of(context)!.sortBy, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12)),
                    DropdownButton<String>(
                      value: _sortOption,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(value: 'newest', child: Text('الأحدث', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
                        DropdownMenuItem(value: 'debt', child: Text(AppLocalizations.of(context)!.highestDebt, style: TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
                        DropdownMenuItem(value: 'alpha', child: Text(AppLocalizations.of(context)!.sortAlphabetical, style: TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
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
            child: query == null
                ? const Center(child: CircularProgressIndicator())
                : FirestoreListView<Supplier>(
                    query: query,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    emptyBuilder: (context) => Center(
                      child: Text(AppLocalizations.of(context)!.text123, style: TextStyle(fontFamily: 'Tajawal')),
                    ),
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text('خطأ: $error', style: TextStyle(fontFamily: 'Tajawal')),
                    ),
                    itemBuilder: (context, doc) {
                      final supplier = doc.data();
                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.zero,
                        onTap: canManageInventory
                            ? () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => SupplierDetailsScreen(supplier: supplier),
                                  ),
                                );
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.business, color: Theme.of(context).colorScheme.primary, size: 26),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      supplier.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Tajawal',
                                        fontSize: 17,
                                        decoration: !supplier.isActive ? TextDecoration.lineThrough : null,
                                        color: !supplier.isActive ? Colors.grey : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          supplier.phone ?? AppLocalizations.of(context)!.text124,
                                          style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey[700], fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!.text125,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Tajawal'),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: supplier.totalDebt > 0
                                          ? Colors.red.withValues(alpha: 0.1)
                                          : Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${supplier.totalDebt} ${currentCurrency.code}',
                                      style: TextStyle(
                                        color: supplier.totalDebt > 0 ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (canManageInventory) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (_) => SupplierDetailsScreen(supplier: supplier),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: canManageInventory
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () async {
                final canAdd = await GuestLimitService.canAddSupplier(context, ref);
                if (!canAdd) return;
                if (context.mounted) _showAddSupplierDialog(context, ref);
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAddSupplierDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final debtController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.text126, style: const TextStyle(fontFamily: 'Tajawal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text127),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text128),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: debtController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.text129),
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

                if (nameController.text.isEmpty) return;

                final initialDebt = double.tryParse(debtController.text) ?? 0.0;
                final supplier = Supplier(
                  id: const Uuid().v4(),
                  merchantId: ref.read(appUserProvider).value?.merchantId ?? user.uid,
                  name: nameController.text,
                  phone: phoneController.text,
                  totalDebt: initialDebt,
                  createdAt: DateTime.now(),
                );

                ref.read(supplierRepositoryProvider)?.addSupplier(supplier);

                if (initialDebt > 0) {
                  final tx = SupplierTransaction(
                    id: const Uuid().v4(),
                    supplierId: supplier.id,
                    merchantId: supplier.merchantId,
                    amount: initialDebt,
                    type: 'debt_addition',
                    description: 'رصيد افتتاحي / دين أولي',
                    date: DateTime.now(),
                    createdAt: DateTime.now(),
                  );
                  ref.read(supplierTransactionRepositoryProvider)?.addTransaction(tx);
                }

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
