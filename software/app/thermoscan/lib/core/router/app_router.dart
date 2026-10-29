import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thermoscan/features/auth/presentation/auth_controller.dart';
import 'package:thermoscan/features/auth/presentation/login_screen.dart';
import 'package:thermoscan/features/auth/presentation/mandatory_password_change_screen.dart';
import 'package:thermoscan/features/auth/presentation/splash_screen.dart';
import 'package:thermoscan/features/companies/presentation/companies_home_screen.dart';
import 'package:thermoscan/features/companies/presentation/company_details_screen.dart';
import 'package:thermoscan/features/companies/presentation/create_company_screen.dart';
import 'package:thermoscan/features/home/presentation/phase1_role_home_screen.dart';
import 'package:thermoscan/features/profile/presentation/profile_screen.dart';
import 'package:thermoscan/features/users/presentation/manager_admin_home_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(
      authControllerProvider,
      (_, _) => notifyListeners(),
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // 1. While verifying stored session, stay on /splash (SCR-01)
      if (authState.status == AuthStatus.initializing) {
        return location == '/splash' ? null : '/splash';
      }

      // 2. Unauthenticated -> force /login (SCR-02)
      if (!authState.isAuthenticated) {
        return location == '/login' ? null : '/login';
      }

      final user = authState.user!;

      // 3. Mandatory password change enforcement -> force /change-password (SCR-03)
      if (user.mustChangePassword) {
        return location == '/change-password' ? null : '/change-password';
      }

      // 4. Authenticated & password already changed:
      // Redirect away from auth onboarding screens to role-appropriate home
      if (location == '/splash' ||
          location == '/login' ||
          location == '/change-password') {
        return user.homeRoute;
      }

      // 5. Role-based route guards
      if (location.startsWith('/admin') && !user.isSystemAdmin) {
        return user.homeRoute;
      }
      if (location.startsWith('/manager') && !user.isManager) {
        return user.homeRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const MandatoryPasswordChangeScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/admin/companies',
        builder: (context, state) => const CompaniesHomeScreen(),
      ),
      GoRoute(
        path: '/admin/companies/new',
        builder: (context, state) => const CreateCompanyScreen(),
      ),
      GoRoute(
        path: '/admin/companies/:companyId',
        builder: (context, state) {
          final companyId = state.pathParameters['companyId'] ?? '';
          return CompanyDetailsScreen(companyId: companyId);
        },
      ),
      GoRoute(
        path: '/manager',
        builder: (context, state) => const ManagerAdminHomeScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Phase1RoleHomeScreen(),
      ),
    ],
  );
});
