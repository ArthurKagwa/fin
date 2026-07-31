// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'allocation_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(allocationRepository)
final allocationRepositoryProvider = AllocationRepositoryProvider._();

final class AllocationRepositoryProvider
    extends
        $FunctionalProvider<
          AllocationRepository,
          AllocationRepository,
          AllocationRepository
        >
    with $Provider<AllocationRepository> {
  AllocationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allocationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allocationRepositoryHash();

  @$internal
  @override
  $ProviderElement<AllocationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AllocationRepository create(Ref ref) {
    return allocationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AllocationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AllocationRepository>(value),
    );
  }
}

String _$allocationRepositoryHash() =>
    r'9076b8474905605a30e457618214b79fff53c3b3';
