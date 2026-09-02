import 'package:flutter/material.dart';

import '../../core/widgets/role_shell.dart';
import '../communication/communication_screen.dart';
import 'screens/admin_academique_screen.dart';
import 'screens/admin_administrative_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_edt_screen.dart';
import 'screens/admin_etudiants_screen.dart';
import 'screens/admin_inscriptions_screen.dart';
import 'screens/admin_notes_screen.dart';
import 'screens/admin_personnel_screen.dart';
import 'screens/admin_presence_screen.dart';
import 'screens/admin_rapports_screen.dart';

/// Miroir de AdminDashboard.jsx (frontend/src/pages/AdminDashboard.jsx).
const _items = [
  NavItem(id: 'home', label: 'Tableau de bord', icon: Icons.home_rounded),
  NavItem(id: 'etudiants', label: 'Gestion Étudiants', icon: Icons.groups_rounded),
  NavItem(id: 'inscriptions', label: "Demandes d'inscription", icon: Icons.person_add_rounded),
  NavItem(id: 'enseignants', label: 'Gestion des Profs', icon: Icons.school_rounded),
  NavItem(id: 'academique', label: 'Gestion Académique', icon: Icons.layers_rounded),
  NavItem(id: 'emploi-du-temps', label: 'Emploi du Temps', icon: Icons.calendar_month_rounded),
  NavItem(id: 'notes', label: 'Notes & Évaluations', icon: Icons.speed_rounded),
  NavItem(id: 'presence', label: 'Présence & Absences', icon: Icons.access_time_rounded),
  NavItem(id: 'admin', label: 'Gestion Administrative', icon: Icons.storage_rounded),
  NavItem(id: 'communication', label: 'Communication', icon: Icons.forum_rounded),
  NavItem(id: 'rapports', label: 'Rapports & Stats', icon: Icons.bar_chart_rounded),
];

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      appTitle: 'SIG-Lycée · Admin',
      items: _items,
      screenBuilder: (context, id) {
        switch (id) {
          case 'home':
            return const AdminDashboardScreen();
          case 'etudiants':
            return const AdminEtudiantsScreen();
          case 'inscriptions':
            return const AdminInscriptionsScreen();
          case 'enseignants':
            return const AdminPersonnelScreen(roleFilter: 'ENSEIGNANT', title: 'Gestion des Profs');
          case 'academique':
            return const AdminAcademiqueScreen();
          case 'emploi-du-temps':
            return const AdminEdtScreen();
          case 'notes':
            return const AdminNotesScreen();
          case 'presence':
            return const AdminPresenceScreen();
          case 'admin':
            return const AdminAdministrativeScreen();
          case 'communication':
            return const CommunicationScreen();
          case 'rapports':
            return const AdminRapportsScreen();
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
