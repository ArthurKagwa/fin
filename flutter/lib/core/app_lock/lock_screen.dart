import 'package:fintrack/core/app_lock/app_lock_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stands in front of the whole app while app lock is engaged.
///
/// No back affordance and nothing readable behind it — the router redirect
/// is what actually enforces that, this screen just gives the OS prompt
/// somewhere to sit and a way to retry if it's dismissed.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _prompting = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    // Prompt immediately rather than making the user tap first — the tap
    // would be pure ceremony on the common path.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_prompting) return;
    setState(() {
      _prompting = true;
      _dismissed = false;
    });
    final ok = await ref.read(appLockControllerProvider.notifier).unlock();
    if (!mounted) return;
    setState(() {
      _prompting = false;
      _dismissed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.lock_outline, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'FinTrack is locked',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                _dismissed
                    ? 'Unlock with your usual screen lock to continue.'
                    : 'Confirm it\'s you to continue.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _prompting ? null : _unlock,
                child: _prompting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Unlock'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
