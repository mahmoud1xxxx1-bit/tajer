import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/application/access_policy.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/providers/effective_merchant.dart';
import '../../../core/providers/store_profile_provider.dart';
import '../data/branch_repository.dart';
import '../domain/branch.dart';
import 'active_branch_selector.dart';
import 'branch_context.dart';

class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  bool _ensuringMain = false;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final policy = ref.watch(accessPolicyProvider);
    final canManage = policy.canManageBranches;
    final theme = Theme.of(context);

    if (!canManage) {
      return Scaffold(
        appBar: AppBar(title: Text(isAr ? 'الفروع' : 'Branches')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              isAr
                  ? 'إدارة الفروع متاحة للمالك فقط.'
                  : 'Branch management is available to the owner only.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        ),
      );
    }

    final branchesAsync = ref.watch(branchesStreamProvider);
    final selectedBranchId = ref.watch(selectedBranchIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'الفروع' : 'Branches',
          style: const TextStyle(
              fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: isAr ? 'تحويل المخزون' : 'Transfer inventory',
            onPressed: () => context.push('/inventory_transfer'),
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBranchDialog(context),
        icon: const Icon(Icons.add_business_rounded),
        label: Text(isAr ? 'إضافة فرع' : 'Add branch'),
      ),
      body: branchesAsync.when(
        data: (branches) {
          if (branches.isEmpty && !_ensuringMain) {
            _ensureMainBranch();
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width =
                    constraints.maxWidth > 820 ? 760.0 : double.infinity;
                return Center(
                  child: SizedBox(
                    width: width,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      children: [
                        Text(
                          isAr ? 'إدارة الفروع' : 'Branch Management',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isAr
                              ? 'أنشئ الفروع، اختر الفرع الحالي، ثم أدِر المخزون والموظفين لكل فرع بوضوح.'
                              : 'Create branches, choose the active branch, then manage stock and employees per branch.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'Tajawal',
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const ActiveBranchSelector(),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    context.push('/inventory_transfer'),
                                icon: const Icon(Icons.swap_horiz_rounded),
                                label: Text(
                                  isAr ? 'تحويل المخزون' : 'Inventory transfer',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    context.push('/employee_branches'),
                                icon: const Icon(Icons.account_tree_rounded),
                                label: Text(
                                  isAr ? 'فروع الموظفين' : 'Employee branches',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/inventory_logs'),
                          icon: const Icon(Icons.inventory_2_rounded),
                          label: Text(
                            isAr
                                ? 'مخزون الفرع الحالي'
                                : 'Current branch inventory',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (branches.isEmpty)
                          _EmptyBranchesCard(isAr: isAr)
                        else
                          ...branches.map(
                            (branch) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _BranchTile(
                                branch: branch,
                                isSelected: branch.id == selectedBranchId,
                                isAr: isAr,
                                onSelect: branch.isActive
                                    ? () => ref
                                        .read(branchContextProvider.notifier)
                                        .selectBranch(branch.id)
                                    : null,
                                onEdit: () =>
                                    _showBranchDialog(context, branch: branch),
                                onToggleActive: branch.isMain
                                    ? null
                                    : () => _toggleBranch(branch),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              isAr
                  ? 'تعذر تحميل الفروع. تحقق من الاتصال وحاول مرة أخرى.'
                  : 'Could not load branches. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _ensureMainBranch() async {
    _ensuringMain = true;
    final repository = ref.read(branchRepositoryProvider);
    final storeProfile = ref.read(storeProfileProvider).value;
    if (repository != null) {
      await repository.ensureMainBranch(
        fallbackName: storeProfile?.storeName ?? 'Main Branch',
      );
    }
    if (mounted) _ensuringMain = false;
  }

  Future<void> _toggleBranch(Branch branch) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final selected = ref.read(selectedBranchIdProvider);
    if (branch.id == selected && branch.isActive) {
      await ref.read(branchContextProvider.notifier).resetToMain();
    }
    try {
      await ref
          .read(branchRepositoryProvider)
          ?.setBranchActive(branch.id, !branch.isActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تم تحديث حالة الفرع.' : 'Branch status updated.',
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'تعذر تحديث الفرع. لا يمكن تعطيل فرع رئيسي أو غير آمن.'
                : 'Could not update this branch. It may be protected.',
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
        ),
      );
    }
  }

  Future<void> _showBranchDialog(BuildContext context, {Branch? branch}) async {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: branch?.name ?? '');
    final phoneController = TextEditingController(text: branch?.phone ?? '');
    final addressController =
        TextEditingController(text: branch?.address ?? '');
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                branch == null
                    ? (isAr ? 'إضافة فرع' : 'Add branch')
                    : (isAr ? 'تعديل الفرع' : 'Edit branch'),
                style: const TextStyle(
                    fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: isAr ? 'اسم الفرع' : 'Branch name',
                          prefixIcon: const Icon(Icons.storefront_rounded),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.length < 2) {
                            return isAr
                                ? 'أدخل اسم فرع صحيح.'
                                : 'Enter a valid branch name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: isAr ? 'الهاتف اختياري' : 'Phone optional',
                          prefixIcon: const Icon(Icons.phone_rounded),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText:
                              isAr ? 'العنوان اختياري' : 'Address optional',
                          prefixIcon: const Icon(Icons.location_on_rounded),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: Text(isAr ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => saving = true);
                          final repository = ref.read(branchRepositoryProvider);
                          final appUser = ref.read(appUserProvider).value;
                          final merchantId = appUser == null
                              ? null
                              : currentEffectiveMerchantId(appUser);
                          if (repository == null || merchantId == null) return;
                          final now = DateTime.now();
                          final payload = Branch(
                            id: branch?.id ?? repository.newBranchId(),
                            merchantId: merchantId,
                            name: nameController.text.trim(),
                            isMain: branch?.isMain ?? false,
                            isActive: branch?.isActive ?? true,
                            phone: _optional(phoneController.text),
                            address: _optional(addressController.text),
                            createdAt: branch?.createdAt ?? now,
                            updatedAt: now,
                          );
                          try {
                            if (branch == null) {
                              await repository.addBranch(payload);
                              await ref
                                  .read(branchContextProvider.notifier)
                                  .selectBranch(payload.id);
                            } else {
                              await repository.updateBranch(payload);
                            }
                            if (!mounted || !dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isAr ? 'تم حفظ الفرع.' : 'Branch saved.',
                                  style: const TextStyle(fontFamily: 'Tajawal'),
                                ),
                              ),
                            );
                          } catch (_) {
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isAr
                                      ? 'تعذر حفظ الفرع. تحقق من الاسم والصلاحيات.'
                                      : 'Could not save branch. Check the name and permissions.',
                                  style: const TextStyle(fontFamily: 'Tajawal'),
                                ),
                              ),
                            );
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(isAr ? 'حفظ' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _BranchTile extends StatelessWidget {
  final Branch branch;
  final bool isSelected;
  final bool isAr;
  final VoidCallback? onSelect;
  final VoidCallback onEdit;
  final VoidCallback? onToggleActive;

  const _BranchTile({
    required this.branch,
    required this.isSelected,
    required this.isAr,
    required this.onSelect,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: branch.isActive
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                branch.isMain
                    ? Icons.storefront_rounded
                    : Icons.apartment_rounded,
                color: branch.isActive
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.disabledColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _StatusChip(
                        label: branch.isActive
                            ? (isAr ? 'نشط' : 'Active')
                            : (isAr ? 'غير نشط' : 'Inactive'),
                        color: branch.isActive ? Colors.green : Colors.grey,
                      ),
                      if (branch.isMain)
                        _StatusChip(
                          label: isAr ? 'رئيسي' : 'Main',
                          color: Colors.blue,
                        ),
                      if (isSelected)
                        _StatusChip(
                          label: isAr ? 'الفرع الحالي' : 'Current',
                          color: Colors.indigo,
                        ),
                    ],
                  ),
                  if ((branch.address ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      branch.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: isAr ? 'إجراءات الفرع' : 'Branch actions',
              onSelected: (value) {
                if (value == 'select') onSelect?.call();
                if (value == 'edit') onEdit();
                if (value == 'toggle') onToggleActive?.call();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'select',
                  enabled: onSelect != null,
                  child: Text(isAr ? 'اختيار كفرع حالي' : 'Set active branch'),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Text(isAr ? 'تعديل' : 'Edit'),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  enabled: onToggleActive != null,
                  child: Text(
                    branch.isActive
                        ? (isAr ? 'تعطيل' : 'Deactivate')
                        : (isAr ? 'تفعيل' : 'Activate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'Tajawal',
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyBranchesCard extends StatelessWidget {
  final bool isAr;

  const _EmptyBranchesCard({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.store_mall_directory_outlined, size: 42),
            const SizedBox(height: 10),
            Text(
              isAr
                  ? 'سيتم إنشاء الفرع الرئيسي تلقائيًا.'
                  : 'The main branch will be created automatically.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
          ],
        ),
      ),
    );
  }
}
