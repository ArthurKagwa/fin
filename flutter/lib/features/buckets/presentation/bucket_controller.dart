import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bucket_controller.g.dart';

@riverpod
class BucketController extends _$BucketController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> create({required String name, int? plannedMinor, int? goalMinor}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(bucketRepositoryProvider).createBucket(
            name: name,
            plannedMinor: plannedMinor,
            goalMinor: goalMinor,
          ),
    );
  }

  Future<void> update({
    required String id,
    required String name,
    int? plannedMinor,
    int? goalMinor,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(bucketRepositoryProvider).updateBucket(
            id,
            name: name,
            plannedMinor: plannedMinor,
            goalMinor: goalMinor,
          ),
    );
  }

  Future<void> delete(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(bucketRepositoryProvider).deleteBucket(id));
  }
}
