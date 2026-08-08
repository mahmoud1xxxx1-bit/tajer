/// Central catalog for employee permissions.
///
/// The application and Firestore rules must use these stable keys. Keeping the
/// keys in one domain-level catalog prevents UI labels, authorization checks and
/// persisted employee documents from drifting apart over time.
abstract final class EmployeePermissionKeys {
  static const manageProducts = 'can_manage_products';
  static const viewCost = 'can_view_cost';
  static const manageInventory = 'can_manage_inventory';
  static const createOrders = 'can_create_orders';
  static const cancelOrders = 'can_cancel_orders';
  static const sellOnCredit = 'can_sell_on_credit';
  static const manageCustomers = 'can_manage_customers';
  static const receivePayments = 'can_receive_payments';
  static const manageExpenses = 'can_manage_expenses';
  static const viewReports = 'can_view_reports';
  static const viewAllOrders = 'can_view_all_orders';

  static const all = <String>{
    manageProducts,
    viewCost,
    manageInventory,
    createOrders,
    cancelOrders,
    sellOnCredit,
    manageCustomers,
    receivePayments,
    manageExpenses,
    viewReports,
    viewAllOrders,
  };
}

enum EmployeePermissionRisk { standard, sensitive, financial }

class EmployeePermissionDefinition {
  final String key;
  final EmployeePermissionRisk risk;
  final bool defaultEnabled;

  const EmployeePermissionDefinition({
    required this.key,
    required this.risk,
    required this.defaultEnabled,
  });
}

/// Least-privilege defaults used when creating a new employee.
///
/// Sensitive actions such as cost visibility, stock administration, order
/// cancellation and expense administration are deliberately opt-in.
abstract final class EmployeePermissionCatalog {
  static const definitions = <EmployeePermissionDefinition>[
    EmployeePermissionDefinition(
      key: EmployeePermissionKeys.createOrders,
      risk: EmployeePermissionRisk.standard,
      defaultEnabled: true,
    ),
    EmployeePermissionDefinition(
      key: EmployeePermissionKeys.manageCustomers,
      risk: EmployeePermissionRisk.standard,
      defaultEnabled: true,
    ),
    EmployeePermissionDefinition(
      key: EmployeePermissionKeys.receivePayments,
      risk: EmployeePermissionRisk.financial,
      defaultEnabled: true,
    ),
    EmployeePermissionDefinition(
      key: EmployeePermissionKeys.viewReports,
      risk: EmployeePermissionRisk.sensitive,
      defaultEnabled: true,
    ),
    EmployeePermissionDefinition(
      key: EmployeePermissionKeys.viewAllOrders,
      risk: EmployeePermissionRisk.sensitive,
      defaultEnabled: true,
    ),
    EmployeePermissionDefinition(
      key: EmployeePermissionKeys.manageProducts,
      risk: EmployeePermissionRisk.sensitive,
      defaultEnabled: false,
    ),
    EmployeePermissionDefinition(
      key: EmployeePermissionKeys.viewCost,
      risk: EmployeePermissionRisk.sensitive,
      defaultEnabled: false,
    ),
    EmployeePermissionDefinition(
      key: EmployeePermissionKeys.manageInventory,
      risk: EmployeePermissionRisk.sensitive,
      defaultEnabled: false,
    ),
    EmployeePermissionDefinition(
      key: EmployeePermissionKeys.cancelOrders,
      risk: EmployeePermissionRisk.financial,
      defaultEnabled: false,
    ),
    EmployeePermissionDefinition(
      key: EmployeePermissionKeys.sellOnCredit,
      risk: EmployeePermissionRisk.financial,
      defaultEnabled: false,
    ),
    EmployeePermissionDefinition(
      key: EmployeePermissionKeys.manageExpenses,
      risk: EmployeePermissionRisk.financial,
      defaultEnabled: false,
    ),
  ];

  static Map<String, bool> get leastPrivilegeDefaults => {
        for (final permission in definitions)
          permission.key: permission.defaultEnabled,
      };

  static bool isKnown(String key) => EmployeePermissionKeys.all.contains(key);
}
