import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Équivalent de `apiClient.js`'s `getStoredTokens`/`storeTokens`, mais en stockage
/// sécurisé (Keychain/Keystore) plutôt que localStorage — plus adapté à un client mobile.
class TokenStorage {
  TokenStorage._();
  static final instance = TokenStorage._();

  final _storage = const FlutterSecureStorage();
  static const _accessKey = 'sig_lycee_access';
  static const _refreshKey = 'sig_lycee_refresh';

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> updateAccess(String access) => _storage.write(key: _accessKey, value: access);

  Future<String?> readAccess() => _storage.read(key: _accessKey);
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
