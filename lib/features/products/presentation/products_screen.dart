import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../data/product_repository.dart';
import 'add_product_dialog.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/activity_logger.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/utils/date_formatter.dart';
import '../../categories/data/category_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import '../domain/product.dart';
import '../../../core/services/excel_import_service.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentCurrency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final canManageProducts = appUser?.hasPermission('can_manage_products') ?? false;

    final repository = ref.watch(productRepositoryProvider);
    final query = appUser != null 
        ? repository.queryProducts(appUser.merchantId ?? appUser.id)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.products, style: const TextStyle(fontFamily: 'Tajawal')),
        actions: [
          if (canManageProducts)
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_rounded, color: Colors.green),
              tooltip: l10n.localeName == 'ar' ? 'استيراد من إكسيل' : 'Import from Excel',
              onSelected: (value) async {
                if (value == 'download_template') {
                  await ExcelImportService.downloadTemplate();
                } else if (value == 'import_excel') {
                  if (appUser == null) return;
                  final products = await ExcelImportService.pickAndParseProductsExcel(appUser.merchantId ?? appUser.id);
                  if (products != null && products.isNotEmpty) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.localeName == 'ar' ? 'جاري رفع ${products.length} منتج...' : 'Uploading ${products.length} products...',
                          style: const TextStyle(fontFamily: 'Tajawal'),
                        ),
                        backgroundColor: Colors.blue,
                      ),
                    );
                    await repository.addProductsBatch(products);
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.localeName == 'ar' ? 'تم استيراد ${products.length} منتج بنجاح!' : 'Successfully imported ${products.length} products!',
                          style: const TextStyle(fontFamily: 'Tajawal'),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'download_template',
                  child: Row(
                    children: [
                      const Icon(Icons.file_download, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.localeName == 'ar' ? 'تحميل قالب الإكسيل' : 'Download Excel Template', style: const TextStyle(fontFamily: 'Tajawal')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'import_excel',
                  child: Row(
                    children: [
                      const Icon(Icons.upload_file, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.localeName == 'ar' ? 'رفع ملف المنتجات' : 'Upload Products File', style: const TextStyle(fontFamily: 'Tajawal')),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                    l10n.localeName == 'ar' 
                      ? '💡 دليل المنتجات: أضف أصناف وجباتك أو بضائعك هنا. يمكنك ربط المنتج بالمواد الخام (المكونات) ليتم الخصم التلقائي من المستودع عند البيع في شاشة الـ POS.' 
                      : '💡 Products Guide: Add your inventory items or meals here. You can link a product to raw materials for automatic deduction from inventory when sold via POS.',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: query == null
                ? const Center(child: CircularProgressIndicator())
                : FirestoreListView<Product>(
                    query: query,
                    padding: const EdgeInsets.all(16),
                    emptyBuilder: (context) {
                      final isAr = l10n.localeName == 'ar';
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.indigo.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              isAr ? "متجرك فارغ!" : "Your store is empty!",
                              style: TextStyle(fontFamily: 'Tajawal', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                isAr 
                                    ? "لا يوجد منتجات بعد! أضف بضاعتك للرفوف لتبدأ البيع فوراً." 
                                    : "No products yet! Add your inventory to the shelves to start selling immediately.",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, color: Colors.grey.shade600, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text('${l10n.error}: $error', style: const TextStyle(fontFamily: 'Tajawal')),
                    ),
                    itemBuilder: (context, doc) {
                      final product = doc.data();
                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.zero,
                        onLongPress: canManageProducts ? () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => Padding(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(context).viewInsets.bottom,
                              ),
                              child: AddProductDialog(productToEdit: product),
                            ),
                          );
                        } : null,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.inventory_2_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 16),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.inventory,
                                              size: 14,
                                              color: (!product.isManufacturedOnDemand && product.quantity <= 5) ? Colors.red : Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              product.isManufacturedOnDemand ? 'يُصنع عند الطلب' : '${l10n.quantity}: ${product.quantity}',
                                              style: TextStyle(
                                                fontFamily: 'Tajawal',
                                                color: (!product.isManufacturedOnDemand && product.quantity <= 5) ? Colors.red : Colors.grey[700],
                                                fontWeight: (!product.isManufacturedOnDemand && product.quantity <= 5) ? FontWeight.bold : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (!product.isManufacturedOnDemand && product.quantity <= 5) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                                            ],
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.teal),
                                            const SizedBox(width: 4),
                                            Text(
                                              AppDateFormatter.format(product.createdAt),
                                              style: const TextStyle(fontFamily: 'Tajawal', color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${product.price} ${currentCurrency.code}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (canManageProducts)
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
                                            child: AddProductDialog(productToEdit: product),
                                          ),
                                        );
                                      } else if (value == 'delete') {
                                        final appUser = ref.read(appUserProvider).value;
                                        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
                                        if (appUser != null) {
                                          final success = await PinConfirmationDialog.requirePinOrSetup(
                                            context,
                                            appUser,
                                            title: isArabic ? 'تأكيد الحذف' : 'Confirm Deletion',
                                            warning: isArabic 
                                              ? 'حذف هذا المنتج سيمنعك من مسح أو إلغاء أي فاتورة سابقة تحتوي عليه.\nإذا كان المنتج مربوطاً بمواد خام، يجب عليك حذف مواده الخام أولاً.\nهل أنت متأكد من الحذف؟'
                                              : 'Deleting prevents cancelling past invoices. If linked to raw materials, delete them first. Proceed?',
                                          );
                                          if (!success) return;
                                        }
                                        ref.read(productRepositoryProvider).deleteProduct(product.id);
                                        ActivityLogger.log(
                                          user: appUser,
                                          actionType: 'Archive Product|أرشفة منتج',
                                          description: 'Archived product "${product.name}"|تم أرشفة وإخفاء المنتج "${product.name}"',
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.edit, size: 20, color: Colors.blue),
                                            const SizedBox(width: 8),
                                            Text(l10n.edit, style: const TextStyle(fontFamily: 'Tajawal')),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete, color: Colors.red, size: 20),
                                            const SizedBox(width: 8),
                                            Text(l10n.delete, style: const TextStyle(color: Colors.red, fontFamily: 'Tajawal')),
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
                  ),
          ),
        ],
      ),
      floatingActionButton: canManageProducts ? FloatingActionButton.extended(
        heroTag: null,
        onPressed: () async {
          final categories = ref.read(categoriesStreamProvider).value;
          if (categories == null || categories.isEmpty) {
            final isAr = Localizations.localeOf(context).languageCode == 'ar';
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    const Text("✋ "),
                    Text(isAr ? "خطوة للوراء!" : "Hold on!", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.orangeAccent : Colors.orange.shade800)),
                  ],
                ),
                content: Text(
                  isAr 
                    ? "ليكون متجرك مرتباً واحترافياً، يجب أن تنشئ (تصنيفاً) أولاً تضع تحته هذا المنتج (مثال: عصائر، حلى). دعنا ننشئ أول تصنيف الآن!"
                    : "To keep your store organized, you must create a (Category) first. Let's create one now!",
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, height: 1.5),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(isAr ? "إلغاء" : "Cancel", style: const TextStyle(fontFamily: 'Tajawal', color: Colors.grey)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/categories');
                    },
                    icon: const Icon(Icons.create_new_folder),
                    label: Text(isAr ? "إنشاء تصنيف" : "Create Category", style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
            return;
          }

          final canAdd = await GuestLimitService.canAddProduct(context, ref);
          if (!canAdd) return;

          if (context.mounted) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: const AddProductDialog(),
              ),
            );
          }
        },
        label: Text(l10n.add, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
      ) : null,
    );
  }
}
