import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/resource_service.dart';

/// Miroir des hooks `useResourceList('etudiants', ...)`, etc. côté web — un `FutureProvider`
/// par ressource, mis en cache par riverpod comme TanStack Query le fait côté React.
final monDossierProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final list = await ResourceService('/etudiants').list();
  return list.isEmpty ? null : list.first;
});

final trimestresProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/trimestres').list());

final matieresProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/matieres').list());

final notesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/notes').list());

final emploiDuTempsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/emplois-du-temps').list());

final cahierTextesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/cahier-textes').list());

final presencesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/presences').list());

final bulletinsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/bulletins').list());
