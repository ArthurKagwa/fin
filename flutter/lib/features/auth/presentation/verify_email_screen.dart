import 'dart:async';

import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/auth/presentation/email_verification_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(emailVerificationControllerProvider.notifier).checkVerified();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    await ref.read(emailVerificationControllerProvider.notifier).resend();
    setState(() => _resendCooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown -= 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authStateProvider).asData?.value?.email ?? '';
    final state = ref.watch(emailVerificationControllerProvider);

    ref.listen(emailVerificationControllerProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString())),
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
              Icon(
                Icons.mark_email_unread_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to $email. '
                'Confirm it to start using FinTrack.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: state.isLoading
                    ? null
                    : () => ref
                        .read(emailVerificationControllerProvider.notifier)
                        .checkVerified(),
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("I've verified my email"),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _resendCooldown > 0 || state.isLoading
                    ? null
                    : _resend,
                child: Text(
                  _resendCooldown > 0
                      ? 'Resend email (${_resendCooldown}s)'
                      : 'Resend email',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
