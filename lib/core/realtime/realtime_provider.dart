import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import 'realtime_client.dart';

final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = RealtimeClient();
  ref.onDispose(client.disconnect);
  return client;
});

/// Pont entre l'état d'authentification et le cycle de vie du WebSocket — même mécanique que
/// `_GoRouterRefreshNotifier` (core/router/app_router.dart) : un `ref.listen` hors arbre de
/// widgets. Gardé vivant depuis `SigLyceeApp.build()` via `ref.watch(realtimeConnectionProvider)`.
final realtimeConnectionProvider = Provider<void>((ref) {
  final client = ref.watch(realtimeClientProvider);
  ref.listen(authProvider, (previous, next) {
    if (next.isAuthenticated) {
      client.connect();
    } else {
      client.disconnect();
    }
  }, fireImmediately: true);
});

/// Flux d'événements temps réel — chaque écran fait son propre `ref.listen` dessus et
/// invalide les providers qu'il connaît (pattern `FutureProvider.autoDispose.family`, où
/// `ref.invalidate(provider)` sans argument invalide toutes les instances en cache), comme il
/// gérait auparavant son propre `Timer.periodic` — voir
/// features/teacher/screens/teacher_chat_screen.dart pour un exemple de migration.
final realtimeEventProvider = StreamProvider<RealtimeEvent>((ref) {
  final client = ref.watch(realtimeClientProvider);
  return client.events;
});
