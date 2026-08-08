import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/auth_repository.dart';
import '../data/employee_permission_repository.dart';
import '../domain/employee_permission_catalog.dart';
import '../domain/employee_permission_presentation.dart';

class EmployeePermissionsScreen extends ConsumerWidget {
  const EmployeePermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final current = ref.watch(appUserProvider).value;
    final ownerAllowed = current?.role == 'merchant' || current?.role == 'admin';
    final merchantUid = FirebaseAuth.instance.currentUser?.uid;

    if (!ownerAllowed || merchantUid == null) {
      return Scaffold(
        appBar: AppBar(title: Text(isAr ? 'صلاحيات الموظفين' : 'Employee Permissions')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              isAr ? 'هذه الصفحة متاحة للتاجر فقط.' : 'This page is available to the merchant only.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'صلاحيات الموظفين' : 'Employee Permissions',
          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(merchantUid)
            .collection('employees')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(isAr ? 'تعذر تحميل الموظفين.' : 'Could not load employees.'));
          }
          final employees = snapshot.data?.docs ?? const [];
          if (employees.isEmpty) {
            return Center(child: Text(isAr ? 'لا يوجد موظفون بعد.' : 'No employees yet.'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > 840 ? 800.0 : double.infinity;
              return Center(
                child: SizedBox(
                  width: width,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.admin_panel_settings_outlined,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isAr
                                      ? 'امنح أقل قدر من الصلاحيات اللازمة للعمل. الصلاحيات المالية والحساسة موضحة بوضوح، ونطاق الفرع يظل شرطًا مستقلًا عن هذه الصلاحيات.'
                                      : 'Grant only the minimum permissions needed for the role. Financial and sensitive permissions are clearly marked, and branch access remains a separate requirement.',
                                  style: const TextStyle(fontFamily: 'Tajawal', height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...employees.map((doc) {
                        final data = doc.data();
                        final name = data['name']?.toString().trim();
                        return _EmployeePermissionCard(
                          employeeId: doc.id,
                          employeeName: (name == null || name.isEmpty)
                              ? (isAr ? 'موظف' : 'Employee')
                              : name,
                          rawPermissions: data['permissions'],
                          isAr: isAr,
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmployeePermissionCard extends ConsumerStatefulWidget {
  final String employeeId;
  final String employeeName;
  final dynamic rawPermissions;
  final bool isAr;

  const _EmployeePermissionCard({
    required this.employeeId,
    required this.employeeName,
    required this.rawPermissions,
    required this.isAr,
  });

  @override
  ConsumerState<_EmployeePermissionCard> createState() => _EmployeePermissionCardState();
}

class _EmployeePermissionCardState extends ConsumerState<_EmployeePermissionCard> {
  late Map<String, bool> permissions;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    permissions = _normalizedPermissions(widget.rawPermissions);
  }

  @override
  void didUpdateWidget(covariant _EmployeePermissionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawPermissions != widget.rawPermissions) {
      permissions = _normalizedPermissions(widget.rawPermissions);
    }
  }

  Map<String, bool> _normalizedPermissions(dynamic raw) {
    final result = Map<String, bool>.from(EmployeePermissionCatalog.leastPrivilegeDefaults);
    if (raw is Map) {
      for (final key in EmployeePermissionKeys.all) {
        if (raw.containsKey(key)) result[key] = raw[key] == true;
      }
    }
    return result;
  }

  String _groupTitle(EmployeePermissionGroup group) {
    switch (group) {
      case EmployeePermissionGroup.sales:
        return widget.isAr ? 'المبيعات والطلبات' : 'Sales & Orders';
      case EmployeePermissionGroup.customers:
        return widget.isAr ? 'العملاء والتحصيل' : 'Customers & Collections';
      case EmployeePermissionGroup.inventory:
        return widget.isAr ? 'المنتجات والمخزون' : 'Products & Inventory';
      case EmployeePermissionGroup.finance:
        return widget.isAr ? 'المالية والمصروفات' : 'Finance & Expenses';
      case EmployeePermissionGroup.reports:
        return widget.isAr ? 'التقارير والاطلاع' : 'Reports & Visibility';
    }
  }

  IconData _groupIcon(EmployeePermissionGroup group) {
    switch (group) {
      case EmployeePermissionGroup.sales:
        return Icons.point_of_sale_rounded;
      case EmployeePermissionGroup.customers:
        return Icons.people_alt_outlined;
      case EmployeePermissionGroup.inventory:
        return Icons.inventory_2_outlined;
      case EmployeePermissionGroup.finance:
        return Icons.account_balance_wallet_outlined;
      case EmployeePermissionGroup.reports:
        return Icons.analytics_outlined;
    }
  }

  EmployeePermissionRisk _riskFor(String key) {
    return EmployeePermissionCatalog.definitions
        .firstWhere((item) => item.key == key)
        .risk;
  }

  String _riskLabel(EmployeePermissionRisk risk) {
    switch (risk) {
      case EmployeePermissionRisk.standard:
        return widget.isAr ? 'عادية' : 'Standard';
      case EmployeePermissionRisk.sensitive:
        return widget.isAr ? 'حساسة' : 'Sensitive';
      case EmployeePermissionRisk.financial:
        return widget.isAr ? 'مالية' : 'Financial';
    }
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await ref.read(employeePermissionRepositoryProvider).updatePermissions(
            employeeId: widget.employeeId,
            permissions: Map<String, bool>.from(permissions),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isAr
              ? 'تم حفظ صلاحيات ${widget.employeeName} بنجاح.'
              : '${widget.employeeName} permissions saved successfully.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isAr
              ? 'تعذر حفظ الصلاحيات. لم يتم تطبيق أي تغيير جزئي، حاول مرة أخرى.'
              : 'Could not save permissions. No partial change was applied; please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ExpansionTile(
        leading: CircleAvatar(child: Text(widget.employeeName.characters.first.toUpperCase())),
        title: Text(
          widget.employeeName,
          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          widget.isAr ? 'اضغط لإدارة الصلاحيات بالتفصيل' : 'Tap to manage permissions in detail',
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        children: [
          ...EmployeePermissionGroup.values.map((group) {
            final items = EmployeePermissionPresentationCatalog.forGroup(group);
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(_groupIcon(group), color: theme.colorScheme.primary),
                      title: Text(
                        _groupTitle(group),
                        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 1),
                    ...items.map((item) {
                      final risk = _riskFor(item.key);
                      final title = widget.isAr ? item.titleAr : item.titleEn;
                      final description = widget.isAr ? item.descriptionAr : item.descriptionEn;
                      final isHighImpact = risk != EmployeePermissionRisk.standard;
                      return SwitchListTile.adaptive(
                        value: permissions[item.key] ?? false,
                        onChanged: saving
                            ? null
                            : (value) => setState(() => permissions[item.key] = value),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (isHighImpact)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _riskLabel(risk),
                                  style: theme.textTheme.labelSmall?.copyWith(fontFamily: 'Tajawal'),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            description,
                            style: const TextStyle(fontFamily: 'Tajawal', height: 1.4),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                widget.isAr ? 'حفظ الصلاحيات' : 'Save permissions',
                style: const TextStyle(fontFamily: 'Tajawal'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
