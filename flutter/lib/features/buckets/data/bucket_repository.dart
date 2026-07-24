import 'package:fintrack/features/buckets/application/bucket.dart';

abstract class BucketRepository {
  Stream<List<Bucket>> watchActiveBuckets();
  Future<void> createBucket({required String name, int? plannedMinor, int? goalMinor});
  Future<void> archiveBucket(String id);
}

class FirestoreBucketRepository implements BucketRepository {
  @override
  Stream<List<Bucket>> watchActiveBuckets() => throw UnimplementedError();

  @override
  Future<void> createBucket({
    required String name,
    int? plannedMinor,
    int? goalMinor,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> archiveBucket(String id) => throw UnimplementedError();
}
