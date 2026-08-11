import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tajer/features/products/data/product_repository.dart';
import 'package:tajer/features/products/data/product_cost_repository.dart';
import 'package:tajer/features/products/domain/product.dart';
import 'package:tajer/features/authentication/domain/app_user.dart';
import 'package:tajer/core/providers/effective_merchant.dart';
import 'package:tajer/features/branches/data/branch_repository.dart';
import 'package:tajer/features/branches/data/branch_inventory_repository.dart';
import 'package:tajer/features/branches/domain/branch_inventory.dart';
import 'package:tajer/features/authentication/data/auth_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:tajer/features/branches/presentation/branch_context.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

class MockFirebaseCore extends FirebasePlatform {
  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return FirebaseAppPlatform(
      name ?? '[DEFAULT]',
      options ?? const FirebaseOptions(
        apiKey: '123',
        appId: '123',
        messagingSenderId: '123',
        projectId: '123',
      ),
    );
  }

  @override
  FirebaseAppPlatform app([String name = '[DEFAULT]']) {
    return FirebaseAppPlatform(
      name,
      const FirebaseOptions(
        apiKey: '123',
        appId: '123',
        messagingSenderId: '123',
        projectId: '123',
      ),
    );
  }
}

Future<AsyncValue<List<Product>>> waitForData(ProviderContainer container, [bool Function(List<Product>)? predicate]) async {
  for (int i = 0; i < 100; i++) {
    final state = container.read(productsStreamProvider);
    if (state is AsyncData && state.value != null && state.value!.isNotEmpty) {
      if (predicate == null || predicate(state.value!)) return state;
    }
    if (state is AsyncError) throw state.error!;
    await Future.delayed(const Duration(milliseconds: 50));
  }
  return container.read(productsStreamProvider);
}

class MockProductRepository extends ProductRepository {
  MockProductRepository(super.firestore);

  @override
  Future<bool> isBranchCatalogMigrationCompleted({required String merchantId, required String branchId}) async {
    return true;
  }
}

class MockFirebaseAuthPlatform extends FirebaseAuthPlatform {
  MockFirebaseAuthPlatform() : super(appInstance: Firebase.app());
  
  @override
    FirebaseAuthPlatform delegateFor({FirebaseApp? app}) {
    return this;
  }
  
  @override
  UserPlatform? get currentUser => null;
  
