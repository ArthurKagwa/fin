// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bucket_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bucketRepository)
final bucketRepositoryProvider = BucketRepositoryProvider._();

final class BucketRepositoryProvider
    extends
        $FunctionalProvider<
          BucketRepository,
          BucketRepository,
          BucketRepository
        >
    with $Provider<BucketRepository> {
  BucketRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bucketRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bucketRepositoryHash();

  @$internal
  @override
  $ProviderElement<BucketRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BucketRepository create(Ref ref) {
    return bucketRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BucketRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BucketRepository>(value),
    );
  }
}

String _$bucketRepositoryHash() => r'b78be52545ce1f4f2c480547c6043d7f569f15ce';

@ProviderFor(activeBuckets)
final activeBucketsProvider = ActiveBucketsProvider._();

final class ActiveBucketsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Bucket>>,
          List<Bucket>,
          Stream<List<Bucket>>
        >
    with $FutureModifier<List<Bucket>>, $StreamProvider<List<Bucket>> {
  ActiveBucketsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeBucketsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeBucketsHash();

  @$internal
  @override
  $StreamProviderElement<List<Bucket>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Bucket>> create(Ref ref) {
    return activeBuckets(ref);
  }
}

String _$activeBucketsHash() => r'bc3736539beb6830aaecb29e46c3a8bf1d1b392a';
