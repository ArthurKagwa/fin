// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'income_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(incomeRepository)
final incomeRepositoryProvider = IncomeRepositoryProvider._();

final class IncomeRepositoryProvider
    extends
        $FunctionalProvider<
          IncomeRepository,
          IncomeRepository,
          IncomeRepository
        >
    with $Provider<IncomeRepository> {
  IncomeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'incomeRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$incomeRepositoryHash();

  @$internal
  @override
  $ProviderElement<IncomeRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IncomeRepository create(Ref ref) {
    return incomeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IncomeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IncomeRepository>(value),
    );
  }
}

String _$incomeRepositoryHash() => r'6dfd4d7cfdb47ad7fd8fdd1f13ec97923ac8333f';

@ProviderFor(incomeEvents)
final incomeEventsProvider = IncomeEventsProvider._();

final class IncomeEventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<IncomeEvent>>,
          List<IncomeEvent>,
          Stream<List<IncomeEvent>>
        >
    with
        $FutureModifier<List<IncomeEvent>>,
        $StreamProvider<List<IncomeEvent>> {
  IncomeEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'incomeEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$incomeEventsHash();

  @$internal
  @override
  $StreamProviderElement<List<IncomeEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<IncomeEvent>> create(Ref ref) {
    return incomeEvents(ref);
  }
}

String _$incomeEventsHash() => r'2fa3fe464cd41161db37a31d00f0480fb9ababc7';
