from pathlib import Path

# Dashboard: use a tested local-calendar-day metric instead of all-time totals.
p = Path('lib/features/dashboard/presentation/dashboard_screen.dart')
s = p.read_text(encoding='utf-8')
import_anchor = "import '../../reports/presentation/reports_screen.dart';\n"
import_line = "import '../domain/dashboard_daily_metrics.dart';\n"
if import_line not in s:
    if import_anchor not in s:
        raise SystemExit('dashboard import anchor not found')
    s = s.replace(import_anchor, import_anchor + import_line, 1)
old = """          final liveOrders = orders
              .where((order) =>
                  order.status != 'cancelled' &&
                  order.status != 'debt_repayment')
              .toList();
          final totalSales =
              liveOrders.fold<double>(0, (sum, order) => sum + order.total);
          final ordersCount = liveOrders.length;
"""
new = """          final dailyMetrics = DashboardDailyMetrics.fromOrders(orders);
          final totalSales = dailyMetrics.totalSales;
          final ordersCount = dailyMetrics.ordersCount;
"""
if old not in s:
    raise SystemExit('dashboard all-time metrics anchor not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# Reports UI: never present missing historical cost as a real zero or inflate profit.
p = Path('lib/features/reports/presentation/reports_screen.dart')
s = p.read_text(encoding='utf-8')
old_profit = """                          value:
                              '${reportsService.netProfit.toStringAsFixed(2)} ${currentCurrency.code}',
"""
new_profit = """                          value: reportsService.isCOGSComplete
                              ? '${reportsService.netProfit.toStringAsFixed(2)} ${currentCurrency.code}'
                              : (isAr ? 'غير مكتمل' : 'Incomplete'),
"""
if old_profit not in s:
    raise SystemExit('net profit card anchor not found')
s = s.replace(old_profit, new_profit, 1)
old_cogs = """                          value:
                              '${reportsService.totalCOGS.toStringAsFixed(2)} ${currentCurrency.code}',
"""
new_cogs = """                          value: reportsService.isCOGSComplete
                              ? '${reportsService.totalCOGS.toStringAsFixed(2)} ${currentCurrency.code}'
                              : (isAr ? 'غير مكتمل' : 'Incomplete'),
"""
if old_cogs not in s:
    raise SystemExit('COGS card anchor not found')
s = s.replace(old_cogs, new_cogs, 1)
p.write_text(s, encoding='utf-8')

# Rules: support canonical branch-scoped protected costs while preserving legacy docs.
p = Path('firestore.rules')
s = p.read_text(encoding='utf-8')
old_rules = """      match /product_costs/{productId} {
        allow read: if hasPermission(merchantId, 'can_view_cost');
        allow create, update: if hasPermission(merchantId, 'can_manage_products') &&
          hasPermission(merchantId, 'can_view_cost') &&
          request.resource.data.keys().hasOnly(['merchantId', 'productId', 'costPrice', 'updatedAt']) &&
          request.resource.data.get('merchantId', '') == merchantId &&
          request.resource.data.get('productId', '') == productId &&
          request.resource.data.get('costPrice', -1) is number &&
          request.resource.data.get('costPrice', -1) >= 0;
        allow delete: if hasPermission(merchantId, 'can_manage_products') &&
          hasPermission(merchantId, 'can_view_cost');
      }
"""
new_rules = """      match /product_costs/{costId} {
        allow read: if resource != null &&
          hasPermission(merchantId, 'can_view_cost') &&
          hasBranchAccess(merchantId, resource.data.get('branchId', 'main'));
        allow create, update: if hasPermission(merchantId, 'can_manage_products') &&
          hasPermission(merchantId, 'can_view_cost') &&
          request.resource.data.keys().hasOnly([
            'merchantId', 'branchId', 'productId', 'costPrice', 'updatedAt',
            'migratedFromLegacyProduct'
          ]) &&
          request.resource.data.get('merchantId', '') == merchantId &&
          request.resource.data.get('productId', '') is string &&
          request.resource.data.get('productId', '') != '' &&
          request.resource.data.get('costPrice', -1) is number &&
          request.resource.data.get('costPrice', -1) >= 0 &&
          (
            (request.resource.data.get('branchId', null) is string &&
             request.resource.data.get('branchId', '') != '' &&
             costId == request.resource.data.get('branchId', '') + '_' + request.resource.data.get('productId', '') &&
             hasBranchAccess(merchantId, request.resource.data.get('branchId', 'main'))) ||
            (request.resource.data.get('branchId', null) == null &&
             costId == request.resource.data.get('productId', '') &&
             hasBranchAccess(merchantId, 'main'))
          );
        allow delete: if resource != null &&
          hasPermission(merchantId, 'can_manage_products') &&
          hasPermission(merchantId, 'can_view_cost') &&
          hasBranchAccess(merchantId, resource.data.get('branchId', 'main'));
      }
"""
if old_rules not in s:
    raise SystemExit('product_costs rules anchor not found')
s = s.replace(old_rules, new_rules, 1)
p.write_text(s, encoding='utf-8')
