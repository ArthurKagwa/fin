// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RecurringController)
final recurringControllerProvider = RecurringControllerProvider._();

final class RecurringControllerProvider
    extends $NotifierProvider<RecurringController, AsyncValue<void>> {
  RecurringControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recurringControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recurringControllerHash();

  @$internal
  @override
  RecurringController create() => RecurringController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$recurringControllerHash() =>
    r'816ef26a1894700b1e1e8948269006c806fff2e7';

abstract class _$RecurringController extends $Notifier<AsyncValue<void>> {
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
