import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../admin_providers.dart';

final _trimestresRapportsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/trimestres').list());

/// Miroir de `StatistiquesPanel` (frontend/src/components/statistiques/StatistiquesPanel.jsx) —
/// les graphiques Area/Radar restent sur le tableau de bord (AdminDashboardScreen) ; ici la
/// synthèse par classe, filtrable par trimestre.
class AdminRapportsScreen extends ConsumerStatefulWidget {
  const AdminRapportsScreen({super.key});

  @override
  ConsumerState<AdminRapportsScreen> createState() => _AdminRapportsScreenState();
}

class _AdminRapportsScreenState extends ConsumerState<AdminRapportsScreen> {
  int? _trimestreId;

  @override
  Widget build(BuildContext context) {
    final anneesAsync = ref.watch(adminAnneesScolairesProvider);
    final trimestresAsync = ref.watch(_trimestresRapportsProvider);

    return anneesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => const ErrorView(message: 'Années scolaires indisponibles'),
      data: (annees) {
        final actives = annees.where((a) => a['est_active'] == true).toList();
        final anneeId = actives.isNotEmpty ? actives.first['id'] as int : (annees.isNotEmpty ? annees.first['id'] as int : null);
        final statsAsync = ref.watch(statistiquesFiltreesProvider((anneeScolaireId: anneeId, trimestreId: _trimestreId)));

        return trimestresAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => const ErrorView(message: 'Trimestres indisponibles'),
          data: (trimestres) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(statistiquesFiltreesProvider((anneeScolaireId: anneeId, trimestreId: _trimestreId)));
              },
              child: ListView(
                children: [
                  const SectionHeader(title: 'Rapports & Statistiques', subtitle: "Analyses de l'établissement"),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(label: const Text('Année complète'), selected: _trimestreId == null, onSelected: (_) => setState(() => _trimestreId = null)),
                        ),
                        ...trimestres.map((t) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('Trimestre ${t['numero']}'),
                                selected: _trimestreId == t['id'],
                                onSelected: (_) => setState(() => _trimestreId = t['id'] as int),
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  statsAsync.when(
                    data: (s) => Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Taux de réussite',
                            value: s?['taux_reussite'] != null ? '${s!['taux_reussite']}%' : '—',
                            subtitle: s?['nb_evalues'] != null ? 'Sur ${s!['nb_evalues']} élève(s)' : null,
                            icon: Icons.bar_chart_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            title: 'Taux de présence',
                            value: s?['taux_presence'] != null ? '${s!['taux_presence']}%' : '—',
                            subtitle: s?['total_seances'] != null ? 'Sur ${s!['total_seances']} séance(s)' : null,
                            icon: Icons.access_time_filled_rounded,
                          ),
                        ),
                      ],
                    ),
                    loading: () => const LoadingView(),
                    error: (e, _) => const ErrorView(message: 'Statistiques indisponibles'),
                  ),
                  const SizedBox(height: 20),
                  Text('Effectifs et moyennes par classe', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  statsAsync.when(
                    data: (s) {
                      final effectifs = (s?['effectifs_par_classe'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                      final moyennes = (s?['moyennes_par_classe'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                      if (effectifs.isEmpty) return const EmptyView(message: 'Aucune classe.');
                      return Column(
                        children: effectifs.map((eff) {
                          final moy = moyennes.firstWhere((m) => m['classe_id'] == eff['classe_id'], orElse: () => {});
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(eff['classe_nom']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${eff['effectif']} élève(s)'),
                              trailing: Text(moy['moyenne'] != null ? '${moy['moyenne']}/20' : '—', style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const LoadingView(),
                    error: (e, _) => const ErrorView(message: 'Statistiques indisponibles'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
