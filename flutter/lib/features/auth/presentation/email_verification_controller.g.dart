// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_verification_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EmailVerificationController)
final emailVerificationControllerProvider =
    EmailVerificationControllerProvider._();

final class EmailVerificationControllerProvider
    extends $NotifierProvider<EmailVerificationController, AsyncValue<void>> {
  EmailVerificationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailVerificationControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailVerificationControllerHash();

  @$internal
  @override
  EmailVerificationController create() => EmailVerificationController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$emailVerificationControllerHash() =>
    r'75430a5bdbb7791cef99e8b668741d197bd531fa';

abstract class _$EmailVerificationController
    extends $Notifier<AsyncValue<void>> {
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
