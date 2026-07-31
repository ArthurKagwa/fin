// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_lock_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appLockService)
final appLockServiceProvider = AppLockServiceProvider._();

final class AppLockServiceProvider
    extends $FunctionalProvider<AppLockService, AppLockService, AppLockService>
    with $Provider<AppLockService> {
  AppLockServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLockServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLockServiceHash();

  @$internal
  @override
  $ProviderElement<AppLockService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppLockService create(Ref ref) {
    return appLockService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLockService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLockService>(value),
    );
  }
}

String _$appLockServiceHash() => r'd74e3760feb1c7c27e37182fdef2f3579f671876';
