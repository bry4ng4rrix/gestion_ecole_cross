import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/resource_service.dart';

/// Le backend scope déjà `/classes/`, `/matieres/`, `/notes/`, `/emplois-du-temps/` et
/// `/cahier-textes/` aux seules données de l'enseignant connecté — pas de filtrage
/// supplémentaire à faire côté client (même principe que côté web).
final teacherClassesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/classes').list());

final teacherMatieresProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/matieres').list());

final teacherTrimestresProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/trimestres').list());

final teacherEtudiantsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/etudiants').list());

final teacherNotesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/notes').list());

final teacherEmploiDuTempsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/emplois-du-temps').list());

final teacherCahierTextesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) => ResourceService('/cahier-textes').list());
