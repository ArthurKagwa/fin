// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ExpenseController)
final expenseControllerProvider = ExpenseControllerProvider._();

final class ExpenseControllerProvider
    extends $NotifierProvider<ExpenseController, AsyncValue<void>> {
  ExpenseControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expenseControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expenseControllerHash();

  @$internal
  @override
  ExpenseController create() => ExpenseController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$expenseControllerHash() => r'bd69bb0679f300acb54aaffe0f6aa6a99e9dd339';

abstract class _$ExpenseController extends $Notifier<AsyncValue<void>> {
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
