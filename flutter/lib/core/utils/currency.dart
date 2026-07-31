/// Currency facts the app needs: how many decimal places a currency has, and
/// what to draw in front of an amount.
///
/// Amounts are stored as integer **minor units** everywhere — cents, pence,
/// fils. The exponent below is what turns those integers back into something a
/// person recognises, and it is not always 2: yen and shillings have no minor
/// unit at all, and Gulf dinars have three.
library;

/// Currencies with no minor unit. Storing 1200 UGX means 1,200 shillings, not
/// twelve. Getting this wrong shows amounts 100x out.
const _zeroDecimalCurrencies = {
  'BIF', 'CLP', 'DJF', 'GNF', 'ISK', 'JPY', 'KMF', 'KRW', 'PYG', 'RWF',
  'UGX', 'UYI', 'VND', 'VUV', 'XAF', 'XOF', 'XPF',
};

/// Currencies with three decimal places rather than two.
const _threeDecimalCurrencies = {
  'BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND',
};

/// Number of decimal places for [currencyCode]. Defaults to 2, which covers
/// the overwhelming majority of ISO 4217.
int currencyDecimals(String currencyCode) {
  final code = currencyCode.toUpperCase();
  if (_zeroDecimalCurrencies.contains(code)) return 0;
  if (_threeDecimalCurrencies.contains(code)) return 3;
  return 2;
}

/// How many minor units make one major unit — 100 for most, 1 for yen, 1000
/// for dinars.
int currencyMinorUnitsPerMajor(String currencyCode) {
  var multiplier = 1;
  for (var i = 0; i < currencyDecimals(currencyCode); i++) {
    multiplier *= 10;
  }
  return multiplier;
}

/// Well-known symbols only. Anything absent falls back to the ISO code, which
/// is always correct if a little formal — better than inventing a glyph or
/// showing the wrong one.
const _currencySymbols = {
  'AUD': r'A$',
  'BRL': r'R$',
  'CAD': r'C$',
  'CHF': 'CHF',
  'CNY': '¥',
  'EUR': '€',
  'GBP': '£',
  'GHS': '₵',
  'HKD': r'HK$',
  'ILS': '₪',
  'INR': '₹',
  'JPY': '¥',
  'KES': 'KSh',
  'KRW': '₩',
  'MXN': r'MX$',
  'NGN': '₦',
  'NZD': r'NZ$',
  'PHP': '₱',
  'PLN': 'zł',
  'RUB': '₽',
  'SGD': r'S$',
  'THB': '฿',
  'TRY': '₺',
  'TZS': 'TSh',
  'UAH': '₴',
  'UGX': 'USh',
  'USD': r'$',
  'VND': '₫',
  'ZAR': 'R',
};

/// The symbol to draw before an amount, or the ISO code when there isn't a
/// recognisable one.
String currencySymbol(String currencyCode) =>
    _currencySymbols[currencyCode.toUpperCase()] ?? currencyCode.toUpperCase();

/// True when [currencySymbol] returned a real symbol rather than falling back
/// to the code. Callers use this to decide spacing: "$12.00" but "UGX 1,200".
bool currencyHasSymbol(String currencyCode) =>
    _currencySymbols.containsKey(currencyCode.toUpperCase());

class CountryOption {
  const CountryOption(this.code, this.name, this.currencyCode);

  final String code;
  final String name;
  final String currencyCode;
}

