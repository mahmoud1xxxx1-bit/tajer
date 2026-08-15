import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/features/accounting_notebook/data/accounting_notebook_provider.dart';
import 'package:tajer/features/accounting_notebook/data/accounting_notebook_repository.dart';

void main() {
  group('Accounting Notebook Isolation and Atomicity Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AccountingNotebookRepository repository;
    late AccountingNotebookService service;
    const merchantId = 'test_owner_123';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = AccountingNotebookRepository(fakeFirestore, merchantId);
      service = AccountingNotebookService(repository);
    });

    test('Strict Isolation: Notebook transactions do not affect POS collections', () async {
      // 1. Setup baseline in POS collections
      final posCollections = [
        'orders', 'products', 'raw_materials', 'shifts', 'customers',
        'suppliers', 'expenses', 'payments', 'inventory_logs', 'employee_actions'
      ];

      for (var col in posCollections) {
        await fakeFirestore.collection('merchants').doc(merchantId).collection(col).add({'baseline': true});
      }

      // Capture baseline counts
      Map<String, int> baselineCounts = {};
      for (var col in posCollections) {
        final snap = await fakeFirestore.collection('merchants').doc(merchantId).collection(col).get();
        baselineCounts[col] = snap.docs.length;
      }

      // 2. Perform Notebook Operations
      await repository.accountsRef.doc('acc1').set({'id': 'acc1', 'name': 'Cash', 'balance': 0.0});
      await repository.peopleRef.doc('p1').set({'id': 'p1', 'name': 'John', 'amountOwedToMe': 0.0, 'amountIOwe': 0.0});

      await service.createIncome(
        bookId: 'b1',
        accountId: 'acc1',
        amount: 500,
        categoryId: 'c1',
      );

      await service.createDebt(
        bookId: 'b1',
        personId: 'p1',
        amount: 200,
        isOwedToMe: true,
      );

      // 3. Verify Isolation
      for (var col in posCollections) {
        final snap = await fakeFirestore.collection('merchants').doc(merchantId).collection(col).get();
        expect(snap.docs.length, equals(baselineCounts[col]), reason: 'POS Collection $col was modified!');
      }

      // 4. Verify Notebook state
      final accSnap = await repository.accountsRef.doc('acc1').get();
      expect(accSnap.data()?['balance'], equals(500.0));
      
      final txSnap = await repository.transactionsRef.get();
      expect(txSnap.docs.length, equals(2));
    });

    test('Atomicity: Debt partial payment updates both Person and Account simultaneously', () async {
      await repository.accountsRef.doc('acc1').set({'id': 'acc1', 'name': 'Cash', 'balance': 1000.0, 'bookId': 'b1'});
      await repository.peopleRef.doc('p1').set({'id': 'p1', 'name': 'John', 'amountOwedToMe': 500.0, 'amountIOwe': 0.0});

      await service.recordDebtPayment(
        bookId: 'b1',
        personId: 'p1',
        accountId: 'acc1',
        amount: 200.0,
        isReceivablePayment: true,
      );

      final pSnap = await repository.peopleRef.doc('p1').get();
      final accSnap = await repository.accountsRef.doc('acc1').get();

      // Debt reduced by 200
      expect(pSnap.data()?['amountOwedToMe'], equals(300.0));
      // Account increased by 200
      expect(accSnap.data()?['balance'], equals(1200.0));
    });
    
    test('Atomicity: Transfer funds between accounts updates both correctly', () async {
      await repository.accountsRef.doc('acc1').set({'id': 'acc1', 'name': 'Cash', 'balance': 1000.0, 'bookId': 'b1'});
      await repository.accountsRef.doc('acc2').set({'id': 'acc2', 'name': 'Bank', 'balance': 500.0, 'bookId': 'b1'});

      await service.transferFunds(
        bookId: 'b1',
        fromAccountId: 'acc1',
        toAccountId: 'acc2',
        amount: 300.0,
      );

      final acc1Snap = await repository.accountsRef.doc('acc1').get();
      final acc2Snap = await repository.accountsRef.doc('acc2').get();

      expect(acc1Snap.data()?['balance'], equals(700.0));
      expect(acc2Snap.data()?['balance'], equals(800.0));
    });
  });
}
