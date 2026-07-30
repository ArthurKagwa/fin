import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          _SectionLabel('Records'),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.history,
                title: 'History',
                subtitle: 'Browse past months',
                onTap: () {},
              ),
              _SettingsRow(
                icon: Icons.upload_file_outlined,
                title: 'Import',
                subtitle: 'Bring in a CSV of past transactions',
                onTap: () {},
              ),
              _SettingsRow(
                icon: Icons.download_outlined,
                title: 'Export',
                subtitle: 'Download your data as a CSV',
                onTap: () {},
              ),
              _SettingsRow(
                icon: Icons.bar_chart_outlined,
                title: 'Earnings report',
                subtitle: 'Gross vs. take-home by month',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionLabel('Preferences'),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.notifications_outlined,
                title: 'Evening reminder',
                subtitle: 'Set a time to log the day',
                onTap: () {},
              ),
              _SettingsRow(
                icon: Icons.account_circle_outlined,
                title: 'Account',
                subtitle: '$email · $currency',
                onTap: () {},
              ),
              _SettingsRow(
                icon: Icons.workspace_premium_outlined,
                title: 'Plan & billing',
                subtitle: 'Trial ends in 62 days',
                onTap: () {},
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
                onTap: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
        ],
      ),
    );
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
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: titleColor),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
