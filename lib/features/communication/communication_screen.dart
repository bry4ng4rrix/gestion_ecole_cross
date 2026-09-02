import 'package:flutter/material.dart';

import 'annonces_panel.dart';
import 'messagerie_panel.dart';

/// Miroir de `CommunicationTab` (frontend/src/pages/ParentDashboard.jsx et équivalents) :
/// deux sous-onglets Annonces / Messagerie, réutilisé par les 4 rôles.
class CommunicationScreen extends StatelessWidget {
  const CommunicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Annonces'), Tab(text: 'Messagerie')]),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [AnnoncesPanel(), MessageriePanel()],
            ),
          ),
        ],
      ),
    );
  }
}
