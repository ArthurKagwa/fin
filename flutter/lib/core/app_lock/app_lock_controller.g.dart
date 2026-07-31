// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_lock_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppLockController)
final appLockControllerProvider = AppLockControllerProvider._();

final class AppLockControllerProvider
    extends $AsyncNotifierProvider<AppLockController, AppLockState> {
  AppLockControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLockControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLockControllerHash();

  @$internal
  @override
  AppLockController create() => AppLockController();
}

String _$appLockControllerHash() => r'94f76303ea7abcc6fd499ab827313b482f0d1419';

abstract class _$AppLockController extends $AsyncNotifier<AppLockState> {
  FutureOr<AppLockState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppLockState>, AppLockState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppLockState>, AppLockState>,
              AsyncValue<AppLockState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
