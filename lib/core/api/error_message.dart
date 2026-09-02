import 'dart:convert';

import 'package:dio/dio.dart';

/// Extrait le message d'erreur renvoyé par le backend (`{"detail": "..."}`) — miroir de
/// `err.response?.data?.detail` (frontend/src/components/etudiants/EtudiantsPanel.jsx) —
/// plutôt que d'afficher un message générique qui masque la vraie raison (ex. "Le droit
/// d'inscription est déjà payé.").
///
/// Les requêtes de téléchargement (`responseType: ResponseType.bytes`) reçoivent le corps
/// de la réponse SOUS FORME D'OCTETS BRUTS même en cas d'erreur — `response.data` n'est
/// alors pas un `Map` déjà décodé mais un `List<int>` : il faut le décoder nous-mêmes avant
/// de pouvoir y lire `detail`.
String messageErreur(Object erreur, String repli) {
  if (erreur is! DioException) return repli;
  var data = erreur.response?.data;
  if (data is List<int>) {
    try {
      data = jsonDecode(utf8.decode(data));
    } catch (_) {
      return repli;
    }
  }
  if (data is Map && data['detail'] is String) return data['detail'] as String;
  return repli;
}

/// Variante qui concatène TOUTES les erreurs de champs (`{"email": ["..."], "ecole": ["..."]}`)
/// plutôt que de ne lire que `detail` — miroir de `Object.values(data).flat().join(' ')`
/// (formulaires de création/modification, EtudiantsPanel.jsx / Register.jsx).
String messageErreurChamps(Object erreur, String repli) {
  if (erreur is! DioException) return repli;
  var data = erreur.response?.data;
  if (data is List<int>) {
    try {
      data = jsonDecode(utf8.decode(data));
    } catch (_) {
      return repli;
    }
  }
  if (data is Map && data.isNotEmpty) {
    return data.values.expand((v) => v is List ? v : [v]).join(' ');
  }
  return repli;
}
