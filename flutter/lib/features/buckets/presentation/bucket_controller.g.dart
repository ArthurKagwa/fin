// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bucket_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BucketController)
final bucketControllerProvider = BucketControllerProvider._();

final class BucketControllerProvider
    extends $NotifierProvider<BucketController, AsyncValue<void>> {
  BucketControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bucketControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bucketControllerHash();

  @$internal
  @override
  BucketController create() => BucketController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$bucketControllerHash() => r'cb3cdf3af761e8111e4321b1b836d73d1bf9b93c';

abstract class _$BucketController extends $Notifier<AsyncValue<void>> {
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
