import 'package:fintrack/core/utils/locale_currency.dart';
import 'package:fintrack/features/onboarding/presentation/currency_setup_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurrencySetupScreen extends ConsumerStatefulWidget {
  const CurrencySetupScreen({super.key});

  @override
  ConsumerState<CurrencySetupScreen> createState() => _CurrencySetupScreenState();
}

class _CurrencySetupScreenState extends ConsumerState<CurrencySetupScreen> {
  String? _countryCode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = ref.watch(currencySetupControllerProvider).isLoading;
    final currencyCode = _countryCode == null ? null : currencyForCountry(_countryCode!);

    ref.listen(currencySetupControllerProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: ${next.error}')),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.public_outlined, size: 56, color: colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Where are you based?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'We use this to set your currency. '
                'You won\'t be able to change it once you start logging.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
              DropdownButtonFormField<String>(
                initialValue: _countryCode,
                decoration: const InputDecoration(labelText: 'Country'),
                hint: const Text('Select your country'),
                items: [
                  for (final option in supportedCountries)
                    DropdownMenuItem(value: option.code, child: Text(option.name)),
                ],
                onChanged: (value) => setState(() => _countryCode = value),
              ),
              if (currencyCode != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Currency: $currencyCode',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.secondary,
                      ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: isLoading || currencyCode == null
                    ? null
                    : () => ref.read(currencySetupControllerProvider.notifier).confirm(
                          currencyCode: currencyCode,
                          timezone: currentUtcOffsetLabel(),
                        ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
