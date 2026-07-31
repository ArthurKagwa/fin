import 'package:fintrack/core/app_lock/app_lock_controller.dart';
import 'package:fintrack/core/app_lock/lock_screen.dart';
import 'package:fintrack/core/widgets/scaffold_with_nav.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/auth/presentation/sign_in_screen.dart';
import 'package:fintrack/features/auth/presentation/verify_email_screen.dart';
import 'package:fintrack/features/buckets/presentation/bucket_detail_screen.dart';
import 'package:fintrack/features/buckets/presentation/bucket_form_screen.dart';
import 'package:fintrack/features/buckets/presentation/buckets_screen.dart';
import 'package:fintrack/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fintrack/features/earnings/presentation/earnings_screen.dart';
import 'package:fintrack/features/expenses/presentation/transactions_screen.dart';
import 'package:fintrack/features/imports/presentation/import_screen.dart';
import 'package:fintrack/features/income/presentation/income_list_screen.dart';
import 'package:fintrack/features/onboarding/presentation/currency_setup_screen.dart';
import 'package:fintrack/features/planning/presentation/plan_editor_screen.dart';
import 'package:fintrack/features/planning/presentation/plan_vs_actual_screen.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/profile/presentation/account_screen.dart';
import 'package:fintrack/features/recurring/presentation/recurring_form_screen.dart';
import 'package:fintrack/features/recurring/presentation/recurring_screen.dart';
import 'package:fintrack/features/reports/presentation/export_screen.dart';
import 'package:fintrack/features/settings/presentation/settings_screen.dart';
import 'package:fintrack/features/trends/presentation/trends_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final authState = ref.watch(authStateProvider);
  final profileState = ref.watch(userProfileProvider);
  final lockState = ref.watch(appLockControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = authState.asData?.value;
      final isSignedIn = user != null;
      final isVerified = user?.emailVerified ?? false;
      final hasCurrency = profileState.asData?.value != null;
      final isLocked = lockState.asData?.value.shouldBlock ?? false;
      final isOnSignIn = state.matchedLocation == '/sign-in';
      final isOnVerifyEmail = state.matchedLocation == '/verify-email';
      final isOnCurrencySetup = state.matchedLocation == '/onboarding/currency';
      final isOnLock = state.matchedLocation == '/lock';

      if (!isSignedIn) {
        return isOnSignIn ? null : '/sign-in';
      }
      if (!isVerified) {
        return isOnVerifyEmail ? null : '/verify-email';
      }
      // Before onboarding, not after: someone resuming mid-setup should
      // still have to unlock first.
      if (isLocked) {
        return isOnLock ? null : '/lock';
      }
      if (isOnLock) return '/';
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
        path: '/lock',
        builder: (context, state) => const LockScreen(),
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
      GoRoute(
        path: '/plan',
        builder: (context, state) => const PlanVsActualScreen(),
      ),
      GoRoute(
        path: '/plan/edit',
        builder: (context, state) => const PlanEditorScreen(),
      ),
      GoRoute(
        path: '/earnings',
        builder: (context, state) => const EarningsScreen(),
      ),
      GoRoute(
        path: '/export',
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionsScreen(),
      ),
      GoRoute(
        path: '/import',
        builder: (context, state) => const ImportScreen(),
      ),
      GoRoute(
        path: '/trends',
        builder: (context, state) => const TrendsScreen(),
      ),
      GoRoute(
        path: '/recurring/new',
        builder: (context, state) => const RecurringFormScreen(),
      ),
      GoRoute(
        path: '/recurring/:id/edit',
        builder: (context, state) =>
            RecurringFormScreen(paymentId: state.pathParameters['id']),
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
