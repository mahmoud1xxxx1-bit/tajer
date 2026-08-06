// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$customerRepositoryHash() =>
    r'eeef0e35e401002b3fa54736da82a1fe4ce0e2f7';

/// See also [customerRepository].
@ProviderFor(customerRepository)
final customerRepositoryProvider =
    AutoDisposeProvider<CustomerRepository>.internal(
  customerRepository,
  name: r'customerRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$customerRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CustomerRepositoryRef = AutoDisposeProviderRef<CustomerRepository>;
String _$customersStreamHash() => r'b10009e541b5c0df09fd64eed59b5396540ce0ab';

/// See also [customersStream].
@ProviderFor(customersStream)
final customersStreamProvider =
    AutoDisposeStreamProvider<List<Customer>>.internal(
  customersStream,
  name: r'customersStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$customersStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CustomersStreamRef = AutoDisposeStreamProviderRef<List<Customer>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