/// Every country the picker offers, with the currency it implies.
///
/// Countries that use more than one currency in practice are mapped to the one
/// a personal-finance user would mean; the currency is confirmed on screen
/// before it is saved, so an unusual case is visible rather than silent.
const supportedCountries = [
  CountryOption('AF', 'Afghanistan', 'AFN'),
  CountryOption('AL', 'Albania', 'ALL'),
  CountryOption('DZ', 'Algeria', 'DZD'),
  CountryOption('AD', 'Andorra', 'EUR'),
  CountryOption('AO', 'Angola', 'AOA'),
  CountryOption('AG', 'Antigua and Barbuda', 'XCD'),
  CountryOption('AR', 'Argentina', 'ARS'),
  CountryOption('AM', 'Armenia', 'AMD'),
  CountryOption('AU', 'Australia', 'AUD'),
  CountryOption('AT', 'Austria', 'EUR'),
  CountryOption('AZ', 'Azerbaijan', 'AZN'),
  CountryOption('BS', 'Bahamas', 'BSD'),
  CountryOption('BH', 'Bahrain', 'BHD'),
  CountryOption('BD', 'Bangladesh', 'BDT'),
  CountryOption('BB', 'Barbados', 'BBD'),
  CountryOption('BY', 'Belarus', 'BYN'),
  CountryOption('BE', 'Belgium', 'EUR'),
  CountryOption('BZ', 'Belize', 'BZD'),
  CountryOption('BJ', 'Benin', 'XOF'),
  CountryOption('BT', 'Bhutan', 'BTN'),
  CountryOption('BO', 'Bolivia', 'BOB'),
  CountryOption('BA', 'Bosnia and Herzegovina', 'BAM'),
  CountryOption('BW', 'Botswana', 'BWP'),
  CountryOption('BR', 'Brazil', 'BRL'),
  CountryOption('BN', 'Brunei', 'BND'),
  CountryOption('BG', 'Bulgaria', 'BGN'),
  CountryOption('BF', 'Burkina Faso', 'XOF'),
  CountryOption('BI', 'Burundi', 'BIF'),
  CountryOption('KH', 'Cambodia', 'KHR'),
  CountryOption('CM', 'Cameroon', 'XAF'),
  CountryOption('CA', 'Canada', 'CAD'),
  CountryOption('CV', 'Cape Verde', 'CVE'),
  CountryOption('CF', 'Central African Republic', 'XAF'),
  CountryOption('TD', 'Chad', 'XAF'),
  CountryOption('CL', 'Chile', 'CLP'),
  CountryOption('CN', 'China', 'CNY'),
  CountryOption('CO', 'Colombia', 'COP'),
  CountryOption('KM', 'Comoros', 'KMF'),
  CountryOption('CG', 'Congo - Brazzaville', 'XAF'),
  CountryOption('CD', 'Congo - Kinshasa', 'CDF'),
  CountryOption('CR', 'Costa Rica', 'CRC'),
  CountryOption('CI', "Côte d'Ivoire", 'XOF'),
  CountryOption('HR', 'Croatia', 'EUR'),
  CountryOption('CU', 'Cuba', 'CUP'),
  CountryOption('CY', 'Cyprus', 'EUR'),
  CountryOption('CZ', 'Czechia', 'CZK'),
  CountryOption('DK', 'Denmark', 'DKK'),
  CountryOption('DJ', 'Djibouti', 'DJF'),
  CountryOption('DM', 'Dominica', 'XCD'),
  CountryOption('DO', 'Dominican Republic', 'DOP'),
  CountryOption('EC', 'Ecuador', 'USD'),
  CountryOption('EG', 'Egypt', 'EGP'),
  CountryOption('SV', 'El Salvador', 'USD'),
  CountryOption('GQ', 'Equatorial Guinea', 'XAF'),
  CountryOption('ER', 'Eritrea', 'ERN'),
  CountryOption('EE', 'Estonia', 'EUR'),
  CountryOption('SZ', 'Eswatini', 'SZL'),
  CountryOption('ET', 'Ethiopia', 'ETB'),
  CountryOption('FJ', 'Fiji', 'FJD'),
  CountryOption('FI', 'Finland', 'EUR'),
  CountryOption('FR', 'France', 'EUR'),
  CountryOption('GA', 'Gabon', 'XAF'),
  CountryOption('GM', 'Gambia', 'GMD'),
  CountryOption('GE', 'Georgia', 'GEL'),
  CountryOption('DE', 'Germany', 'EUR'),
  CountryOption('GH', 'Ghana', 'GHS'),
  CountryOption('GR', 'Greece', 'EUR'),
  CountryOption('GD', 'Grenada', 'XCD'),
  CountryOption('GT', 'Guatemala', 'GTQ'),
  CountryOption('GN', 'Guinea', 'GNF'),
  CountryOption('GW', 'Guinea-Bissau', 'XOF'),
  CountryOption('GY', 'Guyana', 'GYD'),
  CountryOption('HT', 'Haiti', 'HTG'),
  CountryOption('HN', 'Honduras', 'HNL'),
  CountryOption('HK', 'Hong Kong SAR China', 'HKD'),
  CountryOption('HU', 'Hungary', 'HUF'),
  CountryOption('IS', 'Iceland', 'ISK'),
  CountryOption('IN', 'India', 'INR'),
  CountryOption('ID', 'Indonesia', 'IDR'),
  CountryOption('IR', 'Iran', 'IRR'),
  CountryOption('IQ', 'Iraq', 'IQD'),
  CountryOption('IE', 'Ireland', 'EUR'),
  CountryOption('IL', 'Israel', 'ILS'),
  CountryOption('IT', 'Italy', 'EUR'),
  CountryOption('JM', 'Jamaica', 'JMD'),
  CountryOption('JP', 'Japan', 'JPY'),
  CountryOption('JO', 'Jordan', 'JOD'),
  CountryOption('KZ', 'Kazakhstan', 'KZT'),
  CountryOption('KE', 'Kenya', 'KES'),
  CountryOption('KI', 'Kiribati', 'AUD'),
  CountryOption('KW', 'Kuwait', 'KWD'),
  CountryOption('KG', 'Kyrgyzstan', 'KGS'),
  CountryOption('LA', 'Laos', 'LAK'),
  CountryOption('LV', 'Latvia', 'EUR'),
  CountryOption('LB', 'Lebanon', 'LBP'),
  CountryOption('LS', 'Lesotho', 'LSL'),
  CountryOption('LR', 'Liberia', 'LRD'),
  CountryOption('LY', 'Libya', 'LYD'),
  CountryOption('LI', 'Liechtenstein', 'CHF'),
  CountryOption('LT', 'Lithuania', 'EUR'),
  CountryOption('LU', 'Luxembourg', 'EUR'),
  CountryOption('MG', 'Madagascar', 'MGA'),
  CountryOption('MW', 'Malawi', 'MWK'),
  CountryOption('MY', 'Malaysia', 'MYR'),
  CountryOption('MV', 'Maldives', 'MVR'),
  CountryOption('ML', 'Mali', 'XOF'),
  CountryOption('MT', 'Malta', 'EUR'),
  CountryOption('MR', 'Mauritania', 'MRU'),
  CountryOption('MU', 'Mauritius', 'MUR'),
  CountryOption('MX', 'Mexico', 'MXN'),
  CountryOption('MD', 'Moldova', 'MDL'),
  CountryOption('MC', 'Monaco', 'EUR'),
  CountryOption('MN', 'Mongolia', 'MNT'),
  CountryOption('ME', 'Montenegro', 'EUR'),
  CountryOption('MA', 'Morocco', 'MAD'),
  CountryOption('MZ', 'Mozambique', 'MZN'),
  CountryOption('MM', 'Myanmar', 'MMK'),
  CountryOption('NA', 'Namibia', 'NAD'),
  CountryOption('NP', 'Nepal', 'NPR'),
  CountryOption('NL', 'Netherlands', 'EUR'),
  CountryOption('NZ', 'New Zealand', 'NZD'),
  CountryOption('NI', 'Nicaragua', 'NIO'),
  CountryOption('NE', 'Niger', 'XOF'),
  CountryOption('NG', 'Nigeria', 'NGN'),
  CountryOption('MK', 'North Macedonia', 'MKD'),
  CountryOption('NO', 'Norway', 'NOK'),
  CountryOption('OM', 'Oman', 'OMR'),
  CountryOption('PK', 'Pakistan', 'PKR'),
  CountryOption('PA', 'Panama', 'PAB'),
  CountryOption('PG', 'Papua New Guinea', 'PGK'),
  CountryOption('PY', 'Paraguay', 'PYG'),
  CountryOption('PE', 'Peru', 'PEN'),
  CountryOption('PH', 'Philippines', 'PHP'),
  CountryOption('PL', 'Poland', 'PLN'),
  CountryOption('PT', 'Portugal', 'EUR'),
  CountryOption('QA', 'Qatar', 'QAR'),
  CountryOption('RO', 'Romania', 'RON'),
  CountryOption('RU', 'Russia', 'RUB'),
  CountryOption('RW', 'Rwanda', 'RWF'),
  CountryOption('WS', 'Samoa', 'WST'),
  CountryOption('SA', 'Saudi Arabia', 'SAR'),
  CountryOption('SN', 'Senegal', 'XOF'),
  CountryOption('RS', 'Serbia', 'RSD'),
  CountryOption('SC', 'Seychelles', 'SCR'),
  CountryOption('SL', 'Sierra Leone', 'SLE'),
  CountryOption('SG', 'Singapore', 'SGD'),
  CountryOption('SK', 'Slovakia', 'EUR'),
  CountryOption('SI', 'Slovenia', 'EUR'),
  CountryOption('SB', 'Solomon Islands', 'SBD'),
  CountryOption('SO', 'Somalia', 'SOS'),
  CountryOption('ZA', 'South Africa', 'ZAR'),
  CountryOption('KR', 'South Korea', 'KRW'),
  CountryOption('SS', 'South Sudan', 'SSP'),
  CountryOption('ES', 'Spain', 'EUR'),
  CountryOption('LK', 'Sri Lanka', 'LKR'),
  CountryOption('LC', 'St. Lucia', 'XCD'),
  CountryOption('VC', 'St. Vincent and Grenadines', 'XCD'),
  CountryOption('SD', 'Sudan', 'SDG'),
  CountryOption('SR', 'Suriname', 'SRD'),
  CountryOption('SE', 'Sweden', 'SEK'),
  CountryOption('CH', 'Switzerland', 'CHF'),
  CountryOption('SY', 'Syria', 'SYP'),
  CountryOption('TW', 'Taiwan', 'TWD'),
  CountryOption('TJ', 'Tajikistan', 'TJS'),
  CountryOption('TZ', 'Tanzania', 'TZS'),
  CountryOption('TH', 'Thailand', 'THB'),
  CountryOption('TL', 'Timor-Leste', 'USD'),
  CountryOption('TG', 'Togo', 'XOF'),
  CountryOption('TO', 'Tonga', 'TOP'),
  CountryOption('TT', 'Trinidad and Tobago', 'TTD'),
  CountryOption('TN', 'Tunisia', 'TND'),
  CountryOption('TR', 'Türkiye', 'TRY'),
  CountryOption('TM', 'Turkmenistan', 'TMT'),
  CountryOption('UG', 'Uganda', 'UGX'),
  CountryOption('UA', 'Ukraine', 'UAH'),
  CountryOption('AE', 'United Arab Emirates', 'AED'),
  CountryOption('GB', 'United Kingdom', 'GBP'),
  CountryOption('US', 'United States', 'USD'),
  CountryOption('UY', 'Uruguay', 'UYU'),
  CountryOption('UZ', 'Uzbekistan', 'UZS'),
  CountryOption('VU', 'Vanuatu', 'VUV'),
  CountryOption('VE', 'Venezuela', 'VES'),
  CountryOption('VN', 'Vietnam', 'VND'),
  CountryOption('YE', 'Yemen', 'YER'),
  CountryOption('ZM', 'Zambia', 'ZMW'),
  CountryOption('ZW', 'Zimbabwe', 'ZWG'),
];

/// The currency for [countryCode], or null when the code isn't one we know.
/// Nullable rather than throwing: an unknown code is a bad saved value, not a
/// programming error, and the picker should recover by asking again.
String? currencyForCountry(String countryCode) {
  final upper = countryCode.toUpperCase();
  for (final country in supportedCountries) {
    if (country.code == upper) return country.currencyCode;
  }
  return null;
}

/// Countries whose name contains [query], case-insensitively. An empty query
/// returns everything, so the picker can use one code path.
List<CountryOption> searchCountries(String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return supportedCountries;
  return [
    for (final country in supportedCountries)
      if (country.name.toLowerCase().contains(needle) ||
          country.currencyCode.toLowerCase().contains(needle))
        country,
  ];
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
