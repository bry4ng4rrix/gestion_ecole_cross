import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/token_storage.dart';
import '../../models/user.dart';

/// Miroir de `authService.js` — mêmes endpoints, même contrat (`{access, refresh, user}`).
class AuthService {
  final _dio = ApiClient.instance.dio;

  /// [identifiant] accepte un email OU un matricule (résolu côté backend, voir
  /// `CustomTokenObtainPairSerializer`).
  Future<AppUser> login(String identifiant, String password) async {
    final response = await _dio.post('/auth/token/', data: {
      'email': identifiant,
      'password': password,
    });
    final data = response.data as Map<String, dynamic>;
    await TokenStorage.instance.save(access: data['access'] as String, refresh: data['refresh'] as String);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> fetchProfile() async {
    final response = await _dio.get('/auth/profile/');
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  /// Auto-inscription élève/parent (compte en attente de validation par l'établissement) —
  /// miroir de `authService.register` / `JoinForm` (frontend/src/pages/Register.jsx). [photo]
  /// optionnelle (rôle Élève uniquement) : photo du dossier étudiant créé côté serveur.
  Future<void> register(Map<String, dynamic> payload, {XFile? photo}) async {
    if (photo != null) {
      final form = FormData.fromMap({
        ...payload,
        'photo': MultipartFile.fromBytes(await photo.readAsBytes(), filename: photo.name),
      });
      await _dio.post('/auth/register/', data: form);
      return;
    }
    await _dio.post('/auth/register/', data: payload);
  }

  /// Création d'un nouvel établissement + de son compte administrateur — miroir de
  /// `authService.registerEcole` / `CreateEcoleForm` (frontend/src/pages/Register.jsx).
  Future<void> registerEcole(Map<String, dynamic> payload) async {
    await _dio.post('/auth/register/ecole/', data: payload);
  }

  /// Miroir de `MonProfilPanel.jsx` : mise à jour partielle (nom/prénom/téléphone + photo
  /// optionnelle). `XFile` (image_picker) fonctionne aussi bien mobile/desktop que web —
  /// contrairement à `dart:io File`, il expose `readAsBytes()` sur toutes les plateformes.
  Future<AppUser> updateProfile(Map<String, dynamic> champs, {XFile? photo}) async {
    if (photo != null) {
      final form = FormData.fromMap({
        ...champs,
        'photo': MultipartFile.fromBytes(await photo.readAsBytes(), filename: photo.name),
      });
      final response = await _dio.patch('/auth/profile/', data: form);
      return AppUser.fromJson(response.data as Map<String, dynamic>);
    }
    final response = await _dio.patch('/auth/profile/', data: champs);
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> changePassword(String ancien, String nouveau) async {
    await _dio.post('/auth/changer-mot-de-passe/', data: {
      'ancien_mot_de_passe': ancien,
      'nouveau_mot_de_passe': nouveau,
    });
  }

  Future<void> logout() async {
    await TokenStorage.instance.clear();
  }
}
