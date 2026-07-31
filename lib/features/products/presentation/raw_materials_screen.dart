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
    final quantityController = TextEditingController(text: rawMaterial?.quantity.toString());
    final unitController = TextEditingController(text: rawMaterial?.unit ?? 'g');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(rawMaterial == null ? 'إضافة مادة خام' : 'تعديل مادة خام', style: const TextStyle(fontFamily: 'Tajawal')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم المادة (مثال: لحم برجر)'),
            ),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'الكمية المتوفرة'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(labelText: 'الوحدة (g, ml, piece)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.text42, style: const TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final qty = double.tryParse(quantityController.text) ?? 0;
              final unit = unitController.text.trim();

              if (name.isEmpty || unit.isEmpty) return;

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
                  unit: unit,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await repo.addRawMaterial(newItem);
              } else {
                final updatedItem = rawMaterial.copyWith(
                  name: name,
                  quantity: qty,
                  unit: unit,
                  updatedAt: DateTime.now(),
                );
                await repo.updateRawMaterial(updatedItem);
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: Text('حفظ', style: const TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final merchantId = user?.merchantId ?? user?.id;

    if (merchantId == null) return const Scaffold();

    final materialsAsync = ref.watch(rawMaterialsStreamProvider(merchantId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('المواد الخام (المخزون)', style: TextStyle(fontFamily: 'Tajawal')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: materialsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (materials) {
          if (materials.isEmpty) {
            return const Center(child: Text('لا توجد مواد خام بعد.', style: TextStyle(fontFamily: 'Tajawal')));
          }
          return ListView.builder(
            itemCount: materials.length,
            itemBuilder: (ctx, index) {
              final item = materials[index];
              return ListTile(
                title: Text(item.name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                subtitle: Text('الكمية: ${item.quantity} ${item.unit}', style: const TextStyle(fontFamily: 'Tajawal')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showAddEditDialog(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Tajawal')),
                            content: const Text('هل أنت متأكد من حذف هذه المادة؟', style: TextStyle(fontFamily: 'Tajawal')),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(rawMaterialRepositoryProvider).deleteRawMaterial(item.id);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
