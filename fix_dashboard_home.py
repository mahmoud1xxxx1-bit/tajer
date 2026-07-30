import re

with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I will pass canManageCustomers and canViewReports to DashboardHome.
# And inside DashboardHome, calculate the index.

target_dashboard_call = "DashboardHome(onNavigateToTab: (index) {"
replace_dashboard_call = '''DashboardHome(
        canManageCustomers: canManageCustomers,
        canViewReports: canViewReports,
        onNavigateToTab: (index) {'''

content = content.replace(target_dashboard_call, replace_dashboard_call)

target_dashboard_class = '''class DashboardHome extends ConsumerWidget {
  final void Function(int) onNavigateToTab;
  const DashboardHome({super.key, required this.onNavigateToTab});'''
replace_dashboard_class = '''class DashboardHome extends ConsumerWidget {
  final void Function(int) onNavigateToTab;
  final bool canManageCustomers;
  final bool canViewReports;
  const DashboardHome({super.key, required this.onNavigateToTab, required this.canManageCustomers, required this.canViewReports});'''

content = content.replace(target_dashboard_class, replace_dashboard_class)

# Now, hide the quick actions in DashboardHome
# We need to conditionally add _QuickAction for customers and reports.

quick_actions_target = '''                    _QuickAction(
                      label: l10n.products,
                      color: Colors.deepPurpleAccent,
                      onTap: () {
                        onNavigateToTab(2);
                      },
                    ),
                    _QuickAction(
                      label: l10n.customers,
                      color: Theme.of(context).colorScheme.secondary,
                      onTap: () {
                        onNavigateToTab(3);
                      },
                    ),
                    _QuickAction(
                      label: l10n.reports,
                      color: Colors.teal,
                      onTap: () {
                        onNavigateToTab(4);
                      },
                    ),'''

quick_actions_replace = '''                    _QuickAction(
                      label: l10n.products,
                      color: Colors.deepPurpleAccent,
                      onTap: () {
                        onNavigateToTab(2);
                      },
                    ),
                    if (canManageCustomers)
                      _QuickAction(
                        label: l10n.customers,
                        color: Theme.of(context).colorScheme.secondary,
                        onTap: () {
                          onNavigateToTab(3); // Wait, this index will be dynamically handled in _DashboardScreenState, but currently _DashboardScreenState uses the raw index!
                        },
                      ),
                    if (canViewReports)
                      _QuickAction(
                        label: l10n.reports,
                        color: Colors.teal,
                        onTap: () {
                          onNavigateToTab(canManageCustomers ? 4 : 3);
                        },
                      ),'''

content = content.replace(quick_actions_target, quick_actions_replace)

with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('DashboardHome fixed')
