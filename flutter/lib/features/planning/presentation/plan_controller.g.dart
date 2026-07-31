// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which month the plan-vs-actual report is showing. Kept alive so paging back
/// to June, opening a bucket and coming back doesn't silently jump to today.

@ProviderFor(SelectedPlanMonth)
final selectedPlanMonthProvider = SelectedPlanMonthProvider._();

/// Which month the plan-vs-actual report is showing. Kept alive so paging back
/// to June, opening a bucket and coming back doesn't silently jump to today.
final class SelectedPlanMonthProvider
    extends $NotifierProvider<SelectedPlanMonth, DateTime> {
  /// Which month the plan-vs-actual report is showing. Kept alive so paging back
  /// to June, opening a bucket and coming back doesn't silently jump to today.
  SelectedPlanMonthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedPlanMonthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedPlanMonthHash();

  @$internal
  @override
  SelectedPlanMonth create() => SelectedPlanMonth();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$selectedPlanMonthHash() => r'2ac20a7a3560501633c9b3a971b08bbe56858366';

/// Which month the plan-vs-actual report is showing. Kept alive so paging back
/// to June, opening a bucket and coming back doesn't silently jump to today.

abstract class _$SelectedPlanMonth extends $Notifier<DateTime> {
  DateTime build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime, DateTime>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime, DateTime>,
              DateTime,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(PlanController)
final planControllerProvider = PlanControllerProvider._();

final class PlanControllerProvider
    extends $NotifierProvider<PlanController, AsyncValue<void>> {
  PlanControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planControllerHash();

  @$internal
  @override
  PlanController create() => PlanController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$planControllerHash() => r'b41ae60448418729a42ff41cd133431827e00e6a';

abstract class _$PlanController extends $Notifier<AsyncValue<void>> {
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
