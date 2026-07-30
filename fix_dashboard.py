import re

with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace screens logic
screens_target = '''  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final List<Widget> screens = [
      DashboardHome(onNavigateToTab: (index) {
        setState(() {
          _currentIndex = index;
        });
      }),
      const OrdersScreen(),
      const ProductsScreen(),
      const CustomersScreen(),
      const ReportsScreen(),
    ];'''

screens_replacement = '''  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appUser = ref.watch(appUserProvider).value;
    
    final bool canManageCustomers = appUser?.hasPermission('can_manage_customers') ?? true;
    final bool canViewReports = appUser?.hasPermission('can_view_reports') ?? true;

    final List<Widget> screens = [
      DashboardHome(onNavigateToTab: (index) {
        setState(() {
          _currentIndex = index;
        });
      }),
      const OrdersScreen(),
      const ProductsScreen(),
      if (canManageCustomers) const CustomersScreen(),
      if (canViewReports) const ReportsScreen(),
    ];'''

content = content.replace(screens_target, screens_replacement)

destinations_target = '''        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: l10n.dashboard,
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: l10n.orders,
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: l10n.products,
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: l10n.customers,
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: l10n.reports,
          ),
        ],'''

destinations_replacement = '''        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: l10n.dashboard,
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: l10n.orders,
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: l10n.products,
          ),
          if (canManageCustomers)
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: l10n.customers,
            ),
          if (canViewReports)
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: l10n.reports,
            ),
        ],'''

content = content.replace(destinations_target, destinations_replacement)

with open('lib/features/dashboard/presentation/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Updated Dashboard screen successfully!')
