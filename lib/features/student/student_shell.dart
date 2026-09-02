import 'package:flutter/material.dart';

import '../../core/widgets/role_shell.dart';
import '../communication/communication_screen.dart';
import 'screens/student_academique_screen.dart';
import 'screens/student_dashboard_screen.dart';
import 'screens/student_edt_screen.dart';
import 'screens/student_notes_screen.dart';
import 'screens/student_devoirs_screen.dart';
import 'screens/student_presence_screen.dart';
import 'screens/student_profil_screen.dart';
import 'screens/student_administratif_screen.dart';
import 'screens/student_documents_screen.dart';

/// Miroir de StudentDashboard.jsx — même liste de sections (frontend/src/pages/StudentDashboard.jsx).
const _items = [
  NavItem(id: 'home', label: 'Tableau de bord', icon: Icons.home_rounded),
  NavItem(id: 'profil', label: 'Mon Profil', icon: Icons.person_rounded),
  NavItem(id: 'academique', label: 'Gestion Académique', icon: Icons.layers_rounded),
  NavItem(id: 'edt', label: 'Emploi du Temps', icon: Icons.calendar_month_rounded),
  NavItem(id: 'devoirs', label: 'Devoirs', icon: Icons.assignment_rounded),
  NavItem(id: 'notes', label: 'Notes & Résultats', icon: Icons.bar_chart_rounded),
  NavItem(id: 'presence', label: 'Présence', icon: Icons.access_time_rounded),
  NavItem(id: 'admin', label: 'Gestion Administrative', icon: Icons.folder_rounded),
  NavItem(id: 'communication', label: 'Communications', icon: Icons.forum_rounded),
  NavItem(id: 'documents', label: 'Mes Documents', icon: Icons.description_rounded),
];

class StudentShell extends StatelessWidget {
  const StudentShell({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      appTitle: 'SIG-Lycée · Élève',
      items: _items,
      screenBuilder: (context, id) {
        switch (id) {
          case 'home':
            return const StudentDashboardScreen();
          case 'profil':
            return const StudentProfilScreen();
          case 'academique':
            return const StudentAcademiqueScreen();
          case 'edt':
            return const StudentEdtScreen();
          case 'devoirs':
            return const StudentDevoirsScreen();
          case 'notes':
            return const StudentNotesScreen();
          case 'presence':
            return const StudentPresenceScreen();
          case 'admin':
            return const StudentAdministratifScreen();
          case 'communication':
            return const CommunicationScreen();
          case 'documents':
            return const StudentDocumentsScreen();
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
