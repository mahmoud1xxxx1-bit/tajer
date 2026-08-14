// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_statement_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$customerStatementHash() => r'9e84e0683439009e58487ac0452d8658d2e2bcb9';

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

/// See also [customerStatement].
@ProviderFor(customerStatement)
const customerStatementProvider = CustomerStatementFamily();

/// See also [customerStatement].
class CustomerStatementFamily
    extends Family<AsyncValue<List<CustomerStatementItem>>> {
  /// See also [customerStatement].
  const CustomerStatementFamily();

  /// See also [customerStatement].
  CustomerStatementProvider call(
    Customer customer,
  ) {
    return CustomerStatementProvider(
      customer,
    );
  }

  @override
  CustomerStatementProvider getProviderOverride(
    covariant CustomerStatementProvider provider,
  ) {
    return call(
      provider.customer,
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
  String? get name => r'customerStatementProvider';
}

/// See also [customerStatement].
class CustomerStatementProvider
    extends AutoDisposeStreamProvider<List<CustomerStatementItem>> {
  /// See also [customerStatement].
  CustomerStatementProvider(
    Customer customer,
  ) : this._internal(
          (ref) => customerStatement(
            ref as CustomerStatementRef,
            customer,
          ),
          from: customerStatementProvider,
          name: r'customerStatementProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$customerStatementHash,
          dependencies: CustomerStatementFamily._dependencies,
          allTransitiveDependencies:
              CustomerStatementFamily._allTransitiveDependencies,
          customer: customer,
        );

  CustomerStatementProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.customer,
  }) : super.internal();

  final Customer customer;

  @override
  Override overrideWith(
    Stream<List<CustomerStatementItem>> Function(CustomerStatementRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CustomerStatementProvider._internal(
        (ref) => create(ref as CustomerStatementRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        customer: customer,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<CustomerStatementItem>>
      createElement() {
    return _CustomerStatementProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerStatementProvider && other.customer == customer;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, customer.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin CustomerStatementRef
    on AutoDisposeStreamProviderRef<List<CustomerStatementItem>> {
  /// The parameter `customer` of this provider.
  Customer get customer;
}

class _CustomerStatementProviderElement
    extends AutoDisposeStreamProviderElement<List<CustomerStatementItem>>
    with CustomerStatementRef {
  _CustomerStatementProviderElement(super.provider);

  @override
  Customer get customer => (origin as CustomerStatementProvider).customer;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
