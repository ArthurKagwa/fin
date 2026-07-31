class UserProfile {
  const UserProfile({
    required this.currencyCode,
    required this.timezone,
    required this.currencySetAt,
    this.unallocatedMinor = 0,
    this.reminderHour,
    this.reminderMinute,
  });

  final String currencyCode;
  final String timezone;
  final DateTime currencySetAt;

  /// Income received but not yet allocated to a bucket — the "ready to
  /// assign" pool. A running total maintained transactionally alongside
  /// every income/allocation write, not recomputed from history.
  final int unallocatedMinor;

  /// The evening reminder's time of day. Both null means disabled.
  final int? reminderHour;
  final int? reminderMinute;

  bool get hasReminder => reminderHour != null && reminderMinute != null;
}
