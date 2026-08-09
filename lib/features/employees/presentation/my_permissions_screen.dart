import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/access_policy.dart';
import '../../authentication/application/session_identity.dart';
import '../domain/employee_permission_presentation.dart';

class MyPermissionsScreen extends ConsumerWidget {
  const MyPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final identity = ref.watch(sessionIdentityProvider);
    final policy = ref.watch(accessPolicyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'صلاحياتي' : 'My Permissions',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: identity == null || !policy.isEmployee
          ? Center(
              child: Text(
                isAr
                    ? 'هذه الصفحة مخصصة للموظفين.'
                    : 'This page is for employees.',
                style: const TextStyle(fontFamily: 'Tajawal'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InfoCard(
                  isAr: isAr,
                  branchCount: identity.assignedBranchIds.length,
                ),
                const SizedBox(height: 12),
                ...EmployeePermissionGroup.values.map((group) {
                  final items =
                      EmployeePermissionPresentationCatalog.forGroup(group);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _groupTitle(group, isAr),
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(),
                          ...items.map((item) {
                            final allowed =
                                identity.permissions[item.key] == true;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                allowed
                                    ? Icons.check_circle_rounded
                                    : Icons.block_rounded,
                                color: allowed
                                    ? Colors.green.shade700
                                    : theme.disabledColor,
                              ),
                              title: Text(
                                isAr ? item.titleAr : item.titleEn,
                                style: const TextStyle(fontFamily: 'Tajawal'),
                              ),
                              subtitle: Text(
                                allowed
                                    ? (isAr ? 'مسموح' : 'Allowed')
                                    : (isAr ? 'غير مسموح' : 'Not allowed'),
                                style: const TextStyle(fontFamily: 'Tajawal'),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  String _groupTitle(EmployeePermissionGroup group, bool isAr) {
    switch (group) {
      case EmployeePermissionGroup.sales:
        return isAr ? 'المبيعات والطلبات' : 'Sales & Orders';
      case EmployeePermissionGroup.customers:
        return isAr ? 'العملاء والتحصيل' : 'Customers & Collections';
      case EmployeePermissionGroup.inventory:
        return isAr ? 'المنتجات والمخزون' : 'Products & Inventory';
      case EmployeePermissionGroup.finance:
        return isAr ? 'المالية والمصروفات' : 'Finance & Expenses';
      case EmployeePermissionGroup.reports:
        return isAr ? 'التقارير والاطلاع' : 'Reports & Visibility';
    }
  }
}

class _InfoCard extends StatelessWidget {
  final bool isAr;
  final int branchCount;

  const _InfoCard({required this.isAr, required this.branchCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.verified_user_outlined,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isAr
                    ? 'هذه صلاحياتك الحالية. تتحدث تلقائيًا عند تعديلها من التاجر. عدد الفروع المسموحة: $branchCount'
                    : 'These are your current permissions. They update automatically when the merchant changes them. Assigned branches: $branchCount',
                style: const TextStyle(fontFamily: 'Tajawal', height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
