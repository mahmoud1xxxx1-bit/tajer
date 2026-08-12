import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/data/auth_repository.dart';
import '../../features/branches/domain/branch.dart';
import '../../features/categories/data/category_repository.dart';
import '../../features/products/data/product_repository.dart';
import '../../features/products/data/raw_material_repository.dart';
import '../providers/effective_merchant.dart';

class BranchCatalogMigrationFailure implements Exception {
  final String merchantId;
  final String branchId;
  final String step;
  final String firestorePath;
  final String? firebaseCode;
  final Object cause;

  const BranchCatalogMigrationFailure({
    required this.merchantId,
    required this.branchId,
    required this.step,
    required this.firestorePath,
    required this.firebaseCode,
    required this.cause,
  });

  @override
  String toString() => 'BranchCatalogMigrationFailure(merchantId: $merchantId, '
      'branchId: $branchId, step: $step, firestorePath: $firestorePath, '
      'firebaseCode: $firebaseCode, cause: $cause)';
}

bool shouldRunBranchCatalogMigrationForRole(String? role) =>
    role == 'merchant' || role == 'admin';

class BranchCatalogMigrationBootstrapService {
  final FirebaseFirestore firestore;

  const BranchCatalogMigrationBootstrapService(this.firestore);

  Future<void> runForOwner({
    required String merchantId,
  }) async {
    final globalStateRef = firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('migration_state')
        .doc('global_catalog_migration_v2');
        
    final globalState = await globalStateRef.get();
    if (globalState.data()?['status'] == 'completed') return;

    final branchIds = await _runStep<List<String>>(
      merchantId: merchantId,
      branchId: '<enumeration>',
      step: 'branch_enumeration',
      firestorePath: 'merchants/$merchantId/branches',
      action: () => _branchIds(merchantId),
    );
    final productRepository = ProductRepository(firestore);
    final rawMaterialRepository = RawMaterialRepository(firestore);

    for (final branchId in branchIds) {
      await _runStep<void>(
        merchantId: merchantId,
        branchId: branchId,
        step: 'product_visibility_manifest',
        firestorePath:
            'merchants/$merchantId/migration_state/legacy_product_visibility_v1_$branchId',
        action: () =>
            productRepository.buildLegacyProductVisibilityManifestIfNeeded(
          merchantId: merchantId,
          branchId: branchId,
        ),
      );
      await _runStep<void>(
        merchantId: merchantId,
        branchId: branchId,
        step: 'raw_material_visibility_manifest',
        firestorePath:
            'merchants/$merchantId/migration_state/legacy_raw_material_visibility_v1_$branchId',
        action: () => rawMaterialRepository
            .buildLegacyRawMaterialVisibilityManifestIfNeeded(
          merchantId: merchantId,
          branchId: branchId,
        ),
      );
      await _runStep<void>(
        merchantId: merchantId,
        branchId: branchId,
        step: 'product_catalog',
        firestorePath:
            'merchants/$merchantId/migration_state/branch_catalog_v1_$branchId',
        action: () => productRepository.migrateBranchCatalogIfNeeded(
          merchantId: merchantId,
          branchId: branchId,
        ),
      );
      await _runStep<void>(
        merchantId: merchantId,
        branchId: branchId,
        step: 'raw_material_catalog',
        firestorePath:
            'merchants/$merchantId/migration_state/branch_raw_materials_v1_$branchId',
        action: () => rawMaterialRepository.migrateBranchRawMaterialsIfNeeded(
          merchantId: merchantId,
          branchId: branchId,
        ),
      );
      await _runStep<void>(
        merchantId: merchantId,
        branchId: branchId,
        step: 'category_catalog',
        firestorePath:
            'merchants/$merchantId/migration_state/branch_categories_v1_$branchId',
        action: () => CategoryRepository(firestore, merchantId, branchId)
            .migrateBranchCategoriesIfNeeded(),
      );
    }

    await globalStateRef.set({
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<T> _runStep<T>({
    required String merchantId,
    required String branchId,
    required String step,
    required String firestorePath,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      final failure = BranchCatalogMigrationFailure(
        merchantId: merchantId,
        branchId: branchId,
        step: step,
        firestorePath: firestorePath,
        firebaseCode: error is FirebaseException ? error.code : null,
        cause: error,
      );
      developer.log(
        failure.toString(),
        name: 'tajer.branch_catalog_migration',
        error: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(failure, stackTrace);
    }
  }

  Future<List<String>> _branchIds(String merchantId) async {
    final snapshot = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branches')
        .get();
    final branchIds = snapshot.docs.map((doc) => doc.id).toSet();
    branchIds.add(BranchIds.main);
    return branchIds.toList(growable: false)..sort();
  }
}

final branchCatalogMigrationBootstrapProvider =
    FutureProvider.autoDispose<void>((ref) async {
  final user = ref.watch(appUserProvider).value;
  if (user == null || !shouldRunBranchCatalogMigrationForRole(user.role)) {
    return;
  }
  final service = BranchCatalogMigrationBootstrapService(
    FirebaseFirestore.instance,
  );
  await service.runForOwner(merchantId: currentEffectiveMerchantId(user));
});
