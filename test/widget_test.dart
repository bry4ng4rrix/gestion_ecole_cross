import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cross/main.dart';

void main() {
  // `flutter_secure_storage` n'a pas d'implémentation native dans l'environnement de test
  // (pas de plateforme réelle) — on simule "aucun token stocké" pour que la restauration de
  // session (AuthNotifier._restoreSession) se résolve de façon déterministe.
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'read' ? null : <String, String>{},
    );
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('App boots to the login screen when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SigLyceeApp()));
    await tester.pumpAndSettle();

    expect(find.text('SIG-Lycée'), findsWidgets);
    expect(find.text('Connexion'), findsOneWidget);
  });
}
