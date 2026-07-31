import 'package:fintrack/core/utils/currency.dart';
import 'package:fintrack/core/utils/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cash-register amount entry: digits fill from the right.
///
/// Typing 1, 2, 5, 0 in a two-decimal currency reads 0.01, 0.12, 1.25, 12.50 —
/// no decimal key, no ambiguity about whether "12.5" meant twelve-fifty, and
/// nothing the user can type that fails to parse. Silent nulls from
/// `int.tryParse` were losing amounts before this existed.
///
/// In a zero-decimal currency the behaviour collapses to plain digit entry
/// with grouping, which is what a UGX or JPY user expects anyway.
class MoneyInputFormatter extends TextInputFormatter {
  MoneyInputFormatter({required this.currency, this.maxDigits = 15});

  final String currency;

  /// Guards against an int overflow from a held-down key. 15 digits is well
  /// inside a 64-bit int even in a three-decimal currency.
  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);

    // An empty field must stay empty rather than showing 0.00, so "optional
    // amount" fields can tell "cleared" from "zero".
    if (digits.isEmpty) return const TextEditingValue();

    final formatted = formatMoneyDigits(digits, currency: currency);
    // The caret always sits at the end: digits enter from the right, so there
    // is nowhere else meaningful for it to be.
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Renders a raw digit string as an amount, without a currency symbol —
/// the field shows the symbol separately as a prefix.
String formatMoneyDigits(String digits, {required String currency}) {
  final minorUnits = int.tryParse(digits) ?? 0;
  final full = formatMoney(minorUnits, currency: currency);
  final symbol = currencySymbol(currency);
  // formatMoney owns the grouping and decimal-place rules; strip the symbol it
  // added rather than reimplementing them here and risking a mismatch.
  return full.replaceFirst(symbol, '').trimLeft();
}

/// The amount a [MoneyField] currently holds, in minor units. Zero for an
/// empty field; callers that need to distinguish empty use [moneyFieldIsEmpty].
int moneyFromField(TextEditingController controller) {
  final digits = controller.text.replaceAll(RegExp(r'\D'), '');
  return int.tryParse(digits) ?? 0;
}

bool moneyFieldIsEmpty(TextEditingController controller) =>
    controller.text.replaceAll(RegExp(r'\D'), '').isEmpty;

/// Seeds a controller with an existing amount so edit forms show what is
/// already stored.
void setMoneyField(
  TextEditingController controller,
  int? minorUnits, {
  required String currency,
}) {
  if (minorUnits == null || minorUnits == 0) {
    controller.text = '';
    return;
  }
  controller.text = formatMoneyDigits(
    minorUnits.abs().toString(),
    currency: currency,
  );
}

/// A money input with the currency symbol shown, the right keyboard, and
/// cash-register formatting. Every amount in the app goes through this so the
/// entry rules can't drift form to form.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.currency,
    this.label,
    this.errorText,
    this.autofocus = false,
    this.large = false,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String currency;
  final String? label;
  final String? errorText;
  final bool autofocus;

  /// The oversized centred treatment used on the add-expense sheet, where the
  /// amount is the whole point of the screen.
  final bool large;

  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symbol = currencySymbol(currency);
    final hint = formatMoneyDigits('0', currency: currency);

    return TextField(
      controller: controller,
      autofocus: autofocus,
      // digitsOnly plus the formatter means there is no keystroke that can
      // produce an unparseable value.
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        MoneyInputFormatter(currency: currency),
      ],
      style: large ? theme.textTheme.displaySmall : null,
      textAlign: large ? TextAlign.center : TextAlign.start,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        hintText: hint,
        prefixText: '$symbol ',
        prefixStyle: large
            ? theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
        border: large ? InputBorder.none : null,
        filled: large ? false : null,
      ),
    );
  }
}
