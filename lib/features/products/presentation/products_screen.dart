import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import '../data/product_repository.dart';
import 'add_product_dialog.dart';
import '../../../core/services/app_error_mapper.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../../../core/widgets/tajer_message.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/activity_logger.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/utils/date_formatter.dart';
import '../../categories/data/category_repository.dart';
import 'package:go_router/go_router.dart';
import '../../branches/presentation/active_branch_selector.dart';
import '../../branches/domain/branch_operation_context.dart';
import '../../branches/presentation/branch_context.dart';
import '../../authentication/application/access_policy.dart';
import '../../branches/domain/branch.dart';
import '../../branches/data/branch_repository.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final productsAsyncValue = ref.watch(productsStreamProvider);
    final currentCurrency = ref.watch(currencyProvider);
    final appUser = ref.watch(appUserProvider).value;
    final policy = ref.watch(accessPolicyProvider);
    final canManageProducts =
        appUser?.hasPermission('can_manage_products') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.products, style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ActiveBranchSelector(compact: true),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.indigo.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: Colors.amber, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.localeName == 'ar'
                        ? '💡 دليل المنتجات: أضف أصناف وجباتك أو بضائعك هنا. يمكنك ربط المنتج بالمواد الخام (المكونات) ليتم الخصم التلقائي من المستودع عند البيع في شاشة الـ POS.'
                        : '💡 Products Guide: Add your inventory items or meals here. You can link a product to raw materials for automatic deduction from inventory when sold via POS.',
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        height: 1.4,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: productsAsyncValue.when(
              data: (products) {
                if (products.isEmpty) {
                  final isAr = l10n.localeName == 'ar';
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 80, color: Colors.indigo.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          isAr ? "متجرك فارغ!" : "Your store is empty!",
                          style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            isAr
                                ? "لا يوجد منتجات بعد! أضف بضاعتك للرفوف لتبدأ البيع فوراً."
                                : "No products yet! Add your inventory to the shelves to start selling immediately.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: products.length,
                  padding: EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.zero,
                      onLongPress: canManageProducts
                          ? () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(context)
                                        .viewInsets
                                        .bottom,
                                  ),
                                  child:
                                      AddProductDialog(productToEdit: product),
                                ),
                              );
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.inventory_2_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Tajawal',
                                        fontSize: 16),
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
                                            color: (!product
                                                        .isManufacturedOnDemand &&
                                                    product.quantity <= 5)
                                                ? Colors.red
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            product.isManufacturedOnDemand
                                                ? 'يُصنع عند الطلب'
                                                : '${l10n.quantity}: ${product.quantity}',
                                            style: TextStyle(
                                              fontFamily: 'Tajawal',
                                              color: (!product
                                                          .isManufacturedOnDemand &&
                                                      product.quantity <= 5)
                                                  ? Colors.red
                                                  : Colors.grey[700],
                                              fontWeight: (!product
                                                          .isManufacturedOnDemand &&
                                                      product.quantity <= 5)
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (!product.isManufacturedOnDemand &&
                                              product.quantity <= 5) ...[
                                            const SizedBox(width: 4),
                                            const Icon(
                                                Icons.warning_amber_rounded,
                                                color: Colors.red,
                                                size: 14),
                                          ],
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 14,
                                              color: Colors.teal),
                                          const SizedBox(width: 4),
                                          Text(
                                            AppDateFormatter.format(
                                                product.createdAt),
                                            style: const TextStyle(
                                                fontFamily: 'Tajawal',
                                                color: Colors.teal,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${product.price} ${currentCurrency.code}',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (canManageProducts)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert,
                                        color: Colors.grey),
                                    padding: EdgeInsets.zero,
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (context) => Padding(
                                            padding: EdgeInsets.only(
                                              bottom: MediaQuery.of(context)
                                                  .viewInsets
                                                  .bottom,
                                            ),
                                            child: AddProductDialog(
                                                productToEdit: product),
                                          ),
                                        );
                                      } else if (value == 'copy_branch') {
                                        final branchesVal = ref.read(branchesStreamProvider).value;
                                        if (branchesVal == null || branchesVal.isEmpty) return;
                                        final currentBranchId = ref.read(selectedBranchIdProvider);
                                        final availableBranches = branchesVal.where((b) => b.id != currentBranchId).toList();
                                        if (availableBranches.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No other branches available.')));
                                          return;
                                        }
                                        final selectedBranch = await showDialog<Branch>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'اختر الفرع' : 'Select Branch', style: const TextStyle(fontFamily: 'Tajawal')),
                                            content: SizedBox(
                                              width: double.maxFinite,
                                              child: ListView.builder(
                                                shrinkWrap: true,
                                                itemCount: availableBranches.length,
                                                itemBuilder: (ctx, i) => ListTile(
                                                  title: Text(availableBranches[i].name, style: const TextStyle(fontFamily: 'Tajawal')),
                                                  onTap: () => Navigator.pop(ctx, availableBranches[i]),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                        if (selectedBranch != null) {
                                          try {
                                            await ref.read(productRepositoryProvider).copyProductToBranch(
                                              product: product,
                                              targetBranchId: selectedBranch.id,
                                            );
                                            if (context.mounted) {
                                              TajerMessage.success(context, AppErrorMapper.success(
                                                ar: 'تم نسخ المنتج بنجاح',
                                                en: 'Product copied successfully'
                                              ));
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              await TajerMessage.show(context, AppErrorMapper.fromError(e, domain: 'product'));
                                            }
                                          }
                                        }
                                      } else if (value == 'remove_branch' ||
                                          value == 'archive_store') {
                                        final appUser =
                                            ref.read(appUserProvider).value;
                                        final branchId =
                                            ref.read(selectedBranchIdProvider);
                                        final isArabic =
                                            Localizations.localeOf(context)
                                                    .languageCode ==
                                                'ar';
                                        if (appUser != null) {
                                          final success =
                                              await PinConfirmationDialog
                                                  .requirePinOrSetup(
                                            context,
                                            appUser,
                                            title: isArabic
                                                ? (value == 'archive_store'
                                                    ? 'أرشفة المنتج من المتجر'
                                                    : 'إزالة من هذا الفرع')
                                                : (value == 'archive_store'
                                                    ? 'Archive product from store'
                                                    : 'Remove from this branch'),
                                            warning: isArabic
                                                ? (value == 'archive_store'
                                                    ? 'سيتم إخفاء المنتج من كل الفروع مع حفظ الفواتير السابقة. هل تريد المتابعة؟'
                                                    : 'سيتم إخفاء المنتج من هذا الفرع فقط دون التأثير على الفروع الأخرى أو الفواتير السابقة.')
                                                : (value == 'archive_store'
                                                    ? 'This hides the product from all branches while preserving past invoices. Continue?'
                                                    : 'This hides the product from this branch only without affecting other branches or historical invoices.'),
                                          );
                                          if (!success) return;
                                        }
                                        try {
                                          final repo = ref
                                              .read(productRepositoryProvider);
                                          if (value == 'archive_store') {
                                            await repo.archiveProductFromStore(
                                              context: BranchOperationContext(
                                                merchantId: product.merchantId,
                                                branchId: branchId,
                                              ),
                                              productId: product.id,
                                            );
                                          } else {
                                            await repo.removeProductFromBranch(
                                              context: BranchOperationContext(
                                                merchantId: product.merchantId,
                                                branchId: branchId,
                                              ),
                                              productId: product.id,
                                            );
                                          }
                                          ActivityLogger.log(
                                            user: appUser,
                                            actionType: value == 'archive_store'
                                                ? 'Archive Product'
                                                : 'Remove Product From Branch',
                                            description: value ==
                                                    'archive_store'
                                                ? 'Archived product'
                                                : 'Removed product from branch',
                                          );
                                          if (context.mounted) {
                                            TajerMessage.success(
                                              context,
                                              AppErrorMapper.success(
                                                ar: value == 'archive_store'
                                                    ? 'تمت أرشفة المنتج'
                                                    : 'تمت إزالة المنتج من هذا الفرع',
                                                en: value == 'archive_store'
                                                    ? 'Product archived'
                                                    : 'Product removed from this branch',
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            await TajerMessage.show(
                                              context,
                                              AppErrorMapper.fromError(e,
                                                  domain: 'product'),
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
                                            const Icon(Icons.edit,
                                                size: 20, color: Colors.blue),
                                            const SizedBox(width: 8),
                                            Text(l10n.edit,
                                                style: const TextStyle(
                                                    fontFamily: 'Tajawal')),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'copy_branch',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.copy, color: Colors.green, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                                Localizations.localeOf(context).languageCode == 'ar'
                                                    ? 'نسخ إلى فرع آخر'
                                                    : 'Copy to another branch',
                                                style: const TextStyle(color: Colors.green, fontFamily: 'Tajawal')),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'remove_branch',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.remove_circle,
                                                color: Colors.orange, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                                Localizations.localeOf(context)
                                                            .languageCode ==
                                                        'ar'
                                                    ? 'إزالة من هذا الفرع'
                                                    : 'Remove from this branch',
                                                style: const TextStyle(
                                                    color: Colors.orange,
                                                    fontFamily: 'Tajawal')),
                                          ],
                                        ),
                                      ),
                                      if (policy.isOwnerLike)
                                        PopupMenuItem(
                                          value: 'archive_store',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.archive,
                                                  color: Colors.red, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                  Localizations.localeOf(
                                                                  context)
                                                              .languageCode ==
                                                          'ar'
                                                      ? 'أرشفة المنتج من المتجر'
                                                      : 'Archive product from store',
                                                  style: const TextStyle(
                                                      color: Colors.red,
                                                      fontFamily: 'Tajawal')),
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
                child: Text('${l10n.error}: $e',
                    style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: canManageProducts
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () async {
                final categories = ref.read(categoriesStreamProvider).value;
                if (categories == null || categories.isEmpty) {
                  final isAr =
                      Localizations.localeOf(context).languageCode == 'ar';
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: Row(
                        children: [
                          const Text("✋ "),
                          Text(isAr ? "خطوة للوراء!" : "Hold on!",
                              style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.orangeAccent
                                      : Colors.orange.shade800)),
                        ],
                      ),
                      content: Text(
                        isAr
                            ? "ليكون متجرك مرتباً واحترافياً، يجب أن تنشئ (تصنيفاً) أولاً تضع تحته هذا المنتج (مثال: عصائر، حلى). دعنا ننشئ أول تصنيف الآن!"
                            : "To keep your store organized, you must create a (Category) first. Let's create one now!",
                        style: const TextStyle(
                            fontFamily: 'Tajawal', fontSize: 15, height: 1.5),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(isAr ? "إلغاء" : "Cancel",
                              style: const TextStyle(
                                  fontFamily: 'Tajawal', color: Colors.grey)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.push('/categories');
                          },
                          icon: const Icon(Icons.create_new_folder),
                          label: Text(isAr ? "إنشاء تصنيف" : "Create Category",
                              style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                final canAdd =
                    await GuestLimitService.canAddProduct(context, ref);
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
              label: Text(l10n.add,
                  style: TextStyle(
                      fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              icon: Icon(Icons.add),
            )
          : null,
    );
  }
}
