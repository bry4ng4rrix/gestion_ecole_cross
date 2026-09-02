import 'package:dio/dio.dart';

import 'token_storage.dart';

/// Base URL du backend Django : pointe par défaut sur le VPS de production (même IP:port
/// que `VITE_API_URL` côté frontend web, voir `.env.example` à la racine), joignable de la
/// même façon depuis toutes les plateformes (web, émulateur/simulateur, appareil réel).
/// Pour un backend local de dev, lancer avec `--dart-define=API_BASE_URL=http://<ip>:8000/api`
/// (ex: `http://10.0.2.2:8000/api` sur émulateur Android, `http://127.0.0.1:8000/api` ailleurs).
String _defaultBaseUrl() => 'http://157.173.103.147:8030/api';

const _envBaseUrl = String.fromEnvironment('API_BASE_URL');

class ApiClient {
  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: _envBaseUrl.isNotEmpty ? _envBaseUrl : _defaultBaseUrl(),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    dio.interceptors.add(_AuthInterceptor(dio));
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio dio;

  /// Origine du serveur (schéma+hôte+port, sans `/api`) — pour résoudre une URL de média
  /// relative (ex. `/media/photos_profils/x.jpg`) que le backend pourrait renvoyer sans la
  /// construire en absolu. DRF le fait normalement via `request.build_absolute_uri()`, mais
  /// s'appuyer uniquement sur ça est fragile (dépend du header Host reçu) — donc on résout
  /// nous-mêmes côté client par sécurité.
  String get mediaOrigin {
    final uri = Uri.parse(dio.options.baseUrl);
    return '${uri.scheme}://${uri.authority}';
  }

  /// Renvoie une URL de média absolue et chargeable par `NetworkImage`, que [path] soit déjà
  /// absolu ou relatif (voire vide/null, auquel cas `null` est renvoyé).
  String? resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return path.startsWith('/') ? '$mediaOrigin$path' : '$mediaOrigin/$path';
  }
}

/// Reproduit le comportement de `apiClient.js` : injecte le Bearer token sur chaque
/// requête, et sur un 401 (hors endpoints d'auth), tente un rafraîchissement unique
/// partagé par toutes les requêtes concurrentes avant de rejouer la requête d'origine.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);

  final Dio _dio;
  Future<String?>? _refreshing;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Un échec de lecture (ex. trousseau/Secret Service indisponible sur certains
    // environnements Linux sans gnome-keyring/kwallet actif) ne doit pas faire échouer
    // TOUTES les requêtes — on part alors du principe qu'il n'y a pas de session, plutôt
    // que de laisser l'exception remonter et transformer chaque appel en erreur réseau.
    String? access;
    try {
      access = await TokenStorage.instance.readAccess();
    } catch (_) {
      access = null;
    }
    if (access != null) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final path = err.requestOptions.path;
    final isAuthEndpoint = path.contains('/auth/token');
    final alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (response?.statusCode != 401 || isAuthEndpoint || alreadyRetried) {
      handler.next(err);
      return;
    }

    try {
      final refresh = await TokenStorage.instance.readRefresh();
      if (refresh == null) {
        await TokenStorage.instance.clear();
        handler.next(err);
        return;
      }

      _refreshing ??= _doRefresh(refresh);
      final newAccess = await _refreshing;
      _refreshing = null;
      if (newAccess == null) throw Exception('refresh failed');

      final retryOptions = err.requestOptions;
      retryOptions.extra['retried'] = true;
      retryOptions.headers['Authorization'] = 'Bearer $newAccess';
      final response = await _dio.fetch(retryOptions);
      handler.resolve(response);
    } catch (_) {
      _refreshing = null;
      try {
        await TokenStorage.instance.clear();
      } catch (_) {
        // Stockage sécurisé indisponible : rien de plus à faire.
      }
      handler.next(err);
    }
  }

  Future<String?> _doRefresh(String refresh) async {
    final response = await Dio(BaseOptions(baseUrl: _dio.options.baseUrl))
        .post('/auth/token/refresh/', data: {'refresh': refresh});
    final access = response.data['access'] as String;
    await TokenStorage.instance.updateAccess(access);
    return access;
  }
}
