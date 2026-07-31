import 'package:fintrack/features/allocations/data/allocation_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'allocation_controller.g.dart';

@riverpod
class AllocationController extends _$AllocationController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> allocate({
    required String incomeEventId,
    required String bucketId,
    required int amountMinor,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(allocationRepositoryProvider).allocate(
            incomeEventId: incomeEventId,
            bucketId: bucketId,
            amountMinor: amountMinor,
          ),
    );
  }
}
