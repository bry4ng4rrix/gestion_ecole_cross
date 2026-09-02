import 'package:dio/dio.dart';

import 'api_client.dart';

/// Miroir de `createResourceService(basePath)` (frontend/src/services/index.js) : un client
/// CRUD générique par ressource DRF, pour éviter de réécrire list/create/update/delete à
/// chaque nouveau modèle. [basePath] sans slash final, ex. `/etudiants` — même convention
/// que côté web.
class ResourceService {
  final String basePath;
  final Dio _dio = ApiClient.instance.dio;

  ResourceService(this.basePath);

  Future<List<Map<String, dynamic>>> list([Map<String, dynamic>? params]) async {
    final response = await _dio.get('$basePath/', queryParameters: params);
    final data = response.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    // Pagination DRF classique ({count, results}) si jamais activée un jour.
    if (data is Map && data['results'] is List) {
      return (data['results'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> get(dynamic id) async {
    final response = await _dio.get('$basePath/$id/');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    final response = await _dio.post('$basePath/', data: payload);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(dynamic id, Map<String, dynamic> payload) async {
    final response = await _dio.patch('$basePath/$id/', data: payload);
    return response.data as Map<String, dynamic>;
  }

  Future<void> remove(dynamic id) => _dio.delete('$basePath/$id/');

  Future<dynamic> action(dynamic id, String actionName, {Map<String, dynamic>? payload, String method = 'post'}) async {
    final path = id == null ? '$basePath/$actionName/' : '$basePath/$id/$actionName/';
    final response = method == 'get'
        ? await _dio.get(path, queryParameters: payload)
        : await _dio.post(path, data: payload);
    return response.data;
  }
}