  @override
  FirebaseAuthPlatform setInitialValues({
    bool? isLanguageCodeSet,
    String? languageCode,
    dynamic currentUser,
    String? tenantId,
  }) {
    return this;
  }
}
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FirebasePlatform.instance = MockFirebaseCore();
    
    // Mock Pigeon for FirebaseAuth
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerAuthStateListener',
      (ByteData? message) async {
        return const StandardMessageCodec().encodeMessage(null);
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerIdTokenListener',
      (ByteData? message) async {
        return const StandardMessageCodec().encodeMessage(null);
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.useEmulator',
      (ByteData? message) async {
        return const StandardMessageCodec().encodeMessage(null);
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.currentUser',
      (ByteData? message) async {
        return const StandardMessageCodec().encodeMessage(null);
      },
    );

    await Firebase.initializeApp();
FirebaseAuthPlatform.instance = MockFirebaseAuthPlatform();
  });

  group('productsStream behavioral tests', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;
    late StreamController<AppUser?> authController;
    AppUser? currentUser;

    final owner = AppUser(
      id: 'merchant1', 
      merchantId: 'merchant1',
      role: 'merchant',
      permissions: {'can_view_cost': true},
      createdAt: DateTime.now(),
    );

    final employee = AppUser(
      id: 'emp1',
      merchantId: 'merchant1',
      role: 'employee',
      assignedBranchIds: ['main'],
      permissions: {'can_view_cost': false},
      createdAt: DateTime.now(),
    );

    Stream<AppUser?> appUserMockStream() async* {
      yield currentUser;
      await for (final user in authController.stream) {
        yield user;
      }
    }

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      authController = StreamController<AppUser?>.broadcast();
      currentUser = owner;

      container = ProviderContainer(
        overrides: [
          appUserProvider.overrideWith((ref) => appUserMockStream()),
          selectedBranchIdProvider.overrideWith((ref) => 'main'),
          productRepositoryProvider.overrideWithValue(MockProductRepository(firestore)),
          productCostRepositoryProvider.overrideWithValue(ProductCostRepository(firestore)),
          branchInventoryRepositoryProvider.overrideWithValue(BranchInventoryRepository(firestore, 'merchant1')),
        ],
      );
      
      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('migration_state')
          .doc('global_catalog_migration_v1')
          .set({'status': 'completed'});
          
      await firestore.collection('merchants').doc('merchant1').collection('branches').doc('main').collection('migration_state').doc('branch_catalog_migration').set({'status': 'completed'});
          
      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('migration_state')
          .doc('legacy_product_visibility_v1_main')
          .set({'status': 'completed'});
    });

    tearDown(() {
      container.dispose();
      authController.close();
    });

    test('A. Loading inventory must NOT produce authoritative quantity 0', () async {
      currentUser = owner;
      
      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branches')
          .doc('main')
          .collection('products')
          .doc('prod1')
          .set({
        'name': 'Juice',
        'isArchived': false,
        'taxMode': 'inclusive',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'price': 10.0,
      });

      final sub = container.listen(productsStreamProvider, (prev, next) {});
      
      await Future.delayed(const Duration(milliseconds: 100));
      final state = container.read(productsStreamProvider);
      
      expect(state, isA<AsyncLoading>());
      
      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branch_inventory')
          .doc('main_product_prod1')
          .set({
        'branchId': 'main',
        'itemType': 'product',
        'itemId': 'prod1',
        'quantity': 70,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
            final snap = await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branches')
          .doc('main')
          .collection('products')
          .get();

      final resolved = await waitForData(container, (v) => v.first.quantity == 70);
      expect(resolved.value!.first.quantity, 70);
      
      sub.close();
    });

    test('B. Inventory ready at 70 -> productsStream emits 70, C. changes to 69', () async {
      currentUser = owner;
      
      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branches')
          .doc('main')
          .collection('products')
          .doc('prod1')
          .set({
        'name': 'Juice',
        'isArchived': false,
        'taxMode': 'inclusive',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'price': 10.0,
      });

      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branch_inventory')
          .doc('main_product_prod1')
          .set({
        'branchId': 'main',
        'itemType': 'product',
        'itemId': 'prod1',
        'quantity': 70,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final sub = container.listen(productsStreamProvider, (prev, next) {});
      
      var state = await waitForData(container);
      expect(state.value!.first.quantity, 70);

      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branch_inventory')
          .doc('main_product_prod1')
          .update({'quantity': 69});

      state = await waitForData(container, (products) => products.first.quantity == 69);
      expect(state.value!.first.quantity, 69);
      sub.close();
    });

    test('D. Cost reactivity', () async {
      currentUser = owner;
      
      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branches')
          .doc('main')
          .collection('products')
          .doc('prod1')
          .set({
        'name': 'Juice',
        'isArchived': false,
        'taxMode': 'inclusive',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'price': 10.0,
      });

      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branch_inventory')
          .doc('main_product_prod1')
          .set({
        'branchId': 'main',
        'itemType': 'product',
        'itemId': 'prod1',
        'quantity': 70,
      });

      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('product_costs')
          .doc('main_prod1')
          .set({
        'costPrice': 5.0,
      });

      final sub = container.listen(productsStreamProvider, (prev, next) {});
      
      var state = await waitForData(container);
      expect(state.value!.first.costPrice, 5.0);

      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('product_costs')
          .doc('main_prod1')
          .update({'costPrice': 6.0});

      state = await waitForData(container, (products) => products.first.costPrice == 6.0);
      expect(state.value!.first.costPrice, 6.0);
      
      sub.close();
    });

    test('E. Product Snapshot reactivity', () async {
      currentUser = owner;
      
      final sub = container.listen(productsStreamProvider, (prev, next) {});
      
      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branches')
          .doc('main')
          .collection('products')
          .doc('prodA')
          .set({
        'name': 'A',
        'isArchived': false,
        'taxMode': 'inclusive',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'price': 10.0,
      });

      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branch_inventory')
          .doc('main_product_prodA')
          .set({'branchId': 'main',
        'itemType': 'product', 'itemId': 'prodA', 'quantity': 70});

      var state = await waitForData(container, (products) => products.length == 1);
      expect(state.value!.length, 1);
      expect(state.value!.first.name, 'A');

      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branches')
          .doc('main')
          .collection('products')
          .doc('prodB')
          .set({
        'name': 'B',
        'isArchived': false,
        'taxMode': 'inclusive',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'price': 10.0,
      });
      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branch_inventory')
          .doc('main_product_prodB')
          .set({'branchId': 'main',
        'itemType': 'product', 'itemId': 'prodB', 'quantity': 70});

      for (int i = 0; i < 40; i++) {
        state = container.read(productsStreamProvider);
        if (state is AsyncData && state.value != null && state.value!.length == 2) break;
        await Future.delayed(const Duration(milliseconds: 50));
      }
      expect(state.value!.length, 2);
      expect(state.value!.map((p) => p.name).contains('B'), true);
      sub.close();
    });

    test('F. Identity isolation owner -> employee -> owner false zero check', () async {
      currentUser = owner;
      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branches')
          .doc('main')
          .collection('products')
          .doc('prod1')
          .set({
        'name': 'Juice',
        'isArchived': false,
        'taxMode': 'inclusive',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'price': 10.0,
      });

      await firestore
          .collection('merchants')
          .doc('merchant1')
          .collection('branch_inventory')
          .doc('main_product_prod1')
          .set({
        'branchId': 'main',
        'itemType': 'product',
        'itemId': 'prod1',
        'quantity': 70,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      bool everSawZero = false;
      final sub = container.listen(productsStreamProvider, (prev, next) {
        if (next is AsyncData && next.value != null && next.value!.isNotEmpty) {
          if (next.value!.first.quantity == 0) {
            everSawZero = true;
          }
        }
      });

      var state = await waitForData(container);
      expect(state.value!.first.quantity, 70);

      authController.add(employee);
      state = await waitForData(container, (products) => products.isNotEmpty);
      expect(state.value!.first.quantity, 70);

      authController.add(owner);
      state = await waitForData(container, (products) => products.isNotEmpty);
      expect(state.value!.first.quantity, 70);

      expect(everSawZero, false);
      sub.close();
    });
  });
}
















