// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_cost_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$productCostRepositoryHash() =>
    r'14c9ad5c8dcab5906c1fbd7696ae36fc268e5678';

/// See also [productCostRepository].
@ProviderFor(productCostRepository)
final productCostRepositoryProvider =
    AutoDisposeProvider<ProductCostRepository>.internal(
  productCostRepository,
  name: r'productCostRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$productCostRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ProductCostRepositoryRef
    = AutoDisposeProviderRef<ProductCostRepository>;
String _$productCostsStreamHash() =>
    r'98f94b1ea6a19407250b67055a7092790c46b6bd';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [productCostsStream].
@ProviderFor(productCostsStream)
const productCostsStreamProvider = ProductCostsStreamFamily();

/// See also [productCostsStream].
class ProductCostsStreamFamily extends Family<AsyncValue<Map<String, double>>> {
  /// See also [productCostsStream].
  const ProductCostsStreamFamily();

  /// See also [productCostsStream].
  ProductCostsStreamProvider call(
    String merchantId,
  ) {
    return ProductCostsStreamProvider(
      merchantId,
    );
  }

  @override
  ProductCostsStreamProvider getProviderOverride(
    covariant ProductCostsStreamProvider provider,
  ) {
    return call(
      provider.merchantId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'productCostsStreamProvider';
}

/// See also [productCostsStream].
class ProductCostsStreamProvider
    extends AutoDisposeStreamProvider<Map<String, double>> {
  /// See also [productCostsStream].
  ProductCostsStreamProvider(
    String merchantId,
  ) : this._internal(
          (ref) => productCostsStream(
            ref as ProductCostsStreamRef,
            merchantId,
          ),
          from: productCostsStreamProvider,
          name: r'productCostsStreamProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$productCostsStreamHash,
          dependencies: ProductCostsStreamFamily._dependencies,
          allTransitiveDependencies:
              ProductCostsStreamFamily._allTransitiveDependencies,
          merchantId: merchantId,
        );

  ProductCostsStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.merchantId,
  }) : super.internal();

  final String merchantId;

  @override
  Override overrideWith(
    Stream<Map<String, double>> Function(ProductCostsStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ProductCostsStreamProvider._internal(
        (ref) => create(ref as ProductCostsStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        merchantId: merchantId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<Map<String, double>> createElement() {
    return _ProductCostsStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductCostsStreamProvider &&
        other.merchantId == merchantId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, merchantId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ProductCostsStreamRef
    on AutoDisposeStreamProviderRef<Map<String, double>> {
  /// The parameter `merchantId` of this provider.
  String get merchantId;
}

class _ProductCostsStreamProviderElement
    extends AutoDisposeStreamProviderElement<Map<String, double>>
    with ProductCostsStreamRef {
  _ProductCostsStreamProviderElement(super.provider);

  @override
  String get merchantId => (origin as ProductCostsStreamProvider).merchantId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
