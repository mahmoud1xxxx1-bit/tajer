import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/data/auth_repository.dart';
import '../../features/branches/domain/branch.dart';
import '../../features/categories/data/category_repository.dart';
import '../../features/products/data/product_repository.dart';
import '../../features/products/data/raw_material_repository.dart';
import '../providers/effective_merchant.dart';

class BranchCatalogMigrationBootstrapService {
  final FirebaseFirestore firestore;

  const BranchCatalogMigrationBootstrapService(this.firestore);

  Future<void> runForOwner({
    required String merchantId,
  }) async {
    final branchIds = await _branchIds(merchantId);
    final productRepository = ProductRepository(firestore);
    final rawMaterialRepository = RawMaterialRepository(firestore);

    for (final branchId in branchIds) {
      await productRepository.buildLegacyProductVisibilityManifestIfNeeded(
        merchantId: merchantId,
        branchId: branchId,
      );
      await rawMaterialRepository
          .buildLegacyRawMaterialVisibilityManifestIfNeeded(
        merchantId: merchantId,
        branchId: branchId,
      );
      await productRepository.migrateBranchCatalogIfNeeded(
        merchantId: merchantId,
        branchId: branchId,
      );
      await rawMaterialRepository.migrateBranchRawMaterialsIfNeeded(
        merchantId: merchantId,
        branchId: branchId,
      );
      await CategoryRepository(firestore, merchantId, branchId)
          .migrateBranchCategoriesIfNeeded();
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
  if (user == null || (user.role != 'merchant' && user.role != 'admin')) {
    return;
  }
  final service = BranchCatalogMigrationBootstrapService(
    FirebaseFirestore.instance,
  );
  await service.runForOwner(merchantId: currentEffectiveMerchantId(user));
});
