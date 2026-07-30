// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_setup_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CurrencySetupController)
final currencySetupControllerProvider = CurrencySetupControllerProvider._();

final class CurrencySetupControllerProvider
    extends $NotifierProvider<CurrencySetupController, AsyncValue<void>> {
  CurrencySetupControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currencySetupControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currencySetupControllerHash();

  @$internal
  @override
  CurrencySetupController create() => CurrencySetupController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$currencySetupControllerHash() =>
    r'43cc25e45009a5d9c3b6ab64b8e64f004efefa0f';

abstract class _$CurrencySetupController extends $Notifier<AsyncValue<void>> {
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
