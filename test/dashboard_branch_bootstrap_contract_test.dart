import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard waits for app user and branch context before protected reads',
      () {
    final source =
        File('lib/features/dashboard/presentation/dashboard_screen.dart')
            .readAsStringSync();

    expect(source, contains('appUserState.isLoading'));
    expect(source, contains('branchContext.isReady'));
    expect(source, contains('CircularProgressIndicator'));
  });

  test('dashboard sales cards exclude cancelled and debt repayment records',
      () {
    final source =
        File('lib/features/dashboard/presentation/dashboard_screen.dart')
            .readAsStringSync();

    expect(source, contains("order.status != 'cancelled'"));
    expect(source, contains("order.status != 'debt_repayment'"));
    expect(source, contains('final totalSales'));
    expect(source, contains('final ordersCount'));
  });
}
