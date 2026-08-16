import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  group('Long-lived Firestore pagination contracts', () {
    test(
        'customers use 30-item Firestore pages without eager 1000-customer UI stream',
        () {
      final source =
          read('lib/features/customers/presentation/customers_screen.dart');
      expect(source, contains('pageSize: 30'));
      expect(source, isNot(contains('customersStreamProvider')));
      expect(source,
          contains('.queryCustomers(merchantId: user.merchantId ?? user.id)'));
    });

    test('customer search supports both names and phone numbers in Firestore',
        () {
      final source = read('lib/features/customers/data/customer_repository.dart');
      expect(source, contains("final field = isPhoneSearch ? 'phone' : 'name'"));
      expect(source, contains('.orderBy(field)'));
    });

    test('orders use 50-item Firestore pages', () {
      final source =
          read('lib/features/orders/presentation/orders_screen.dart');
      expect(source, contains('pageSize: 50'));
    });

    test('customer statement starts at 50 and can load 50 more', () {
      final screen = read(
          'lib/features/customers/presentation/customer_statement_screen.dart');
      final provider =
          read('lib/features/customers/data/customer_statement_provider.dart');
      expect(screen, contains('int _limit = 50'));
      expect(screen, contains('_limit += 50'));
      expect(provider, contains('.limit(safeLimit)'));
      expect(provider, contains('items.take(safeLimit)'));
    });

    test('supplier list uses 30-item Firestore pages', () {
      final source =
          read('lib/features/suppliers/presentation/suppliers_screen.dart');
      expect(source, contains('pageSize: 30'));
    });

    test('expense history uses 50-item Firestore pages', () {
      final source =
          read('lib/features/expenses/presentation/expenses_screen.dart');
      expect(source, contains('pageSize: 50'));
    });

    test('shift archive uses 30-item Firestore pages', () {
      final source =
          read('lib/features/shifts/presentation/shifts_archive_screen.dart');
      expect(source, contains('pageSize: 30'));
    });

    test('notebook people are queried per book in 30-item pages', () {
      final source = read(
          'lib/features/accounting_notebook/presentation/notebook_people_screen.dart');
      expect(source, contains(".where('bookId', isEqualTo: selectedBookId)"));
      expect(source, contains('pageSize: 30'));
      expect(source, isNot(contains('ref.watch(notebookPeopleProvider)')));
    });

    test(
        'notebook person statement reads one person and paginates that persons transactions',
        () {
      final source = read(
          'lib/features/accounting_notebook/presentation/notebook_person_statement_screen.dart');
      expect(source, contains('.doc(personId).snapshots()'));
      expect(source, contains('repository.queryTransactions('));
      expect(source, contains('bookId: person.bookId'));
      expect(source, contains('personId: personId'));
      expect(source, contains('pageSize: 50'));
      expect(source, isNot(contains('ref.watch(notebookTransactionsProvider)')));
    });

    test('notebook transaction history pages one selected book 50 at a time',
        () {
      final source = read(
          'lib/features/accounting_notebook/presentation/notebook_transactions_screen.dart');
      expect(source, contains('repository.queryTransactions('));
      expect(source, contains('bookId: _selectedBookId!'));
      expect(source, contains('pageSize: 50'));
      expect(source, isNot(contains('ref.watch(notebookTransactionsProvider)')));
    });

    test(
        'notebook reports query the selected book and period instead of the global transaction stream',
        () {
      final source = read(
          'lib/features/accounting_notebook/presentation/notebook_reports_screen.dart');
      expect(source, contains("String _period = 'month'"));
      expect(source, contains(".where('bookId', isEqualTo: selectedBookId)"));
      expect(
          source,
          contains(
              ".where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))"));
      expect(source, isNot(contains('ref.watch(notebookTransactionsProvider)')));
    });

    test('paginated screens do not expose raw Firestore errors', () {
      for (final path in [
        'lib/features/customers/presentation/customers_screen.dart',
        'lib/features/customers/presentation/customer_statement_screen.dart',
        'lib/features/orders/presentation/orders_screen.dart',
        'lib/features/suppliers/presentation/suppliers_screen.dart',
        'lib/features/expenses/presentation/expenses_screen.dart',
        'lib/features/shifts/presentation/shifts_archive_screen.dart',
        'lib/features/accounting_notebook/presentation/notebook_transactions_screen.dart',
      ]) {
        final source = read(path);
        expect(source, isNot(contains("Text('حدث خطأ: \$error")), reason: path);
        expect(source, isNot(contains("Text('\${l10n.error}: \$error")),
            reason: path);
      }
    });
  });
}
