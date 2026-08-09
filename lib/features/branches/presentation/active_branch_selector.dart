import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/branch_repository.dart';
import 'branch_context.dart';

class ActiveBranchSelector extends ConsumerWidget {
  final bool compact;

  const ActiveBranchSelector({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final selectedBranchId = ref.watch(selectedBranchIdProvider);
    final branchesAsync = ref.watch(branchesStreamProvider);
    final theme = Theme.of(context);

    return branchesAsync.when(
      data: (branches) {
        final activeBranches = branches.where((b) => b.isActive).toList();
        final selected = activeBranches.where((b) => b.id == selectedBranchId);

        if (activeBranches.isEmpty) {
          return _BranchPill(
            icon: Icons.storefront_rounded,
            label: isAr ? 'الفرع الحالي: الرئيسي' : 'Active branch: Main',
            compact: compact,
          );
        }

        final selectedBranch =
            selected.isNotEmpty ? selected.first : activeBranches.first;

        return Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.18)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedBranch.id,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: activeBranches.map((branch) {
                return DropdownMenuItem<String>(
                  value: branch.id,
                  child: Row(
                    children: [
                      Icon(
                        branch.isMain
                            ? Icons.storefront_rounded
                            : Icons.apartment_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          compact
                              ? branch.name
                              : '${isAr ? 'الفرع الحالي' : 'Active branch'}: ${branch.name}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                ref.read(branchContextProvider.notifier).selectBranch(value);
              },
            ),
          ),
        );
      },
      loading: () => _BranchPill(
        icon: Icons.storefront_rounded,
        label: isAr ? 'تحميل الفرع...' : 'Loading branch...',
        compact: compact,
      ),
      error: (_, __) => _BranchPill(
        icon: Icons.error_outline_rounded,
        label: isAr ? 'تعذر تحميل الفرع' : 'Branch unavailable',
        compact: compact,
      ),
    );
  }
}

class _BranchPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;

  const _BranchPill({
    required this.icon,
    required this.label,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
