class CountryOption {
  const CountryOption(this.code, this.name, this.currencyCode);

  final String code;
  final String name;
  final String currencyCode;
}

const supportedCountries = [
  CountryOption('UG', 'Uganda', 'UGX'),
  CountryOption('KE', 'Kenya', 'KES'),
  CountryOption('TZ', 'Tanzania', 'TZS'),
  CountryOption('NG', 'Nigeria', 'NGN'),
  CountryOption('GH', 'Ghana', 'GHS'),
  CountryOption('ZA', 'South Africa', 'ZAR'),
  CountryOption('RW', 'Rwanda', 'RWF'),
  CountryOption('US', 'United States', 'USD'),
  CountryOption('GB', 'United Kingdom', 'GBP'),
  CountryOption('DE', 'Germany', 'EUR'),
  CountryOption('FR', 'France', 'EUR'),
  CountryOption('IN', 'India', 'INR'),
  CountryOption('CA', 'Canada', 'CAD'),
  CountryOption('AU', 'Australia', 'AUD'),
];

String currencyForCountry(String countryCode) {
  return supportedCountries.firstWhere((c) => c.code == countryCode).currencyCode;
}

/// A UTC-offset identifier ("UTC+03:00") — a reasonable stand-in for a full
/// IANA timezone without pulling in a platform-channel timezone package.
String currentUtcOffsetLabel() {
  final offset = DateTime.now().timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.abs().inHours.toString().padLeft(2, '0');
  final minutes = (offset.abs().inMinutes % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hours:$minutes';
}
