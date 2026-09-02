import 'package:flutter/material.dart';

import '../../../core/widgets/common.dart';

/// Miroir de `TeacherReports` (frontend/src/pages/TeacherDashboard.jsx) — **maquette statique
/// côté web** (les boutons "Voir"/"PDF" n'ont pas d'action réelle non plus sur le site) ;
/// reproduit à l'identique pour la parité visuelle.
class TeacherRapportsScreen extends StatelessWidget {
  const TeacherRapportsScreen({super.key});

  static const _rapports = [
    {'titre': 'Moyennes par classe', 'description': 'Comparaison des performances académiques'},
    {'titre': "Taux d'assiduité", 'description': 'Suivi des présences et absences'},
    {'titre': 'Progression académique', 'description': "Évolution des notes sur l'année"},
    {'titre': 'Rapport mensuel', 'description': 'Récapitulatif des activités du mois'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionHeader(title: 'Rapports & Statistiques', subtitle: 'Analyses par classe et par matière'),
        ..._rapports.map((r) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['titre']!, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(r['description']!, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Voir'))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 16), label: const Text('PDF')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
