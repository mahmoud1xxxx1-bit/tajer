import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../data/supplier_repository.dart';
import '../domain/supplier.dart';
import 'add_supplier_dialog.dart';
import 'supplier_details_screen.dart';
import '../../../core/theme/glass_card.dart';
import '../../authentication/data/auth_repository.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../../core/services/activity_logger.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final currency = ref.watch(currencyProvider).code;
    final appUser = ref.watch(appUserProvider).value;
    final canManageSuppliers = appUser?.hasPermission('can_manage_suppliers') ?? false;
    final repository = ref.watch(supplierRepositoryProvider);
    final query = repository?.querySuppliers(
      searchQuery: _searchQuery,
      hasDebt: _filterHasDebt,
      sortBy: _sortOption,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.suppliers, style: const TextStyle(fontFamily: 'Tajawal'))),
      body: Column(
        children: [
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
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilterChip(
                      label: Text(l10n.hasDebts, style: const TextStyle(fontFamily: 'Tajawal')),
                      selected: _filterHasDebt,
                      onSelected: (val) => setState(() => _filterHasDebt = val),
                      selectedColor: Colors.red.withValues(alpha: 0.2),
                      checkmarkColor: Colors.red,
                    ),
                    const Spacer(),
                    Text(l10n.sortBy, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12)),
                    DropdownButton<String>(
                      value: _sortOption,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(value: 'newest', child: Text(l10n.newest, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
                        DropdownMenuItem(value: 'debt', child: Text(l10n.highestDebt, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
                        DropdownMenuItem(value: 'alpha', child: Text(l10n.sortAlphabetical, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
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
                    pageSize: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    emptyBuilder: (context) => Center(
                      child: Text(
                        _searchQuery.isNotEmpty || _filterHasDebt ? l10n.noSuppliersMatch : l10n.noSuppliersYet,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16),
                      ),
                    ),
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'تعذر تحميل الموردين. حاول مرة أخرى.'
                            : 'Could not load suppliers. Please try again.',
                        style: const TextStyle(fontFamily: 'Tajawal'),
                      ),
                    ),
                    itemBuilder: (context, doc) {
                      final supplier = doc.data();
                      return _buildSupplierCard(supplier, context, ref, currency, canManageSuppliers);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: canManageSuppliers
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: const AddSupplierDialog(),
                  ),
                );
              },
              label: Text(l10n.addSupplier, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.person_add_alt_1),
            )
          : null,
    );
  }

  Widget _buildSupplierCard(Supplier supplier, BuildContext context, WidgetRef ref, String currency, bool canManageSuppliers) {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierDetailsScreen(supplier: supplier))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange.shade700, Colors.orange.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: Text(supplier.name.isNotEmpty ? supplier.name.substring(0, 1).toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24, fontFamily: 'Tajawal')),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 18, decoration: !supplier.isActive ? TextDecoration.lineThrough : null, color: !supplier.isActive ? Colors.grey : null),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(children: [const Icon(Icons.phone, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(supplier.phone, style: const TextStyle(color: Colors.grey, fontFamily: 'Tajawal'))]),
                  if (supplier.notes != null && supplier.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(supplier.notes!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Tajawal')),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (supplier.totalDebt > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(l10n.debt, style: const TextStyle(color: Colors.red, fontSize: 10, fontFamily: 'Tajawal')),
                        Text('${supplier.totalDebt.toStringAsFixed(2)} $currency', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  )
                else
                  Text(l10n.noDebt, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Tajawal')),
                const SizedBox(height: 4),
                if (canManageSuppliers)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    onSelected: (value) async {
                      if (value == 'edit') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: AddSupplierDialog(supplierToEdit: supplier)),
                        );
                      } else if (value == 'delete') {
                        if (supplier.isActive && supplier.totalDebt.abs() > 0.01) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(Localizations.localeOf(ctx).languageCode == 'ar' ? 'تنبيه' : 'Warning', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.red)),
                              content: Text(Localizations.localeOf(ctx).languageCode == 'ar' ? 'يجب تسديد الدين اولا لشطب المورد' : 'Debt must be settled first to cancel the supplier.', style: const TextStyle(fontFamily: 'Tajawal')),
                              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً', style: TextStyle(fontFamily: 'Tajawal')))],
                            ),
                          );
                          return;
                        }

                        final currentUser = ref.read(appUserProvider).value;
                        if (currentUser != null) {
                          final isAr = Localizations.localeOf(context).languageCode == 'ar';
                          final title = supplier.isActive ? (isAr ? 'تأكيد: إلغاء المورد' : 'Warning: Cancel Supplier') : (isAr ? 'تأكيد: استعادة المورد' : 'Confirm: Restore Supplier');
                          final warning = supplier.isActive ? (isAr ? 'سيتم شطب المورد من القائمة. لن يتم مسح بياناته السابقة.' : 'Supplier will be crossed out. Data will remain.') : (isAr ? 'سيتم استعادة المورد وإزالة الشطب.' : 'Supplier will be restored.');
                          final success = await PinConfirmationDialog.requirePinOrSetup(context, currentUser, title: title, warning: warning);
                          if (!success) return;
                        }
                        try {
                          final updatedSupplier = supplier.copyWith(isActive: !supplier.isActive);
                          await ref.read(supplierRepositoryProvider)?.updateSupplier(updatedSupplier);
                          if (currentUser != null) {
                            ActivityLogger.log(
                              user: currentUser,
                              actionType: supplier.isActive ? 'Cancel Supplier|إلغاء مورد' : 'Restore Supplier|استعادة مورد',
                              description: '${supplier.isActive ? "Cancelled" : "Restored"} supplier (${supplier.name})|${supplier.isActive ? "إلغاء" : "استعادة"} المورد (${supplier.name})',
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(Localizations.localeOf(ctx).languageCode == 'ar' ? 'تنبيه' : 'Warning', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.red)),
                                content: Text(e.toString().replaceAll('Exception: ', ''), style: const TextStyle(fontFamily: 'Tajawal')),
                                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً', style: TextStyle(fontFamily: 'Tajawal')))],
                              ),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit, size: 20, color: Colors.blue), const SizedBox(width: 8), Text(l10n.edit, style: const TextStyle(fontFamily: 'Tajawal'))])),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(supplier.isActive ? Icons.cancel_outlined : Icons.restore, color: supplier.isActive ? Colors.red : Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              supplier.isActive ? (Localizations.localeOf(context).languageCode == 'ar' ? 'إلغاء المورد' : 'Cancel Supplier') : (Localizations.localeOf(context).languageCode == 'ar' ? 'استعادة المورد' : 'Restore Supplier'),
                              style: TextStyle(color: supplier.isActive ? Colors.red : Colors.green, fontFamily: 'Tajawal'),
                            ),
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
}
