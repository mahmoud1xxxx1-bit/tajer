// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$shiftRepositoryHash() => r'938816d906ec46572fc1ce50c22313e447b5c3a7';

/// See also [shiftRepository].
@ProviderFor(shiftRepository)
final shiftRepositoryProvider = AutoDisposeProvider<ShiftRepository>.internal(
  shiftRepository,
  name: r'shiftRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$shiftRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ShiftRepositoryRef = AutoDisposeProviderRef<ShiftRepository>;
String _$currentShiftHash() => r'c47da9409ccc03a0c3906ae0b5fac2e91f46829c';

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

/// See also [currentShift].
@ProviderFor(currentShift)
const currentShiftProvider = CurrentShiftFamily();

/// See also [currentShift].
class CurrentShiftFamily extends Family<AsyncValue<Shift?>> {
  /// See also [currentShift].
  const CurrentShiftFamily();

  /// See also [currentShift].
  CurrentShiftProvider call(
    String merchantId,
  ) {
    return CurrentShiftProvider(
      merchantId,
    );
  }

  @override
  CurrentShiftProvider getProviderOverride(
    covariant CurrentShiftProvider provider,
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
  String? get name => r'currentShiftProvider';
}

/// See also [currentShift].
class CurrentShiftProvider extends AutoDisposeStreamProvider<Shift?> {
  /// See also [currentShift].
  CurrentShiftProvider(
    String merchantId,
  ) : this._internal(
          (ref) => currentShift(
            ref as CurrentShiftRef,
            merchantId,
          ),
          from: currentShiftProvider,
          name: r'currentShiftProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$currentShiftHash,
          dependencies: CurrentShiftFamily._dependencies,
          allTransitiveDependencies:
              CurrentShiftFamily._allTransitiveDependencies,
          merchantId: merchantId,
        );

  CurrentShiftProvider._internal(
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
    Stream<Shift?> Function(CurrentShiftRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CurrentShiftProvider._internal(
        (ref) => create(ref as CurrentShiftRef),
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
  AutoDisposeStreamProviderElement<Shift?> createElement() {
    return _CurrentShiftProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CurrentShiftProvider && other.merchantId == merchantId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, merchantId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin CurrentShiftRef on AutoDisposeStreamProviderRef<Shift?> {
  /// The parameter `merchantId` of this provider.
  String get merchantId;
}

class _CurrentShiftProviderElement
    extends AutoDisposeStreamProviderElement<Shift?> with CurrentShiftRef {
  _CurrentShiftProviderElement(super.provider);

  @override
  String get merchantId => (origin as CurrentShiftProvider).merchantId;
}

String _$shiftsStreamHash() => r'50229b3f66df8c029160abd07bad325e54c0fcff';

/// See also [shiftsStream].
@ProviderFor(shiftsStream)
final shiftsStreamProvider = AutoDisposeStreamProvider<List<Shift>>.internal(
  shiftsStream,
  name: r'shiftsStreamProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$shiftsStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ShiftsStreamRef = AutoDisposeStreamProviderRef<List<Shift>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
