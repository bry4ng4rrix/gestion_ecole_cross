import 'package:flutter/material.dart';

import '../../../core/widgets/common.dart';

/// Miroir de `StudentHistory` (frontend/src/pages/TeacherDashboard.jsx) — **le composant web
/// source est lui-même une maquette statique** (noms/années/moyennes en dur, pas d'appel API) ;
/// reproduit ici à l'identique pour la parité, pas parce que les données seraient réelles.
class TeacherHistoriqueScreen extends StatefulWidget {
  const TeacherHistoriqueScreen({super.key});

  @override
  State<TeacherHistoriqueScreen> createState() => _TeacherHistoriqueScreenState();
}

class _TeacherHistoriqueScreenState extends State<TeacherHistoriqueScreen> {
  String? _eleveSelectionne;

  static const _eleves = {
    '1': 'Jean Dupont (2nde C)',
    '2': 'Marie Jean (2nde C)',
    '3': 'Paul Rakoto (1ère S)',
  };
  static const _historique = [
    {'annee': '2023-2024', 'classe': '3ème', 'moyenne': '11.5', 'statut': 'Admis'},
    {'annee': '2024-2025', 'classe': '2nde C', 'moyenne': '12.8', 'statut': 'En cours'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionHeader(title: 'Historique Académique', subtitle: "Consultation de l'historique de vos étudiants"),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sélectionner un élève', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _eleveSelectionne,
                  decoration: const InputDecoration(hintText: '-- Sélectionner un élève --'),
                  items: _eleves.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setState(() => _eleveSelectionne = v),
                ),
              ],
            ),
          ),
        ),
        if (_eleveSelectionne != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Profil d'élève", style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _champ(context, 'Nom', 'Jean Dupont'),
                  _champ(context, 'Classe actuelle', '2nde C'),
                  _champ(context, "Date d'inscription", '01/09/2024'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Historique académique', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ..._historique.map((r) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('${r['annee']} — Classe : ${r['classe']}'),
                          subtitle: Text('Moyenne générale : ${r['moyenne']}/20'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (r['statut'] == 'Admis' ? Colors.green : Colors.blue).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(r['statut']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: r['statut'] == 'Admis' ? Colors.green.shade700 : Colors.blue.shade700)),
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _champ(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
