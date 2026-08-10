import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/products/data/product_repository.dart';
import 'package:tajer/features/products/domain/product.dart';
import 'package:tajer/features/products/domain/raw_material.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProductRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = ProductRepository(firestore);
  });

  test('copy product definition from branch A to branch B', () async {
    const merchantId = 'merchant_123';
    const sourceBranch = 'branch_A';
    const targetBranch = 'branch_B';
    const productId = 'prod_1';

    // Source product with cost price and quantity
    final sourceProduct = Product(
      id: productId,
      merchantId: merchantId,
      name: 'Product 1',
      price: 100.0,
      costPrice: 50.0,
      quantity: 10,
      categoryId: 'cat_1',
      isManufacturedOnDemand: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Seed the source product in Firestore
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branches')
        .doc(sourceBranch)
        .collection('products')
        .doc(productId)
        .set(sourceProduct.toJson());

    // Seed the cost in product_costs for source
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branches')
        .doc(sourceBranch)
        .collection('product_costs')
        .doc(productId)
        .set({'costPrice': 50.0});

    // Copy to Target Branch
    await repo.copyProductToBranch(product: sourceProduct, targetBranchId: targetBranch);

    // Assert target branch product exists
    final targetDoc = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branches')
        .doc(targetBranch)
        .collection('products')
        .doc(productId)
        .get();

    expect(targetDoc.exists, true);
    final targetData = targetDoc.data()!;

    // Same logical product id
    expect(targetDoc.id, productId);

    // Target branch stock = 0
    expect(targetData['quantity'], 0);

    // Target branch product payload contains NO protected source cost
    expect(targetData.containsKey('costPrice'), false);

    // Target cost document should not exist
    final targetCostDoc = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branches')
        .doc(targetBranch)
        .collection('product_costs')
        .doc(productId)
        .get();
    expect(targetCostDoc.exists, false);

    // Source product remains intact
    final srcDoc = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branches')
        .doc(sourceBranch)
        .collection('products')
        .doc(productId)
        .get();
    expect(srcDoc.data()?['quantity'], 10);
    expect(srcDoc.data()?['costPrice'], 50.0);

    // Duplicate/retry does not create invalid duplicate state
    // By re-running the copy, it should just return (no crash) and state remains same
    await repo.copyProductToBranch(product: sourceProduct, targetBranchId: targetBranch);
    final targetDocAgain = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branches')
        .doc(targetBranch)
        .collection('products')
        .doc(productId)
        .get();
    expect(targetDocAgain.data()?['quantity'], 0); // Still 0
  });

  test('MTO copy fails closed when required raw materials are unavailable', () async {
    const merchantId = 'merchant_123';
    const sourceBranch = 'branch_A';
    const targetBranch = 'branch_B';
    const productId = 'mto_1';

    final sourceProduct = Product(
      id: productId,
      merchantId: merchantId,
      name: 'MTO Product',
      price: 100.0,
      quantity: 0,
      categoryId: 'cat_1',
      isManufacturedOnDemand: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      recipe: [
        const RecipeItem(rawMaterialId: 'raw_1', amountRequired: 5),
      ],
    );

    // Target branch does not have raw_1 in its inventory

    expect(
      () => repo.copyProductToBranch(product: sourceProduct, targetBranchId: targetBranch),
      throwsStateError,
    );
  });

  test('MTO copy succeeds when required raw materials exist in target branch', () async {
    const merchantId = 'merchant_123';
    const sourceBranch = 'branch_A';
    const targetBranch = 'branch_B';
    const productId = 'mto_1';

    final sourceProduct = Product(
      id: productId,
      merchantId: merchantId,
      name: 'MTO Product',
      price: 100.0,
      quantity: 0,
      categoryId: 'cat_1',
      isManufacturedOnDemand: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      recipe: [
        const RecipeItem(rawMaterialId: 'raw_1', amountRequired: 5),
      ],
    );

    // Target branch HAS raw_1 in its inventory
    await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branch_inventory')
        .doc('${targetBranch}_raw_material_raw_1')
        .set({'quantity': 50.0});

    await repo.copyProductToBranch(product: sourceProduct, targetBranchId: targetBranch);

    final targetDoc = await firestore
        .collection('merchants')
        .doc(merchantId)
        .collection('branches')
        .doc(targetBranch)
        .collection('products')
        .doc(productId)
        .get();

    expect(targetDoc.exists, true);
  });
}
