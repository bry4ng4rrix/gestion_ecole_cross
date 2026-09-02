import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/resource_service.dart';

/// `/etudiants/`, `/bulletins/` et `/presences/` sont déjà scopés côté backend aux enfants
/// du parent connecté — mêmes hooks `useResourceList` que côté web, juste en riverpod.
final mesEnfantsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/etudiants').list());

final parentTrimestresProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/trimestres').list());

final parentBulletinsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/bulletins').list());

final parentPresencesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/presences').list());

final anneesScolairesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/annees-scolaires').list());

/// QR code de sortie (image) d'un enfant — partagé entre l'onglet "Mes Enfants" (affichage
/// direct dans la liste) et l'onglet "QR code enfant(s)" (imprimable en grand).
final qrSortieBytesProvider = FutureProvider.autoDispose.family<Uint8List, int>((ref, etudiantId) async {
  final response = await ApiClient.instance.dio.get<List<int>>(
    '/etudiants/$etudiantId/qrcode-sortie/',
    options: Options(responseType: ResponseType.bytes),
  );
  return Uint8List.fromList(response.data!);
});

/// Miroir de `fetchMoyenneTrimestre` (frontend/src/services/index.js).
final moyenneEnfantProvider = FutureProvider.family<double?, ({int etudiantId, int trimestreId})>((ref, args) async {
  final response = await ApiClient.instance.dio.get('/notes/moyenne/', queryParameters: {
    'etudiant': args.etudiantId,
    'trimestre': args.trimestreId,
  });
  final moyenne = response.data['moyenne'];
  return moyenne == null ? null : double.tryParse('$moyenne');
});
