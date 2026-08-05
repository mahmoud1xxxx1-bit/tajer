import os

# 1. Fix order_details_screen.dart
order_file = 'lib/features/orders/presentation/order_details_screen.dart'
with open(order_file, 'r', encoding='utf-8') as f:
    order_content = f.read()

get_payment_method = '''
  String _getPaymentMethodName(BuildContext context, String method) {
    final l10n = AppLocalizations.of(context)!;
    switch (method) {
      case 'cash': return l10n.cash;
      case 'card': return l10n.card;
      case 'transfer': return l10n.transfer;
      default: return l10n.unknown;
    }
  }
'''
if '_getPaymentMethodName(' in order_content and 'String _getPaymentMethodName' not in order_content:
    # Insert it right after "class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {"
    target = 'class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {'
    order_content = order_content.replace(target, target + '\n' + get_payment_method)
    with open(order_file, 'w', encoding='utf-8') as f:
        f.write(order_content)

# 2. Fix end_shift_screen.dart
shift_file = 'lib/features/shifts/presentation/end_shift_screen.dart'
with open(shift_file, 'r', encoding='utf-8') as f:
    shift_content = f.read()

if 'import \'package:intl/intl.dart\';' not in shift_content:
    shift_content = 'import \'package:intl/intl.dart\';\n' + shift_content

shift_content = shift_content.replace('shift.openedByName', 'shift.employeeName')
shift_content = shift_content.replace('shift.openingCash', 'shift.startCash')
shift_content = shift_content.replace('shift.madaSales', 'shift.cardTotal ?? 0.0')
shift_content = shift_content.replace('shift.transferSales', 'shift.transferTotal ?? 0.0')
shift_content = shift_content.replace('shift.cashSales', 'shift.cashSales ?? 0.0')
# Remove creditSales row
lines = shift_content.split('\n')
new_lines = [l for l in lines if 'creditSales' not in l]
shift_content = '\n'.join(new_lines)

with open(shift_file, 'w', encoding='utf-8') as f:
    f.write(shift_content)

# 3. Fix customers_screen.dart
customers_file = 'lib/features/customers/presentation/customers_screen.dart'
with open(customers_file, 'r', encoding='utf-8') as f:
    cust_content = f.read()

getter = '  AppLocalizations get l10n => AppLocalizations.of(context)!;'
target = 'class _CustomersScreenState extends ConsumerState<CustomersScreen> {'
if getter not in cust_content:
    cust_content = cust_content.replace(target, target + '\n' + getter)
    with open(customers_file, 'w', encoding='utf-8') as f:
        f.write(cust_content)

print('FIXED!')
