import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/core/services/data_migration_service.dart';

void main() {
  test('TEST 10/34 - guest workspace migrates completely and retry is idempotent', () async {
    final db = FakeFirebaseFirestore();
    final service = DataMigrationService(db);
    const oldMerchantId = 'qa_guest_old';
    const newMerchantId = 'qa_google_new';

    await db.collection('products').doc('p1').set({
      'merchantId': oldMerchantId,
      'name': 'Migrated Product',
      'quantity': 7,
    });
    await db.collection('orders').doc('o1').set({
      'merchantId': oldMerchantId,
      'total': 120.0,
    });
    await db.collection('customers').doc('c1').set({
      'merchantId': oldMerchantId,
      'name': 'Guest Customer',
    });

    final oldMerchant = db.collection('merchants').doc(oldMerchantId);
    final newMerchant = db.collection('merchants').doc(newMerchantId);

    await oldMerchant.collection('expenses').doc('keep-destination').set({
      'merchantId': oldMerchantId,
      'amount': 10.0,
      'origin': 'old',
    });
    await oldMerchant.collection('expenses').doc('move-expense').set({
      'merchantId': oldMerchantId,
      'amount': 25.0,
    });
    await newMerchant.collection('expenses').doc('keep-destination').set({
      'merchantId': newMerchantId,
      'amount': 999.0,
      'origin': 'destination',
    });

    await oldMerchant.collection('notebook_people').doc('person1').set({
      'merchantId': oldMerchantId,
      'name': 'Notebook Person',
    });

    final oldSupplier = oldMerchant.collection('suppliers').doc('s1');
    await oldSupplier.set({
      'merchantId': oldMerchantId,
      'name': 'Supplier One',
      'totalDebt': 300.0,
    });
    await oldSupplier.collection('transactions').doc('tx1').set({
      'merchantId': oldMerchantId,
      'supplierId': 's1',
      'amount': 50.0,
    });

    await db.collection('users').doc(oldMerchantId).collection('employees').doc('e1').set({
      'merchantId': oldMerchantId,
      'merchantUid': oldMerchantId,
      'name': 'Employee One',
    });

    expect(await service.migrateData(oldMerchantId, newMerchantId), isTrue);

    for (final path in <List<String>>[
      ['products', 'p1'],
      ['orders', 'o1'],
      ['customers', 'c1'],
    ]) {
      final doc = await db.collection(path[0]).doc(path[1]).get();
      expect(doc.data()?['merchantId'], newMerchantId, reason: '${path[0]}/${path[1]} ownership must move');
    }

    final migratedExpense = await newMerchant.collection('expenses').doc('move-expense').get();
    expect(migratedExpense.exists, isTrue);
    expect(migratedExpense.data()?['merchantId'], newMerchantId);
    expect(migratedExpense.data()?['amount'], 25.0);

    final preservedDestination = await newMerchant.collection('expenses').doc('keep-destination').get();
    expect(preservedDestination.data()?['amount'], 999.0, reason: 'Existing destination data must never be overwritten');
    expect(preservedDestination.data()?['origin'], 'destination');

    final migratedPerson = await newMerchant.collection('notebook_people').doc('person1').get();
    expect(migratedPerson.exists, isTrue);
    expect(migratedPerson.data()?['merchantId'], newMerchantId);

    final migratedSupplier = await newMerchant.collection('suppliers').doc('s1').get();
    expect(migratedSupplier.exists, isTrue);
    expect(migratedSupplier.data()?['merchantId'], newMerchantId);

    final migratedSupplierTx = await newMerchant
        .collection('suppliers')
        .doc('s1')
        .collection('transactions')
        .doc('tx1')
        .get();
    expect(migratedSupplierTx.exists, isTrue);
    expect(migratedSupplierTx.data()?['merchantId'], newMerchantId);
    expect(migratedSupplierTx.data()?['amount'], 50.0);

    final migratedEmployee = await db
        .collection('users')
        .doc(newMerchantId)
        .collection('employees')
        .doc('e1')
        .get();
    expect(migratedEmployee.exists, isTrue);
    expect(migratedEmployee.data()?['merchantId'], newMerchantId);
    expect(migratedEmployee.data()?['merchantUid'], newMerchantId);

    // Path-scoped source data intentionally remains so a failed merge can be retried safely.
    expect((await oldMerchant.collection('expenses').doc('move-expense').get()).exists, isTrue);
    expect((await oldSupplier.collection('transactions').doc('tx1').get()).exists, isTrue);

    // A second migration must be safe and must not create duplicates or overwrite destination data.
    expect(await service.migrateData(oldMerchantId, newMerchantId), isTrue);
    expect((await newMerchant.collection('expenses').get()).docs.length, 2);
    expect((await newMerchant.collection('suppliers').doc('s1').collection('transactions').get()).docs.length, 1);
    final destinationAfterRetry = await newMerchant.collection('expenses').doc('keep-destination').get();
    expect(destinationAfterRetry.data()?['amount'], 999.0);
  });
}
