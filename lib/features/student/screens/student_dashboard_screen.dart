import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../student_providers.dart';
import '../widgets/bulletins_card.dart';

/// Miroir de `StudentDashboardOverview` (frontend/src/pages/StudentDashboard.jsx).
class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dossierAsync = ref.watch(monDossierProvider);
    final trimestresAsync = ref.watch(trimestresProvider);
    final notesAsync = ref.watch(notesProvider);
    final matieresAsync = ref.watch(matieresProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(monDossierProvider);
        ref.invalidate(trimestresProvider);
        ref.invalidate(notesProvider);
        ref.invalidate(matieresProvider);
        ref.invalidate(bulletinsProvider);
      },
      child: ListView(
        children: [
          const SectionHeader(title: 'Tableau de bord', subtitle: 'Bienvenue sur votre portail étudiant'),
          dossierAsync.when(
            data: (dossier) => trimestresAsync.when(
              data: (trimestres) {
                final actif = trimestres.where((t) => t['est_actif'] == true).toList();
                final trimestreActif = actif.isNotEmpty ? actif.first : (trimestres.isNotEmpty ? trimestres.first : null);
                return Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Classe',
                        value: (dossier?['classe_actuelle'] as String?) ?? '—',
                        icon: Icons.menu_book_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: trimestreActif != null ? 'Trimestre ${trimestreActif['numero']}' : 'Trimestre',
                        value: trimestreActif != null ? 'T${trimestreActif['numero']}' : '—',
                        icon: Icons.event_note_rounded,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: 'Trimestres indisponibles'),
            ),
            loading: () => const LoadingView(),
            error: (e, _) => const ErrorView(message: 'Impossible de charger votre dossier.'),
          ),
          const SizedBox(height: 20),
          Text('Mes notes récentes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          trimestresAsync.when(
            data: (trimestres) {
              final actif = trimestres.where((t) => t['est_actif'] == true).toList();
              final trimestreActifId = actif.isNotEmpty ? actif.first['id'] : (trimestres.isNotEmpty ? trimestres.first['id'] : null);
              return notesAsync.when(
                data: (notes) => matieresAsync.when(
                  data: (matieres) {
                    final parMatiere = <int, List<double>>{};
                    for (final n in notes) {
                      if (n['trimestre'] != trimestreActifId) continue;
                      final matiereId = n['matiere'] as int;
                      parMatiere.putIfAbsent(matiereId, () => []).add(double.tryParse('${n['valeur']}') ?? 0);
                    }
                    if (parMatiere.isEmpty) {
                      return const EmptyView(message: 'Aucune note pour ce trimestre.', icon: Icons.grade_outlined);
                    }
                    return Column(
                      children: parMatiere.entries.map((e) {
                        final nom = matieres.firstWhere((m) => m['id'] == e.key, orElse: () => {'intitule': 'Matière ${e.key}'})['intitule'];
                        final moyenne = e.value.reduce((a, b) => a + b) / e.value.length;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${e.value.length} note(s)'),
                            trailing: Text(
                              '${moyenne.toStringAsFixed(2)}/20',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const LoadingView(),
                  error: (e, _) => const ErrorView(message: 'Matières indisponibles'),
                ),
                loading: () => const LoadingView(),
                error: (e, _) => const ErrorView(message: 'Notes indisponibles'),
              );
            },
            loading: () => const LoadingView(),
            error: (e, _) => const ErrorView(message: 'Trimestres indisponibles'),
          ),
          const SizedBox(height: 20),
          const BulletinsCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
