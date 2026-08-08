import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmployeeManagementHubScreen extends StatelessWidget {
  const EmployeeManagementHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'إدارة الموظفين' : 'Employee Management',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > 760 ? 720.0 : double.infinity;
            return Center(
              child: SizedBox(
                width: contentWidth,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ManagementCard(
                      icon: Icons.people_alt_rounded,
                      title: isAr
                          ? 'الموظفون والصلاحيات والأداء'
                          : 'Employees, Permissions & Performance',
                      description: isAr
                          ? 'إضافة الموظفين، تعديل الصلاحيات، مشاركة بيانات الدخول، ومراجعة أداء كل موظف.'
                          : 'Add employees, edit permissions, share login details, and review each employee’s performance.',
                      buttonText: isAr ? 'إدارة الموظفين' : 'Manage employees',
                      onPressed: () => context.push('/employees/manage'),
                    ),
                    const SizedBox(height: 14),
                    _ManagementCard(
                      icon: Icons.account_tree_rounded,
                      title: isAr
                          ? 'تعيين الموظفين للفروع'
                          : 'Assign Employees to Branches',
                      description: isAr
                          ? 'حدد الفروع التي يستطيع كل موظف العمل بها. يتم تطبيق هذا التقييد في الواجهة وفي قواعد الأمان.'
                          : 'Choose which branches each employee can work in. The restriction is enforced in both the UI and security rules.',
                      buttonText: isAr ? 'إدارة فروع الموظفين' : 'Manage employee branches',
                      onPressed: () => context.push('/employee_branches'),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isAr
                                    ? 'صلاحية الميزة وحدها لا تمنح الوصول لكل الفروع. يجب أن يملك الموظف الصلاحية المطلوبة وأن يكون الفرع معيّنًا له.'
                                    : 'A feature permission alone does not grant access to every branch. The employee must have both the required permission and an explicit branch assignment.',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;

  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Tajawal',
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                buttonText,
                style: const TextStyle(fontFamily: 'Tajawal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
