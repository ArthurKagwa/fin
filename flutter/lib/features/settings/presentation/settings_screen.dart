import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/planning/presentation/plan_controller.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final email = ref.watch(authStateProvider).asData?.value?.email ?? '';
    final currency = ref.watch(currencyCodeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('More', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          const _SectionLabel('Records'),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.history,
                title: 'History',
                subtitle: 'Browse past months',
                onTap: () {
                  // Opens the plan-vs-actual report on the current month; its
                  // picker is how past months are reached.
                  ref
                      .read(selectedPlanMonthProvider.notifier)
                      .select(DateTime.now());
                  context.push('/plan');
                },
              ),
              _SettingsRow(
                icon: Icons.bar_chart_outlined,
                title: 'Earnings report',
                subtitle: 'Gross vs. take-home by month',
                onTap: () => context.push('/earnings'),
              ),
              _SettingsRow(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Export',
                subtitle: 'Share a month as a PDF statement',
                onTap: () => context.push('/export'),
              ),
              const _SettingsRow(
                icon: Icons.upload_file_outlined,
                title: 'Import',
                subtitle: 'Bring in a CSV of past transactions',
                enabled: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Preferences'),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.account_circle_outlined,
                title: 'Account',
                subtitle: email.isEmpty ? currency : '$email · $currency',
                onTap: () => context.push('/account'),
              ),
              const _SettingsRow(
                icon: Icons.notifications_outlined,
                title: 'Evening reminder',
                subtitle: 'Set a time to log the day',
                enabled: false,
              ),
              const _SettingsRow(
                icon: Icons.workspace_premium_outlined,
                title: 'Plan & billing',
                subtitle: 'Manage your subscription',
                enabled: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.logout,
                title: 'Sign out',
                iconColor: colorScheme.error,
                titleColor: colorScheme.error,
                showChevron: false,
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, indent: 56, color: colorScheme.outline.withValues(alpha: 0.15)),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.onTap,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.enabled = true,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  /// False for features that exist on the roadmap but not in the app. The row
  /// stays visible and legible but is plainly inert — a row that silently does
  /// nothing when tapped reads as a bug, not as "not built yet".
  final bool enabled;

  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dim = colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    return ListTile(
      enabled: enabled,
      leading: Icon(
        icon,
        color: enabled ? (iconColor ?? colorScheme.onSurfaceVariant) : dim,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: enabled ? titleColor : dim,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: enabled ? null : theme.textTheme.bodySmall?.copyWith(color: dim),
            ),
      trailing: enabled
          ? (showChevron ? const Icon(Icons.chevron_right) : null)
          : const _ComingSoonTag(),
      onTap: enabled ? onTap : null,
    );
  }
}

class _ComingSoonTag extends StatelessWidget {
  const _ComingSoonTag();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Coming soon',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
