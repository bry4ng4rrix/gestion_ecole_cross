import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/token_storage.dart';
import '../../models/user.dart';
import 'auth_service.dart';

/// Miroir de `AuthContext.jsx` : restaure la session depuis le token stocké au démarrage,
/// expose login/logout, et sert de source de vérité pour les gardes de route par rôle.
class AuthState {
  final AppUser? user;
  final bool isLoading;

  const AuthState({this.user, this.isLoading = true});

  bool get isAuthenticated => user != null;

  AuthState copyWith({AppUser? user, bool? isLoading}) =>
      AuthState(user: user ?? this.user, isLoading: isLoading ?? this.isLoading);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _restoreSession();
  }

  final _service = AuthService();

  Future<void> _restoreSession() async {
    // Toute défaillance ici (stockage sécurisé indisponible, token expiré, réseau...) doit
    // retomber sur "non connecté" plutôt que de laisser l'état bloqué en isLoading=true —
    // sinon le router reste indéfiniment sur l'écran de démarrage (voir test/widget_test.dart).
    try {
      final access = await TokenStorage.instance.readAccess();
      if (access == null) {
        state = const AuthState(isLoading: false);
        return;
      }
      final user = await _service.fetchProfile();
      state = AuthState(user: user, isLoading: false);
    } catch (_) {
      try {
        await TokenStorage.instance.clear();
      } catch (_) {
        // Stockage sécurisé indisponible : rien de plus à faire, on reste "non connecté".
      }
      state = const AuthState(isLoading: false);
    }
  }

  Future<AppUser> login(String identifiant, String password) async {
    final user = await _service.login(identifiant, password);
    state = AuthState(user: user, isLoading: false);
    return user;
  }

  Future<void> logout() async {
    // Même si l'effacement du stockage sécurisé échoue (trousseau indisponible), l'état
    // applicatif doit repasser "non connecté" — sinon l'utilisateur reste bloqué sur son
    // tableau de bord sans pouvoir revenir à l'écran de connexion.
    try {
      await _service.logout();
    } catch (_) {
      // Ignoré volontairement, voir commentaire ci-dessus.
    }
    state = const AuthState(isLoading: false);
  }

  void setUser(AppUser user) => state = state.copyWith(user: user);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
