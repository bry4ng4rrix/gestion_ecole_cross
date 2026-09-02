import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../parent_providers.dart';

const _statutLabels = {'P': 'Présent', 'A': 'Absent', 'R': 'En retard', 'E': 'Absence justifiée'};

/// Miroir de `AbsencesTab` (frontend/src/pages/ParentDashboard.jsx).
class ParentAbsencesScreen extends ConsumerWidget {
  const ParentAbsencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enfantsAsync = ref.watch(mesEnfantsProvider);
    final presencesAsync = ref.watch(parentPresencesProvider);

    return enfantsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Enfants indisponibles', onRetry: () => ref.invalidate(mesEnfantsProvider)),
      data: (enfants) => presencesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'Présences indisponibles', onRetry: () => ref.invalidate(parentPresencesProvider)),
        data: (presences) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(parentPresencesProvider),
          child: ListView(
            children: [
              const SectionHeader(title: 'Absences'),
              ...enfants.map((enfant) {
                final siennes = presences.where((p) => p['etudiant'] == enfant['id'] && p['statut'] != 'P').toList()
                  ..sort((a, b) => (b['date_cours'] as String? ?? '').compareTo(a['date_cours'] as String? ?? ''));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${enfant['prenom']} ${enfant['nom']}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (siennes.isEmpty)
                        const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Aucune absence ou retard enregistré.'))
                      else
                        ...siennes.map((p) {
                          final estJustifiee = p['statut'] == 'E';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              title: Text('${p['date_cours']} — ${p['matiere_intitule'] ?? ''}', style: const TextStyle(fontSize: 13)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (estJustifiee ? PresenceColors.present : PresenceColors.retard).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _statutLabels[p['statut']] ?? '${p['statut']}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: estJustifiee ? PresenceColors.present : PresenceColors.retard),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
