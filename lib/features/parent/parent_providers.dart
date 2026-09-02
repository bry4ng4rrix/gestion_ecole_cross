import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/resource_service.dart';

/// `/etudiants/`, `/bulletins/` et `/presences/` sont déjà scopés côté backend aux enfants
/// du parent connecté — mêmes hooks `useResourceList` que côté web, juste en riverpod.
final mesEnfantsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/etudiants').list());

final parentTrimestresProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/trimestres').list());

final parentBulletinsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/bulletins').list());

final parentPresencesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/presences').list());

/// Miroir de `fetchMoyenneTrimestre` (frontend/src/services/index.js).
final moyenneEnfantProvider = FutureProvider.family<double?, ({int etudiantId, int trimestreId})>((ref, args) async {
  final response = await ApiClient.instance.dio.get('/notes/moyenne/', queryParameters: {
    'etudiant': args.etudiantId,
    'trimestre': args.trimestreId,
  });
  final moyenne = response.data['moyenne'];
  return moyenne == null ? null : double.tryParse('$moyenne');
});
