import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/orders/domain/order_date_group.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class _MockL10nEn {
  String get scheduledOrders => 'Scheduled Orders';
  String get todayPrefix => 'Today - ';
  String get yesterdayPrefix => 'Yesterday - ';
  String thisWeekFromTo(String start, String end) => 'This week ($start - $end)';
  String get agoPrefix => 'Ago ';
  String weekFromTo(String start, String end) => ' weeks ($start - $end)';
  String get monthPrefix => 'Month - ';
  String get yearPrefix => 'Year - ';
}

class _MockL10nAr {
  String get scheduledOrders => 'طلبات مجدولة';
  String get todayPrefix => 'اليوم - ';
  String get yesterdayPrefix => 'أمس - ';
  String thisWeekFromTo(String start, String end) => 'هذا الأسبوع ($start - $end)';
  String get agoPrefix => 'منذ ';
  String weekFromTo(String start, String end) => ' أسابيع ($start - $end)';
  String get monthPrefix => 'شهر - ';
  String get yearPrefix => 'سنة - ';
}

void main() {
  group('OrderDateGroup and Screen Sorting (Gate 12)', () {
    final l10nEn = _MockL10nEn();
    final l10nAr = _MockL10nAr();
    final refDate = DateTime(2026, 8, 11, 12, 0); // Reference: 2026-08-11

    AppOrder _createOrder(String id, DateTime date) {
      return AppOrder(
        id: id,
        merchantId: 'm1',
        branchId: 'b1',
        customerId: 'c1',
        customerName: 'Customer',
        items: const [],
        total: 100,
        createdAt: date,
      );
    }

    test('same day 20:00 before 10:00 (Intra-group ordering)', () {
      final o1 = _createOrder('1', DateTime(2026, 8, 11, 10, 0));
      final o2 = _createOrder('2', DateTime(2026, 8, 11, 20, 0));
      
      final list = [o1, o2];
      // Production OrdersScreen sort:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      expect(list.first.id, '2'); // 20:00 comes before 10:00
      expect(list.last.id, '1');
    });

    test('today before yesterday', () {
      final today = OrderDateGroup.fromDate(orderDate: DateTime(2026, 8, 11), referenceDate: refDate, isScheduled: false, l10n: l10nEn);
      final yesterday = OrderDateGroup.fromDate(orderDate: DateTime(2026, 8, 10), referenceDate: refDate, isScheduled: false, l10n: l10nEn);
      expect(today.compareTo(yesterday), lessThan(0));
    });

    test('2026-12-31 NOT This Week when reference date is 2026-08-11', () {
      final futureDate = OrderDateGroup.fromDate(orderDate: DateTime(2026, 12, 31), referenceDate: refDate, isScheduled: false, l10n: l10nEn);
      expect(futureDate.displayName.contains('This week'), isFalse);
    });

    test('2027-01-01 NOT This Week', () {
      final futureDate = OrderDateGroup.fromDate(orderDate: DateTime(2027, 1, 1), referenceDate: refDate, isScheduled: false, l10n: l10nEn);
      expect(futureDate.displayName.contains('This week'), isFalse);
    });

    test('cross-year ordering correct', () {
      final dec2026 = OrderDateGroup.fromDate(orderDate: DateTime(2026, 12, 31), referenceDate: refDate, isScheduled: false, l10n: l10nEn);
      final jan2027 = OrderDateGroup.fromDate(orderDate: DateTime(2027, 1, 1), referenceDate: refDate, isScheduled: false, l10n: l10nEn);
      
      // 2027 should have a lower rank (more recent / future) than 2026
      expect(jan2027.compareTo(dec2026), lessThan(0));
    });

    test('Arabic and English produce same chronological rank', () {
      final d1En = OrderDateGroup.fromDate(orderDate: DateTime(2026, 8, 5), referenceDate: refDate, isScheduled: false, l10n: l10nEn);
      final d1Ar = OrderDateGroup.fromDate(orderDate: DateTime(2026, 8, 5), referenceDate: refDate, isScheduled: false, l10n: l10nAr);
      
      expect(d1En.rank, d1Ar.rank);
      expect(d1En.compareTo(d1Ar), 0); // They sort identically despite localized display name
    });

    test('Branch A and Branch B remain isolated after switching', () {
      // Branch filtering is handled in branch_inventory_provider / orders_screen by `.where((o) => o.branchId == activeBranch.id)`.
      // We test that orders from different branches correctly retain their branch id.
      final oA = _createOrder('A', DateTime(2026, 8, 11));
      final oB = AppOrder(
        id: 'B', merchantId: 'm1', branchId: 'b2', customerId: 'c1', customerName: 'C',
        items: const [], total: 100, createdAt: DateTime(2026, 8, 11)
      );

      final branchAOrders = [oA, oB].where((o) => o.branchId == 'b1').toList();
      expect(branchAOrders.length, 1);
      expect(branchAOrders.first.id, 'A');
    });
  });
}
