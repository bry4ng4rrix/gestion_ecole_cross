import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

Future<void> downloadAndOpen(String path, String fileName) async {
  final response = await ApiClient.instance.dio.get<List<int>>(
    path,
    options: Options(responseType: ResponseType.bytes),
  );
  await _enregistrerEtOuvrir(response.data!, fileName);
}

/// Variante POST de [downloadAndOpen] — certains endpoits de génération PDF déclenchent
/// un effet de bord (ex. validation d'office d'un certificat) et n'utilisent donc pas GET.
Future<void> downloadAndOpenPost(String path, String fileName) async {
  final response = await ApiClient.instance.dio.post<List<int>>(
    path,
    options: Options(responseType: ResponseType.bytes),
  );
  await _enregistrerEtOuvrir(response.data!, fileName);
}

Future<void> _enregistrerEtOuvrir(List<int> bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  await OpenFilex.open(file.path);
}
