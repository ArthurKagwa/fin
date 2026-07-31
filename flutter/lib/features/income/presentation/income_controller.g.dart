// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'income_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(IncomeController)
final incomeControllerProvider = IncomeControllerProvider._();

final class IncomeControllerProvider
    extends $NotifierProvider<IncomeController, AsyncValue<void>> {
  IncomeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'incomeControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$incomeControllerHash();

  @$internal
  @override
  IncomeController create() => IncomeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$incomeControllerHash() => r'3c86d6faf0d9f9cf427c5e8d68ac529be2667ea5';

abstract class _$IncomeController extends $Notifier<AsyncValue<void>> {
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
