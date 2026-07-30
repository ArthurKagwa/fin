import 'package:fintrack/features/recurring/application/recurring_payment.dart';
import 'package:fintrack/features/recurring/data/recurring_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'recurring_controller.g.dart';

@riverpod
class RecurringController extends _$RecurringController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> create({
    required String name,
    required String bucketId,
    required RecurringFrequency frequency,
    required int amountMinor,
    required DateTime startOn,
    int? intervalDays,
    DateTime? endOn,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(recurringRepositoryProvider).createRecurringPayment(
            name: name,
            bucketId: bucketId,
            frequency: frequency,
            amountMinor: amountMinor,
            startOn: startOn,
            intervalDays: intervalDays,
            endOn: endOn,
          ),
    );
  }

  Future<void> confirm(String occurrenceId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(recurringRepositoryProvider).confirmOccurrence(occurrenceId),
    );
  }

  Future<void> skip(String occurrenceId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(recurringRepositoryProvider).skipOccurrence(occurrenceId),
    );
  }
}
