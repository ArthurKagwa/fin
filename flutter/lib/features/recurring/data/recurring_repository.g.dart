// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recurringRepository)
final recurringRepositoryProvider = RecurringRepositoryProvider._();

final class RecurringRepositoryProvider
    extends
        $FunctionalProvider<
          RecurringRepository,
          RecurringRepository,
          RecurringRepository
        >
    with $Provider<RecurringRepository> {
  RecurringRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recurringRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recurringRepositoryHash();

  @$internal
  @override
  $ProviderElement<RecurringRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecurringRepository create(Ref ref) {
    return recurringRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecurringRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecurringRepository>(value),
    );
  }
}

String _$recurringRepositoryHash() =>
    r'71cf86e468a14c757191a8993f1e2f3c865fd57a';

@ProviderFor(recurringPayments)
final recurringPaymentsProvider = RecurringPaymentsProvider._();

final class RecurringPaymentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RecurringPayment>>,
          List<RecurringPayment>,
          Stream<List<RecurringPayment>>
        >
    with
        $FutureModifier<List<RecurringPayment>>,
        $StreamProvider<List<RecurringPayment>> {
  RecurringPaymentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recurringPaymentsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recurringPaymentsHash();

  @$internal
  @override
  $StreamProviderElement<List<RecurringPayment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RecurringPayment>> create(Ref ref) {
    return recurringPayments(ref);
  }
}

String _$recurringPaymentsHash() => r'c082d2906099748ea88cf80803fb893079900914';

@ProviderFor(upcomingOccurrences)
final upcomingOccurrencesProvider = UpcomingOccurrencesProvider._();

final class UpcomingOccurrencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Occurrence>>,
          List<Occurrence>,
          Stream<List<Occurrence>>
        >
    with $FutureModifier<List<Occurrence>>, $StreamProvider<List<Occurrence>> {
  UpcomingOccurrencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'upcomingOccurrencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$upcomingOccurrencesHash();

  @$internal
  @override
  $StreamProviderElement<List<Occurrence>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Occurrence>> create(Ref ref) {
    return upcomingOccurrences(ref);
  }
}

String _$upcomingOccurrencesHash() =>
    r'8188d48879a9532c946ac0464cdb81984b194792';
