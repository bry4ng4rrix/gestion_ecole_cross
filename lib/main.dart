import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/realtime/realtime_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: SigLyceeApp()));
}

class SigLyceeApp extends ConsumerWidget {
  const SigLyceeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Garde le WebSocket temps réel vivant pour toute la durée de l'app (ouvert/fermé selon
    // authProvider — voir core/realtime/realtime_provider.dart).
    ref.watch(realtimeConnectionProvider);
    return MaterialApp.router(
      title: 'SIG-Lycée',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
