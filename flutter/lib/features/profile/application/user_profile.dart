class UserProfile {
  const UserProfile({
    required this.currencyCode,
    required this.timezone,
    required this.currencySetAt,
  });

  final String currencyCode;
  final String timezone;
  final DateTime currencySetAt;
}
