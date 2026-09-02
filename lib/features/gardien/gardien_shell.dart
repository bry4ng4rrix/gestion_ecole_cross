import 'package:flutter/material.dart';

import '../../core/widgets/role_shell.dart';
import 'screens/gardien_scanner_screen.dart';
import 'screens/gardien_historique_screen.dart';

/// Coquille du rôle Gardien : contrôle de sortie des élèves par scan de QR code.
const _items = [
  NavItem(id: 'scanner', label: 'Scanner', icon: Icons.qr_code_scanner_rounded),
  NavItem(id: 'historique', label: 'Historique', icon: Icons.history_rounded),
];

class GardienShell extends StatelessWidget {
  const GardienShell({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      appTitle: 'SIG-Lycée · Gardien',
      items: _items,
      screenBuilder: (context, id) {
        switch (id) {
          case 'scanner':
            return const GardienScannerScreen();
          case 'historique':
            return const GardienHistoriqueScreen();
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
