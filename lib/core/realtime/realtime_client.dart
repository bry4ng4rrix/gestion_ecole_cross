import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api_client.dart';
import '../api/token_storage.dart';

/// Miroir de `frontend/src/lib/realtimeClient.js` : enveloppe générique émise par
/// `application/services/realtime.py::broadcast` côté backend.
class RealtimeEvent {
  final String resource;
  final String action;
  final dynamic id;
  final int? ecoleId;
  final Map<String, dynamic>? data;

  RealtimeEvent({required this.resource, required this.action, this.id, this.ecoleId, this.data});

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) => RealtimeEvent(
        resource: json['resource'] as String,
        action: json['action'] as String,
        id: json['id'],
        ecoleId: json['ecole_id'] as int?,
        data: json['data'] as Map<String, dynamic>?,
      );
}

const _envWsUrl = String.fromEnvironment('WS_BASE_URL');

/// Dérive l'URL WebSocket de la base URL REST (même host, http(s) -> ws(s), sans `/api`) —
/// même principe que `_defaultBaseUrl()` dans `core/api/api_client.dart`. Surchageable via
/// `--dart-define=WS_BASE_URL=...` si le WS doit passer par une origine différente.
String _deriveWsUrl() {
  if (_envWsUrl.isNotEmpty) return _envWsUrl;
  final apiUri = Uri.parse(ApiClient.instance.dio.options.baseUrl);
  final wsScheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
  return apiUri.replace(scheme: wsScheme, path: '/ws/realtime/', query: '').toString();
}

const _reconnectMinDelay = Duration(seconds: 1);
const _reconnectMaxDelay = Duration(seconds: 30);

/// Un seul WebSocket par session, ouvert/fermé par `realtimeConnectionProvider` selon
/// l'état auth. Les écrans écoutent `events` (via `realtimeEventProvider`) et invalident
/// eux-mêmes les providers Riverpod qu'ils connaissent — pas de dispatcher central, voir
/// features/teacher/screens/teacher_chat_screen.dart pour un exemple de migration.
class RealtimeClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Duration _reconnectDelay = _reconnectMinDelay;
  bool _closedByUs = false;

  final _controller = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _controller.stream;

  Future<void> connect() async {
    final access = await TokenStorage.instance.readAccess();
    if (access == null) return;
    _closedByUs = false;
    _open(access);
  }

  void disconnect() {
    _closedByUs = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void _open(String accessToken) {
    final uri = Uri.parse(_deriveWsUrl()).replace(queryParameters: {'token': accessToken});
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _reconnectDelay = _reconnectMinDelay;

    _subscription = channel.stream.listen(
      _handleMessage,
      onDone: () => _handleClose(channel.closeCode),
      onError: (_) => _handleClose(channel.closeCode),
      cancelOnError: true,
    );
  }

  void _handleMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      _controller.add(RealtimeEvent.fromJson(json));
    } catch (_) {
      // Message non conforme à l'enveloppe attendue : ignoré.
    }
  }

  void _handleClose(int? code) {
    if (_closedByUs) return;
    if (code == 4401) {
      _refreshAndReconnect();
      return;
    }
    _scheduleReconnect();
  }

  Future<void> _refreshAndReconnect() async {
    final refresh = await TokenStorage.instance.readRefresh();
    if (refresh == null) return;
    try {
      final response = await Dio(BaseOptions(baseUrl: ApiClient.instance.dio.options.baseUrl))
          .post('/auth/token/refresh/', data: {'refresh': refresh});
      final access = response.data['access'] as String;
      await TokenStorage.instance.updateAccess(access);
      _open(access);
    } catch (_) {
      // Abandon silencieux : le prochain 401 REST déclenche la déconnexion normale
      // (intercepteur de api_client.dart -> authProvider).
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      if (_closedByUs) return;
      final access = await TokenStorage.instance.readAccess();
      if (access == null) return;
      _open(access);
    });
    final next = _reconnectDelay * 2;
    _reconnectDelay = next > _reconnectMaxDelay ? _reconnectMaxDelay : next;
  }
}
