import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../admin_providers.dart';
import '../widgets/distribution_classe_radar_chart.dart';
import '../widgets/taux_par_trimestre_chart.dart';

/// Miroir de `DashboardOverview` (frontend/src/pages/AdminDashboard.jsx) — cartes de
/// synthèse + graphiques Area (taux par trimestre) et Radar (distribution par classe).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etudiantsAsync = ref.watch(adminEtudiantsProvider);
    final personnelAsync = ref.watch(adminPersonnelProvider);
    final classesAsync = ref.watch(adminClassesProvider);
    final anneesAsync = ref.watch(adminAnneesScolairesProvider);

    return anneesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => const ErrorView(message: 'Années scolaires indisponibles'),
      data: (annees) {
        final actives = annees.where((a) => a['est_active'] == true).toList();
        final anneeActiveId = actives.isNotEmpty ? actives.first['id'] as int : (annees.isNotEmpty ? annees.first['id'] as int : null);
        final statsAsync = ref.watch(statistiquesProvider(anneeActiveId));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminEtudiantsProvider);
            ref.invalidate(adminPersonnelProvider);
            ref.invalidate(adminClassesProvider);
            ref.invalidate(statistiquesProvider(anneeActiveId));
          },
          child: ListView(
            children: [
              const SectionHeader(title: 'Tableau de bord', subtitle: 'Bienvenue sur la plateforme SIG-Lycée'),
              Row(
                children: [
                  Expanded(
                    child: etudiantsAsync.when(
                      data: (e) => StatCard(title: 'Élèves inscrits', value: '${e.length}', icon: Icons.groups_rounded),
                      loading: () => const StatCard(title: 'Élèves inscrits', value: '…', icon: Icons.groups_rounded),
                      error: (e, _) => const StatCard(title: 'Élèves inscrits', value: '—', icon: Icons.groups_rounded),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: classesAsync.when(
                      data: (c) => StatCard(
                        title: 'Classes actives',
                        value: '${c.length}',
                        subtitle: '${c.fold<int>(0, (a, cl) => a + ((cl['effectif'] as num?)?.toInt() ?? 0))} élève(s) au total',
                        icon: Icons.class_rounded,
                      ),
                      loading: () => const StatCard(title: 'Classes actives', value: '…', icon: Icons.class_rounded),
                      error: (e, _) => const StatCard(title: 'Classes actives', value: '—', icon: Icons.class_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: personnelAsync.when(
                      data: (p) => StatCard(
                        title: 'Enseignants',
                        value: '${p.where((x) => x['role'] == 'ENSEIGNANT').length}',
                        subtitle: '${p.length} membre(s) du personnel',
                        icon: Icons.school_rounded,
                      ),
                      loading: () => const StatCard(title: 'Enseignants', value: '…', icon: Icons.school_rounded),
                      error: (e, _) => const StatCard(title: 'Enseignants', value: '—', icon: Icons.school_rounded),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: personnelAsync.when(
                      data: (p) => StatCard(
                        title: 'Bureau administratif',
                        value: '${p.where((x) => x['role'] == 'SECRETARIAT').length}',
                        subtitle: '${p.where((x) => x['role'] == 'ADMIN' || x['role'] == 'RESPONSABLE').length} administrateur(s)',
                        icon: Icons.badge_rounded,
                      ),
                      loading: () => const StatCard(title: 'Bureau administratif', value: '…', icon: Icons.badge_rounded),
                      error: (e, _) => const StatCard(title: 'Bureau administratif', value: '—', icon: Icons.badge_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: statsAsync.when(
                      data: (s) => StatCard(
                        title: 'Taux de réussite',
                        value: s?['taux_reussite'] != null ? '${s!['taux_reussite']}%' : '—',
                        subtitle: s?['nb_evalues'] != null ? '${s!['nb_evalues']} élève(s) évalué(s)' : null,
                        icon: Icons.speed_rounded,
                        accentColor: Colors.green,
                      ),
                      loading: () => const StatCard(title: 'Taux de réussite', value: '…', icon: Icons.speed_rounded),
                      error: (e, _) => const StatCard(title: 'Taux de réussite', value: '—', icon: Icons.speed_rounded),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: statsAsync.when(
                      data: (s) => StatCard(
                        title: 'Taux de présence',
                        value: s?['taux_presence'] != null ? '${s!['taux_presence']}%' : '—',
                        subtitle: s?['total_seances'] != null ? '${s!['total_seances']} séance(s)' : null,
                        icon: Icons.event_available_rounded,
                        accentColor: Colors.blue,
                      ),
                      loading: () => const StatCard(title: 'Taux de présence', value: '…', icon: Icons.event_available_rounded),
                      error: (e, _) => const StatCard(title: 'Taux de présence', value: '—', icon: Icons.event_available_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tauxCard = Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Taux par trimestre', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text('Réussite, absence et retard', style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 12),
                          TauxParTrimestreChart(anneeScolaireId: anneeActiveId),
                        ],
                      ),
                    ),
                  );
                  final distributionCard = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Distribution par classe', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      classesAsync.when(
                        loading: () => const LoadingView(),
                        error: (e, _) => const ErrorView(message: 'Classes indisponibles'),
                        data: (classes) {
                          if (classes.isEmpty) return const EmptyView(message: "Aucune classe pour l'année scolaire active.");
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: DistributionClasseRadarChart(classes: classes),
                            ),
                          );
                        },
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 700) {
                    return Column(
                      children: [tauxCard, const SizedBox(height: 16), distributionCard],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: tauxCard),
                      const SizedBox(width: 16),
                      Expanded(child: distributionCard),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
