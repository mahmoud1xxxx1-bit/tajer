import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/l10n/app_localizations.dart';
import 'package:tajer/l10n/onboarding_l10n.dart';
import '../../../core/theme/glass_card.dart';
import '../../categories/data/category_repository.dart';
import '../../products/data/product_repository.dart';
import '../../shifts/data/shift_repository.dart';
import '../../orders/data/order_repository.dart';
import '../../authentication/domain/app_user.dart';
import '../../authentication/data/auth_repository.dart';
import 'package:go_router/go_router.dart';

class SetupChecklistCard extends ConsumerWidget {
  final void Function(int) onNavigateToTab;

  const SetupChecklistCard({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName == 'ar';
    final appUser = ref.watch(appUserProvider).value;

    if (appUser?.role == 'employee') return const SizedBox.shrink();

    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final currentShiftAsync = ref.watch(currentShiftProvider(appUser?.merchantId ?? appUser?.id ?? ''));
    final ordersAsync = ref.watch(ordersStreamProvider);

    final bool hasCategories = (categoriesAsync.value?.length ?? 0) > 0;
    final bool hasProducts = (productsAsync.value?.length ?? 0) > 0;
    final bool hasShift = currentShiftAsync.value != null;
    final bool hasSales = (ordersAsync.value?.length ?? 0) > 0;

    int completedSteps = 0;
    if (hasCategories) completedSteps++;
    if (hasProducts) completedSteps++;
    if (hasShift) completedSteps++;
    if (hasSales) completedSteps++;

    final double progress = completedSteps / 4.0;

    if (progress == 1.0) {
      return const SizedBox.shrink(); // Hide forever once completed
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: GlassCard(
        key: ValueKey(progress),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rocket_launch_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    OnboardingL10n.get('setupChecklistTitle', isAr),
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            _buildStepItem(
              context,
              isCompleted: hasCategories,
              title: OnboardingL10n.get('setupStep1', isAr),
              icon: Icons.category,
              onTap: () => context.push('/categories'),
            ),
            _buildStepItem(
              context,
              isCompleted: hasProducts,
              title: OnboardingL10n.get('setupStep2', isAr),
              icon: Icons.inventory_2,
              onTap: () => onNavigateToTab(2), // Navigate to Products tab
            ),
            _buildStepItem(
              context,
              isCompleted: hasShift,
              title: OnboardingL10n.get('setupStep3', isAr),
              icon: Icons.point_of_sale,
              onTap: () => context.push('/start_shift'),
            ),
            _buildStepItem(
              context,
              isCompleted: hasSales,
              title: OnboardingL10n.get('setupStep4', isAr),
              icon: Icons.receipt_long,
              onTap: () => onNavigateToTab(1), // Navigate to Orders tab
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(BuildContext context, {required bool isCompleted, required String title, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: isCompleted ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCompleted ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  color: isCompleted ? Colors.grey : Theme.of(context).colorScheme.onSurface,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (!isCompleted)
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
