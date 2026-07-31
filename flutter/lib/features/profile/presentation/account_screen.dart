import 'package:fintrack/core/errors/app_failure.dart';
import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/profile/presentation/account_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authStateProvider).asData?.value;
    final profile = ref.watch(userProfileProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.secondaryContainer,
                        foregroundColor: colorScheme.secondary,
                        child: const Icon(Icons.person_outline),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.email ?? 'Not signed in',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  user?.emailVerified ?? false
                                      ? Icons.verified_outlined
                                      : Icons.error_outline,
                                  size: 14,
                                  color: user?.emailVerified ?? false
                                      ? colorScheme.secondary
                                      : colorScheme.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  user?.emailVerified ?? false
                                      ? 'Email verified'
                                      : 'Email not verified',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: user?.emailVerified ?? false
                                        ? colorScheme.secondary
                                        : colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Details', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Currency',
                    value: profile?.currencyCode ?? '—',
                    // Currency is fixed at onboarding by design; saying so here
                    // stops it reading as a setting the user failed to find.
                    note: 'Set when you signed up and fixed from then on',
                  ),
                  const SizedBox(height: 14),
                  _DetailRow(
                    label: 'Time zone',
                    value: profile?.timezone ?? '—',
                  ),
                  const SizedBox(height: 14),
                  _DetailRow(
                    label: 'Member since',
                    value: user?.createdAt == null
                        ? '—'
                        : formatMonth(user!.createdAt!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () => _confirmSignOut(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 32),
          Text('Danger zone', style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.error)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () => _confirmDeleteAccount(context, ref),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete account'),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'Your data stays saved to your account. You will need to sign in again '
        'to log anything new.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    await ref.read(authRepositoryProvider).signOut();
  }
}

Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
        'This permanently deletes every bucket, expense, income entry and '
        'recurring payment on your account. This can\'t be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete everything'),
        ),
      ],
    ),
  );
  if (!(confirmed ?? false) || !context.mounted) return;

  await _attemptDelete(context, ref);
}

/// Tries the delete; if Firebase demands a recent sign-in, prompts the
/// re-auth flow matching how this session originally signed in, then retries
/// once. A second `ReauthRequiredFailure` after that is treated as a real
/// failure rather than looping the prompt indefinitely.
Future<void> _attemptDelete(BuildContext context, WidgetRef ref, {bool isRetry = false}) async {
  final controller = ref.read(accountControllerProvider.notifier);
  await controller.deleteAccount();
  if (!context.mounted) return;

  final error = ref.read(accountControllerProvider).error;
  if (error == null) {
    context.go('/sign-in');
    return;
  }

  if (error is ReauthRequiredFailure && !isRetry) {
    final reauthed = await _showReauthDialog(context, ref);
    if (reauthed && context.mounted) {
      await _attemptDelete(context, ref, isRetry: true);
    }
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
}

Future<bool> _showReauthDialog(BuildContext context, WidgetRef ref) async {
  final kind = ref.read(authRepositoryProvider).currentProviderKind();
  if (kind == SignInProviderKind.google) {
    return ref.read(accountControllerProvider.notifier).reauthenticateWithGoogle();
  }

  final passwordController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Confirm it\'s you'),
      content: TextField(
        controller: passwordController,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Password'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  final password = passwordController.text;
  passwordController.dispose();
  if (!(confirmed ?? false)) return false;

  return ref.read(accountControllerProvider.notifier).reauthenticateWithPassword(password);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (note != null)
                Text(
                  note!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
