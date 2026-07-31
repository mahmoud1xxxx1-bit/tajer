import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/raw_material.dart';
import '../data/raw_material_repository.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/app_user.dart';
import 'package:tajer/l10n/app_localizations.dart';

class RawMaterialsScreen extends ConsumerStatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  ConsumerState<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends ConsumerState<RawMaterialsScreen> {
  void _showAddEditDialog([RawMaterial? rawMaterial]) {
    final nameController = TextEditingController(text: rawMaterial?.name);
    final quantityController = TextEditingController(text: rawMaterial?.quantity != null ? rawMaterial!.quantity.toString() : '');
    String selectedUnit = rawMaterial?.unit ?? 'g';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(rawMaterial == null ? Icons.add_circle : Icons.edit, color: Colors.amber),
              const SizedBox(width: 10),
              Text(rawMaterial == null ? 'إضافة مادة خام جديدة' : 'تعديل مادة خام', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 ستستخدم هذه المادة لربطها بوجبات ومنتجات البيع ليتم الخصم التلقائي عند إصدار الفواتير.',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.amber),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم المادة الخام (مثال: لحم برجر، جبن، قهوة بن)',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: 'الكمية المتوفرة حالياً في المستودع',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  const Text('وحدة القياس:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.scale),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'g', child: Text('جرام (g) - للوزن مثل اللحوم والقهوة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
                      DropdownMenuItem(value: 'ml', child: Text('مللي (ml) - للسوائل والصلصات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
                      DropdownMenuItem(value: 'piece', child: Text('قطعة / حبة (piece) - للأكواب والخبز والعبوات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedUnit = val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 18),
              label: const Text('حفظ في المستودع', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final qty = double.tryParse(quantityController.text) ?? 0;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم المادة الخام أولاً', style: TextStyle(fontFamily: 'Tajawal'))));
                  return;
                }

                final user = ref.read(appUserProvider).value;
                final merchantId = user?.merchantId ?? user?.id;

                if (merchantId == null) return;

                final repo = ref.read(rawMaterialRepositoryProvider);

                if (rawMaterial == null) {
                  final newItem = RawMaterial(
                    id: const Uuid().v4(),
                    merchantId: merchantId,
                    name: name,
                    quantity: qty,
                    unit: selectedUnit,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await repo.addRawMaterial(newItem);
                } else {
                  final updatedItem = rawMaterial.copyWith(
                    name: name,
                    quantity: qty,
                    unit: selectedUnit,
                    updatedAt: DateTime.now(),
                  );
                  await repo.updateRawMaterial(updatedItem);
                }
                if (mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final merchantId = user?.merchantId ?? user?.id;
    final canManageInventory = user?.hasPermission('can_manage_inventory') ?? false;

    if (merchantId == null) return const Scaffold();

    final materialsAsync = ref.watch(rawMaterialsStreamProvider(merchantId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('المواد الخام (مستودع المكونات)', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: canManageInventory ? FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة مادة خام', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ) : null,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '💡 دليل المواد الخام: هنا يمكنك إضافة مكونات مستودعك (مثل: لحم برجر، جبن، أكواب، بن قهوة). عند ربط هذه المكونات بوصفات المنتجات في شاشة المنتجات، سيقوم النظام بخصم كمياتها تلقائياً عند كل عملية بيع لحماية مشروعك من الهدر ومعرفة التكلفة الحقيقية لأرباحك.',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, height: 1.5, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: materialsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (materials) {
                if (materials.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        const Text('لا توجد مواد خام في المستودع بعد.\nاضغط على زر "إضافة مادة خام" بالأسفل للبدء!', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: materials.length,
                  itemBuilder: (ctx, index) {
                    final item = materials[index];
                    String unitLabel = item.unit == 'g' ? 'جرام (g)' : item.unit == 'ml' ? 'مللي (ml)' : 'قطعة / حبة';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.withOpacity(0.2),
                          child: const Icon(Icons.inventory, color: Colors.amber),
                        ),
                        title: Text(item.name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('الرصيد المتوفر: ${item.quantity}  ($unitLabel)', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.amber)),
                        trailing: canManageInventory ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showAddEditDialog(item),
                              tooltip: 'تعديل',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'حذف',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Tajawal')),
                                    content: Text('هل أنت متأكد من حذف مادة "${item.name}" من المستودع؟', style: const TextStyle(fontFamily: 'Tajawal')),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal'))),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red, fontFamily: 'Tajawal', fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref.read(rawMaterialRepositoryProvider).deleteRawMaterial(item.id);
                                }
                              },
                            ),
                          ],
                        ) : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

