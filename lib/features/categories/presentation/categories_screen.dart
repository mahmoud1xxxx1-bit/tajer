import 'package:tajer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/glass_card.dart';
import '../../../core/services/guest_limit_service.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../authentication/data/auth_repository.dart';
import '../../branches/domain/branch_operation_context.dart';
import '../../branches/presentation/branch_context.dart';
import '../data/category_repository.dart';
import '../../../core/services/pin_service.dart';
import '../../../core/widgets/pin_confirmation_dialog.dart';
import '../domain/category.dart';
import '../../../core/utils/date_formatter.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final appUser = ref.watch(appUserProvider).value;
    final canManageProducts =
        appUser?.hasPermission('can_manage_products') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.text39,
            style: TextStyle(fontFamily: 'Tajawal')),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined,
                      size: 80, color: Colors.blue.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    isAr ? "نظم متجرك!" : "Organize your store!",
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      isAr
                          ? "التصنيفات تساعدك في ترتيب منتجاتك (مثال: عصائر، حلى، طازج). أضف أول تصنيف الآن."
                          : "Categories help you organize your products (e.g. Juices, Sweets, Fresh). Add your first category now.",
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
            padding: EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.zero,
                onTap: canManageProducts
                    ? () => _showEditCategoryDialog(context, ref, category)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.category,
                            color: Colors.blue, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Tajawal',
                                  fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today_outlined,
                                        size: 14, color: Colors.teal),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppDateFormatter.format(
                                          category.createdAt),
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
                      if (canManageProducts)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final appUser = ref.read(appUserProvider).value;
                            if (appUser != null) {
                              final success =
                                  await PinConfirmationDialog.requirePinOrSetup(
                                context,
                                appUser,
                                title: isAr
                                    ? 'تحذير: حذف قسم رئيسي'
                                    : 'Warning: Delete Main Category',
                                warning: isAr
                                    ? 'حذف هذا القسم سيؤدي إلى جعل المنتجات التابعة له "بدون تصنيف".\nهل أنت متأكد من الحذف؟'
                                    : 'Deleting this category will make its products "Uncategorized".\nAre you sure?',
                              );
                              if (!success) return;
                            }
                            ref
                                .read(categoryRepositoryProvider)
                                ?.deleteCategory(
                                  category.id,
                                  context: BranchOperationContext(
                                    merchantId:
                                        currentEffectiveMerchantId(appUser!),
                                    branchId:
                                        ref.read(selectedBranchIdProvider),
                                  ),
                                );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: canManageProducts
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () async {
                final canAdd =
                    await GuestLimitService.canAddCategory(context, ref);
                if (!canAdd) return;
                if (context.mounted) _showAddCategoryDialog(context, ref);
              },
              child: Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.text41,
              style: TextStyle(fontFamily: 'Tajawal')),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.text42),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.text43),
            ),
            ElevatedButton(
              onPressed: () {
                final user = ref.read(authRepositoryProvider).currentUser;
                final appUser = ref.read(appUserProvider).value;
                if (user == null ||
                    appUser == null ||
                    nameController.text.isEmpty) return;

                final category = Category(
                  id: Uuid().v4(),
                  merchantId: currentEffectiveMerchantId(appUser),
                  name: nameController.text,
                  createdAt: DateTime.now(),
                );

                ref.read(categoryRepositoryProvider)?.addCategory(
                      category,
                      context: BranchOperationContext(
                        merchantId: currentEffectiveMerchantId(appUser),
                        branchId: ref.read(selectedBranchIdProvider),
                      ),
                    );
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.text44),
            ),
          ],
        );
      },
    );
  }

  void _showEditCategoryDialog(
      BuildContext context, WidgetRef ref, Category category) {
    final nameController = TextEditingController(text: category.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.text45,
              style: TextStyle(fontFamily: 'Tajawal')),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.text42),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.text43),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;

                final updatedCategory =
                    category.copyWith(name: nameController.text);
                ref.read(categoryRepositoryProvider)?.updateCategory(
                      updatedCategory,
                      context: BranchOperationContext(
                        merchantId: category.merchantId,
                        branchId: ref.read(selectedBranchIdProvider),
                      ),
                    );
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.text46),
            ),
          ],
        );
      },
    );
  }
}
