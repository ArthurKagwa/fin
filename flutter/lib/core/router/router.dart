import 'package:fintrack/core/widgets/scaffold_with_nav.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/auth/presentation/sign_in_screen.dart';
import 'package:fintrack/features/auth/presentation/verify_email_screen.dart';
import 'package:fintrack/features/buckets/presentation/bucket_detail_screen.dart';
import 'package:fintrack/features/buckets/presentation/bucket_form_screen.dart';
import 'package:fintrack/features/buckets/presentation/buckets_screen.dart';
import 'package:fintrack/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fintrack/features/income/presentation/income_list_screen.dart';
import 'package:fintrack/features/onboarding/presentation/currency_setup_screen.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/recurring/presentation/recurring_screen.dart';
import 'package:fintrack/features/settings/presentation/settings_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final authState = ref.watch(authStateProvider);
  final profileState = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = authState.asData?.value;
      final isSignedIn = user != null;
      final isVerified = user?.emailVerified ?? false;
      final hasCurrency = profileState.asData?.value != null;
      final isOnSignIn = state.matchedLocation == '/sign-in';
      final isOnVerifyEmail = state.matchedLocation == '/verify-email';
      final isOnCurrencySetup = state.matchedLocation == '/onboarding/currency';

      if (!isSignedIn) {
        return isOnSignIn ? null : '/sign-in';
      }
      if (!isVerified) {
        return isOnVerifyEmail ? null : '/verify-email';
      }
      if (!hasCurrency) {
        return isOnCurrencySetup ? null : '/onboarding/currency';
      }
      if (isOnSignIn || isOnVerifyEmail || isOnCurrencySetup) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/onboarding/currency',
        builder: (context, state) => const CurrencySetupScreen(),
      ),
      GoRoute(
        path: '/buckets',
        builder: (context, state) => const BucketsScreen(),
      ),
      GoRoute(
        path: '/buckets/new',
        builder: (context, state) => const BucketFormScreen(),
      ),
      GoRoute(
        path: '/buckets/:id/edit',
        builder: (context, state) =>
            BucketFormScreen(bucketId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/buckets/:id',
        builder: (context, state) =>
            BucketDetailScreen(bucketId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            ScaffoldWithNav(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/money-in',
                builder: (context, state) => const IncomeListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recurring',
                builder: (context, state) => const RecurringScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
