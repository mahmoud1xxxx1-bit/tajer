import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  group('Long-lived Firestore pagination contracts', () {
    test('customers use 30-item Firestore pages without eager 1000-customer UI stream', () {
      final source = read('lib/features/customers/presentation/customers_screen.dart');
      expect(source, contains('pageSize: 30'));
      expect(source, isNot(contains('customersStreamProvider')));
      expect(source, contains('.queryCustomers(merchantId: user.merchantId ?? user.id)'));
    });

    test('orders use 50-item Firestore pages', () {
      final source = read('lib/features/orders/presentation/orders_screen.dart');
      expect(source, contains('pageSize: 50'));
    });

    test('customer statement starts at 50 and can load 50 more', () {
      final screen = read('lib/features/customers/presentation/customer_statement_screen.dart');
      final provider = read('lib/features/customers/data/customer_statement_provider.dart');
      expect(screen, contains('int _limit = 50'));
      expect(screen, contains('_limit += 50'));
      expect(provider, contains('.limit(safeLimit)'));
      expect(provider, contains('items.take(safeLimit)'));
    });

    test('supplier list uses 30-item Firestore pages', () {
      final source = read('lib/features/suppliers/presentation/suppliers_screen.dart');
      expect(source, contains('pageSize: 30'));
    });

    test('expense history uses 50-item Firestore pages', () {
      final source = read('lib/features/expenses/presentation/expenses_screen.dart');
      expect(source, contains('pageSize: 50'));
    });

    test('shift archive uses 30-item Firestore pages', () {
      final source = read('lib/features/shifts/presentation/shifts_archive_screen.dart');
      expect(source, contains('pageSize: 30'));
    });

    test('paginated screens do not expose raw Firestore errors', () {
      for (final path in [
        'lib/features/customers/presentation/customers_screen.dart',
        'lib/features/customers/presentation/customer_statement_screen.dart',
        'lib/features/orders/presentation/orders_screen.dart',
        'lib/features/suppliers/presentation/suppliers_screen.dart',
        'lib/features/expenses/presentation/expenses_screen.dart',
        'lib/features/shifts/presentation/shifts_archive_screen.dart',
      ]) {
        final source = read(path);
        expect(source, isNot(contains("Text('حدث خطأ: \$error")), reason: path);
        expect(source, isNot(contains("Text('\${l10n.error}: \$error")), reason: path);
      }
    });
  });
}
