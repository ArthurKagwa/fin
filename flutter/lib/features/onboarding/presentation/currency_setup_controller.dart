import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'currency_setup_controller.g.dart';

@riverpod
class CurrencySetupController extends _$CurrencySetupController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> confirm({required String currencyCode, required String timezone}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).setCurrency(
            currencyCode: currencyCode,
            timezone: timezone,
          ),
    );
  }
}
