/// One chunk of income assigned to a bucket.
///
/// A doc per allocation — not a map on the income event or the bucket —
/// so assigning a paycheque across several buckets, or coming back later to
/// assign the rest, is just another doc: no read-modify-write race on a
/// shared array field.
class Allocation {
  const Allocation({
    required this.id,
    required this.incomeEventId,
    required this.bucketId,
    required this.amountMinor,
    required this.createdAt,
  });

  final String id;
  final String incomeEventId;
  final String bucketId;
  final int amountMinor;
  final DateTime createdAt;
}
