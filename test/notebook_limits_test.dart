import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:tajer/core/services/limits_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late LimitsService limitsService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    limitsService = LimitsService(fakeFirestore);
  });

  group('Notebook Limits Tests - Guest', () {
    final guestUser = AppUser(
      id: 'guest1',
      plan: 'guest',
      isAnonymous: true,
      role: 'merchant',
      createdAt: DateTime.now(),
    );

    test('Guest: 1 Book allowed, 2nd rejected', () async {
      expect(await limitsService.canAddNotebookBook(guestUser), isTrue);
      await fakeFirestore.collection('merchants').doc('guest1').collection('notebook_books').add({'name': 'Book 1'});
      expect(await limitsService.canAddNotebookBook(guestUser), isFalse);
    });

    test('Guest: 1 Account allowed, 2nd rejected', () async {
      expect(await limitsService.canAddNotebookAccount(guestUser), isTrue);
      await fakeFirestore.collection('merchants').doc('guest1').collection('notebook_accounts').add({'name': 'Acc 1'});
      expect(await limitsService.canAddNotebookAccount(guestUser), isFalse);
    });

    test('Guest: 2 People allowed, 3rd rejected', () async {
      expect(await limitsService.canAddNotebookPerson(guestUser), isTrue);
      await fakeFirestore.collection('merchants').doc('guest1').collection('notebook_people').add({'name': 'Person 1'});
      expect(await limitsService.canAddNotebookPerson(guestUser), isTrue);
      await fakeFirestore.collection('merchants').doc('guest1').collection('notebook_people').add({'name': 'Person 2'});
      expect(await limitsService.canAddNotebookPerson(guestUser), isFalse);
    });

    test('Guest: 5 Transactions allowed, 6th rejected', () async {
      for (int i = 0; i < 5; i++) {
        expect(await limitsService.canAddNotebookTransaction(guestUser), isTrue);
        await fakeFirestore.collection('merchants').doc('guest1').collection('notebook_transactions').add({'amount': 10});
      }
      expect(await limitsService.canAddNotebookTransaction(guestUser), isFalse);
    });
  });

  group('Notebook Limits Tests - Merchant Free', () {
    final freeUser = AppUser(
      id: 'free1',
      plan: 'free',
      isAnonymous: false,
      role: 'merchant',
      createdAt: DateTime.now(),
    );

    test('Free: 2 Books allowed, 3rd rejected', () async {
      expect(await limitsService.canAddNotebookBook(freeUser), isTrue);
      await fakeFirestore.collection('merchants').doc('free1').collection('notebook_books').add({'name': 'Book 1'});
      expect(await limitsService.canAddNotebookBook(freeUser), isTrue);
      await fakeFirestore.collection('merchants').doc('free1').collection('notebook_books').add({'name': 'Book 2'});
      expect(await limitsService.canAddNotebookBook(freeUser), isFalse);
    });

    test('Free: 2 Accounts allowed, 3rd rejected', () async {
      expect(await limitsService.canAddNotebookAccount(freeUser), isTrue);
      await fakeFirestore.collection('merchants').doc('free1').collection('notebook_accounts').add({'name': 'Acc 1'});
      expect(await limitsService.canAddNotebookAccount(freeUser), isTrue);
      await fakeFirestore.collection('merchants').doc('free1').collection('notebook_accounts').add({'name': 'Acc 2'});
      expect(await limitsService.canAddNotebookAccount(freeUser), isFalse);
    });

    test('Free: 5 People allowed, 6th rejected', () async {
      for (int i = 0; i < 5; i++) {
        expect(await limitsService.canAddNotebookPerson(freeUser), isTrue);
        await fakeFirestore.collection('merchants').doc('free1').collection('notebook_people').add({'name': 'Person $i'});
      }
      expect(await limitsService.canAddNotebookPerson(freeUser), isFalse);
    });

    test('Free: 20 Transactions allowed, 21st rejected', () async {
      for (int i = 0; i < 20; i++) {
        expect(await limitsService.canAddNotebookTransaction(freeUser), isTrue);
        await fakeFirestore.collection('merchants').doc('free1').collection('notebook_transactions').add({'amount': 10});
      }
      expect(await limitsService.canAddNotebookTransaction(freeUser), isFalse);
    });
  });

  group('Notebook Limits Tests - Premium', () {
    final premiumUser = AppUser(
      id: 'pro1',
      plan: 'pro',
      isAnonymous: false,
      role: 'merchant',
      createdAt: DateTime.now(),
    );

    test('Premium: Unlimited Books', () async {
      for (int i = 0; i < 10; i++) {
        expect(await limitsService.canAddNotebookBook(premiumUser), isTrue);
        await fakeFirestore.collection('merchants').doc('pro1').collection('notebook_books').add({'name': 'Book $i'});
      }
    });

    test('Premium: Unlimited Transactions', () async {
      for (int i = 0; i < 50; i++) {
        expect(await limitsService.canAddNotebookTransaction(premiumUser), isTrue);
        await fakeFirestore.collection('merchants').doc('pro1').collection('notebook_transactions').add({'amount': 10});
      }
    });
  });

  group('Notebook Limits Tests - Employee', () {
    final employeeUser = AppUser(
      id: 'emp1',
      merchantId: 'free_merchant',
      plan: 'employee',
      isAnonymous: false,
      role: 'employee',
      createdAt: DateTime.now(),
    );

    test('Employee inherits free merchant limits', () async {
      // Create merchant doc
      await fakeFirestore.collection('users').doc('free_merchant').set({
        'plan': 'free',
        'isAnonymous': false,
        'email': 'merchant@test.com',
      });

      // Allowed initially
      expect(await limitsService.canAddNotebookBook(employeeUser), isTrue);
      await fakeFirestore.collection('merchants').doc('free_merchant').collection('notebook_books').add({'name': 'Book 1'});
      expect(await limitsService.canAddNotebookBook(employeeUser), isTrue);
      await fakeFirestore.collection('merchants').doc('free_merchant').collection('notebook_books').add({'name': 'Book 2'});
      
      // Limit reached
      expect(await limitsService.canAddNotebookBook(employeeUser), isFalse);
    });
  });
}
