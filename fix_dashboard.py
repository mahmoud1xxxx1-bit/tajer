with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

import re

# Fix Customers QuickAction
customers_qa = '''                      _QuickAction(
                        icon: Icons.person_outline,
                        label: l10n.customers,
                        color: Theme.of(context).colorScheme.secondary,
                        onTap: () {
                          onNavigateToTab(3);
                        },
                      ),'''
customers_qa_fixed = '''                      if (canManageCustomers)
                      _QuickAction(
                        icon: Icons.person_outline,
                        label: l10n.customers,
                        color: Theme.of(context).colorScheme.secondary,
                        onTap: () {
                          onNavigateToTab(3);
                        },
                      ),'''
content = content.replace(customers_qa, customers_qa_fixed)

# Fix Reports QuickAction
reports_qa = '''                      _QuickAction(
                        icon: Icons.bar_chart_rounded,
                        label: l10n.reports,
                        color: Colors.teal,
                        onTap: () {
                          onNavigateToTab(4);
                        },
                      ),'''
reports_qa_fixed = '''                      if (canViewReports)
                      _QuickAction(
                        icon: Icons.bar_chart_rounded,
                        label: l10n.reports,
                        color: Colors.teal,
                        onTap: () {
                          onNavigateToTab(canManageCustomers ? 4 : 3);
                        },
                      ),'''
content = content.replace(reports_qa, reports_qa_fixed)

with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed dashboard_screen.dart')
