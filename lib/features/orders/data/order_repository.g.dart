// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$orderRepositoryHash() => r'455bb658a7abfa87bbf895fc847223bbbb5a380b';

/// See also [orderRepository].
@ProviderFor(orderRepository)
final orderRepositoryProvider = AutoDisposeProvider<OrderRepository>.internal(
  orderRepository,
  name: r'orderRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$orderRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef OrderRepositoryRef = AutoDisposeProviderRef<OrderRepository>;
String _$ordersStreamHash() => r'ab016e5cabdb869f4290df2d87c508af565f7259';

/// See also [ordersStream].
@ProviderFor(ordersStream)
final ordersStreamProvider = AutoDisposeStreamProvider<List<AppOrder>>.internal(
  ordersStream,
  name: r'ordersStreamProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$ordersStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef OrdersStreamRef = AutoDisposeStreamProviderRef<List<AppOrder>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
