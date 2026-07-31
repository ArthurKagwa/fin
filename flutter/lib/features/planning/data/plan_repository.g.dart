// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(planRepository)
final planRepositoryProvider = PlanRepositoryProvider._();

final class PlanRepositoryProvider
    extends $FunctionalProvider<PlanRepository, PlanRepository, PlanRepository>
    with $Provider<PlanRepository> {
  PlanRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planRepositoryHash();

  @$internal
  @override
  $ProviderElement<PlanRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlanRepository create(Ref ref) {
    return planRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlanRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlanRepository>(value),
    );
  }
}

String _$planRepositoryHash() => r'9e0a1d43b7c58f26ad91e30b7c4f6182d5a0c93b';

@ProviderFor(monthlyPlan)
final monthlyPlanProvider = MonthlyPlanFamily._();

final class MonthlyPlanProvider
    extends
        $FunctionalProvider<
          AsyncValue<MonthlyPlan>,
          MonthlyPlan,
          Stream<MonthlyPlan>
        >
    with $FutureModifier<MonthlyPlan>, $StreamProvider<MonthlyPlan> {
  MonthlyPlanProvider._({
    required MonthlyPlanFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'monthlyPlanProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monthlyPlanHash();

  @override
  String toString() {
    return r'monthlyPlanProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<MonthlyPlan> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<MonthlyPlan> create(Ref ref) {
    final argument = this.argument as DateTime;
    return monthlyPlan(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MonthlyPlanProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monthlyPlanHash() => r'4b7f2c1e8a3d5906c2e14fb7038d9a5c61e4b872';

final class MonthlyPlanFamily extends $Family
    with $FunctionalFamilyOverride<Stream<MonthlyPlan>, DateTime> {
  MonthlyPlanFamily._()
    : super(
        retry: null,
        name: r'monthlyPlanProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MonthlyPlanProvider call(DateTime month) =>
      MonthlyPlanProvider._(argument: month, from: this);

  @override
  String toString() => r'monthlyPlanProvider';
}

@ProviderFor(planVsActual)
final planVsActualProvider = PlanVsActualFamily._();

final class PlanVsActualProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlanVsActual>,
          PlanVsActual,
          Stream<PlanVsActual>
        >
    with $FutureModifier<PlanVsActual>, $StreamProvider<PlanVsActual> {
  PlanVsActualProvider._({
    required PlanVsActualFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'planVsActualProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$planVsActualHash();

  @override
  String toString() {
    return r'planVsActualProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<PlanVsActual> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PlanVsActual> create(Ref ref) {
    final argument = this.argument as DateTime;
    return planVsActual(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanVsActualProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$planVsActualHash() => r'7c3a95e2b184d670fa2c8e39b5107d4c6a82f1e5';

final class PlanVsActualFamily extends $Family
    with $FunctionalFamilyOverride<Stream<PlanVsActual>, DateTime> {
  PlanVsActualFamily._()
    : super(
        retry: null,
        name: r'planVsActualProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PlanVsActualProvider call(DateTime month) =>
      PlanVsActualProvider._(argument: month, from: this);

  @override
  String toString() => r'planVsActualProvider';
}
