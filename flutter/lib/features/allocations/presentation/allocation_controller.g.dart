// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'allocation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AllocationController)
final allocationControllerProvider = AllocationControllerProvider._();

final class AllocationControllerProvider
    extends $NotifierProvider<AllocationController, AsyncValue<void>> {
  AllocationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allocationControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allocationControllerHash();

  @$internal
  @override
  AllocationController create() => AllocationController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$allocationControllerHash() =>
    r'3930fa7a4dae836276d2a911ed9626861f7bac01';

abstract class _$AllocationController extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
