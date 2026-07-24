import 'package:fintrack/core/widgets/scaffold_with_nav.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/auth/presentation/sign_in_screen.dart';
import 'package:fintrack/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fintrack/features/income/presentation/income_list_screen.dart';
import 'package:fintrack/features/recurring/presentation/recurring_screen.dart';
import 'package:fintrack/features/settings/presentation/settings_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isSignedIn = authState.asData?.value != null;
      final isOnSignIn = state.matchedLocation == '/sign-in';

      if (!isSignedIn && !isOnSignIn) return '/sign-in';
      if (isSignedIn && isOnSignIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
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
