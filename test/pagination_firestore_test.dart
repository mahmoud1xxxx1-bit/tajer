import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tajer/features/customers/data/customer_repository.dart';
import 'package:tajer/features/suppliers/data/supplier_repository.dart';

void main() {
  group('Firestore pagination query behavior', () {
    test(
        'customer pages are bounded and debt/name/phone searches are independent of the first page',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CustomerRepository(firestore);
      const merchantId = 'merchant-pagination-test';

      for (var i = 0; i < 65; i++) {
        final id = 'customer_$i';
        await firestore.collection('customers').doc(id).set({
          'merchantId': merchantId,
          'name': i == 60
              ? 'Target Customer'
              : 'Customer ${i.toString().padLeft(2, '0')}',
          'phone': i == 62
              ? '0599999999'
              : '050000${i.toString().padLeft(4, '0')}',
          'totalDebt': i == 55 ? 250.0 : 0.0,
          'totalPurchases': 0.0,
          'orderCount': 0,
          'isActive': true,
          'createdAt': Timestamp.fromDate(
              DateTime(2026, 1, 1).add(Duration(days: i))),
        });
      }

      final firstPage =
          await repository.queryCustomers(merchantId: merchantId).limit(30).get();
      expect(firstPage.docs, hasLength(30));

      final debtPage = await repository
          .queryCustomers(merchantId: merchantId, hasDebt: true)
          .limit(30)
          .get();
      expect(debtPage.docs.map((doc) => doc.data().id), contains('customer_55'));

      final searchPage = await repository
          .queryCustomers(merchantId: merchantId, searchQuery: 'Target')
          .limit(30)
          .get();
      expect(searchPage.docs.map((doc) => doc.data().id), contains('customer_60'));

      final phonePage = await repository
          .queryCustomers(merchantId: merchantId, searchQuery: '059999')
          .limit(30)
          .get();
      expect(phonePage.docs.map((doc) => doc.data().id), contains('customer_62'));
    });

    test(
        'supplier pages are bounded and debt/search queries are independent of the first page',
        () async {
      final firestore = FakeFirebaseFirestore();
      const merchantId = 'merchant-supplier-pagination-test';
      final repository = SupplierRepository(firestore, merchantId);
      final suppliers = firestore
          .collection('merchants')
          .doc(merchantId)
          .collection('suppliers');

      for (var i = 0; i < 65; i++) {
        final id = 'supplier_$i';
        await suppliers.doc(id).set({
          'merchantId': merchantId,
          'name': i == 61
              ? 'Target Supplier'
              : 'Supplier ${i.toString().padLeft(2, '0')}',
          'phone': '050100${i.toString().padLeft(4, '0')}',
          'totalDebt': i == 56 ? 500.0 : 0.0,
          'isActive': true,
          'createdAt': Timestamp.fromDate(
              DateTime(2026, 1, 1).add(Duration(days: i))),
        });
      }

      final firstPage = await repository.querySuppliers().limit(30).get();
      expect(firstPage.docs, hasLength(30));

      final debtPage =
          await repository.querySuppliers(hasDebt: true).limit(30).get();
      expect(debtPage.docs.map((doc) => doc.data().id), contains('supplier_56'));

      final searchPage = await repository
          .querySuppliers(searchQuery: 'Target')
          .limit(30)
          .get();
      expect(searchPage.docs.map((doc) => doc.data().id), contains('supplier_61'));
    });
  });
}
