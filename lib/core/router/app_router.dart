import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';
import '../../models/user.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/student/student_shell.dart';
import '../../features/teacher/teacher_shell.dart';
import '../../features/parent/parent_shell.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/gardien/gardien_shell.dart';

/// Équivalent de `ROLE_HOME` (frontend/src/components/ProtectedRoute.jsx) — seuls les rôles
/// couverts par cette application mobile ont une destination ; les autres (RESPONSABLE,
/// SECRETARIAT) restent sur le web pour l'instant.
String? roleHome(UserRole role) {
  switch (role) {
    case UserRole.etudiant:
      return '/student';
    case UserRole.enseignant:
      return '/teacher';
    case UserRole.parent:
      return '/parent';
    case UserRole.admin:
      return '/admin';
    case UserRole.gardien:
      return '/gardien';
    default:
      return null;
  }
}

/// Pont entre le `StateNotifier` riverpod et l'API `Listenable` attendue par go_router
/// pour redéclencher `redirect` à chaque changement d'état d'authentification.
class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _GoRouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;

      if (auth.isLoading) return null;

      if (!auth.isAuthenticated) {
        return (loc == '/login' || loc == '/register') ? null : '/login';
      }

      final home = roleHome(auth.user!.role);
      if (loc == '/login' || loc == '/') {
        return home ?? '/unsupported';
      }
      if (home == null) {
        return loc == '/unsupported' ? null : '/unsupported';
      }
      if (!loc.startsWith(home)) {
        return home;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/unsupported', builder: (context, state) => const _UnsupportedRoleScreen()),
      GoRoute(path: '/student', builder: (context, state) => const StudentShell()),
      GoRoute(path: '/teacher', builder: (context, state) => const TeacherShell()),
      GoRoute(path: '/parent', builder: (context, state) => const ParentShell()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminShell()),
      GoRoute(path: '/gardien', builder: (context, state) => const GardienShell()),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _UnsupportedRoleScreen extends ConsumerWidget {
  const _UnsupportedRoleScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Votre rôle n'est pas encore pris en charge par l'application mobile.\n"
                "Utilisez la version web en attendant.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                child: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
