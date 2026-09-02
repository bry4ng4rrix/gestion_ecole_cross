import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../student_providers.dart';

/// Miroir de `GradesResults` (frontend/src/pages/StudentDashboard.jsx) : notes du trimestre
/// sélectionné + moyenne générale annuelle ((T1+T2+T3)/3, arrondie trimestre par trimestre
/// comme `services/moyenne.py`) + statut du bulletin.
class StudentNotesScreen extends ConsumerStatefulWidget {
  const StudentNotesScreen({super.key});

  @override
  ConsumerState<StudentNotesScreen> createState() => _StudentNotesScreenState();
}

class _StudentNotesScreenState extends ConsumerState<StudentNotesScreen> {
  int? _selectedTrimestreId;

  @override
  Widget build(BuildContext context) {
    final trimestresAsync = ref.watch(trimestresProvider);
    final notesAsync = ref.watch(notesProvider);
    final matieresAsync = ref.watch(matieresProvider);
    final bulletinsAsync = ref.watch(bulletinsProvider);

    return trimestresAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Trimestres indisponibles', onRetry: () => ref.invalidate(trimestresProvider)),
      data: (trimestres) {
        if (trimestres.isEmpty) return const EmptyView(message: 'Aucun trimestre configuré.');
        final actif = trimestres.firstWhere((t) => t['est_actif'] == true, orElse: () => trimestres.first);
        final selectedId = _selectedTrimestreId ?? actif['id'] as int;

        return notesAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: 'Notes indisponibles', onRetry: () => ref.invalidate(notesProvider)),
          data: (notes) => matieresAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => const ErrorView(message: 'Matières indisponibles'),
            data: (matieres) {
              final coeffOf = (int matiereId) {
                final m = matieres.firstWhere((m) => m['id'] == matiereId, orElse: () => {});
                return (m['coefficient'] as num?)?.toDouble() ?? 1.0;
              };
              final nomOf = (int matiereId) {
                final m = matieres.firstWhere((m) => m['id'] == matiereId, orElse: () => {});
                return m['intitule']?.toString() ?? 'Matière $matiereId';
              };

              // Moyenne pondérée par trimestre (mêmes règles que services/moyenne.py).
              double? moyennePondereeTrimestre(int trimestreId) {
                final parMatiere = <int, List<double>>{};
                for (final n in notes) {
                  if (n['trimestre'] != trimestreId) continue;
                  final mId = n['matiere'] as int;
                  parMatiere.putIfAbsent(mId, () => []).add(double.tryParse('${n['valeur']}') ?? 0);
                }
                if (parMatiere.isEmpty) return null;
                double totalPondere = 0, totalCoeff = 0;
                for (final entry in parMatiere.entries) {
                  final coeff = coeffOf(entry.key);
                  final moyMatiere = entry.value.reduce((a, b) => a + b) / entry.value.length;
                  totalPondere += moyMatiere * coeff;
                  totalCoeff += coeff;
                }
                return totalCoeff > 0 ? double.parse((totalPondere / totalCoeff).toStringAsFixed(2)) : null;
              }

              final moyennesTrimestres = trimestres.map((t) => moyennePondereeTrimestre(t['id'] as int)).whereType<double>().toList();
              final moyenneAnnuelle = moyennesTrimestres.isEmpty ? null : moyennesTrimestres.reduce((a, b) => a + b) / moyennesTrimestres.length;
              final moyenneSelectionnee = moyennePondereeTrimestre(selectedId);

              final notesParMatiere = <int, List<Map<String, dynamic>>>{};
              for (final n in notes) {
                if (n['trimestre'] != selectedId) continue;
                notesParMatiere.putIfAbsent(n['matiere'] as int, () => []).add(n);
              }
              String? meilleureMatiere;
              double meilleureMoyenne = -1;
              notesParMatiere.forEach((matiereId, list) {
                final moy = list.map((n) => double.tryParse('${n['valeur']}') ?? 0).reduce((a, b) => a + b) / list.length;
                if (moy > meilleureMoyenne) {
                  meilleureMoyenne = moy;
                  meilleureMatiere = nomOf(matiereId);
                }
              });

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(trimestresProvider);
                  ref.invalidate(notesProvider);
                  ref.invalidate(bulletinsProvider);
                },
                child: ListView(
                  children: [
                    const SectionHeader(title: 'Notes & Résultats'),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: trimestres.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final t = trimestres[i];
                          final isSelected = t['id'] == selectedId;
                          return ChoiceChip(
                            label: Text('Trimestre ${t['numero']}'),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedTrimestreId = t['id'] as int),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (notesParMatiere.isEmpty)
                      const EmptyView(message: 'Aucune note pour ce trimestre.', icon: Icons.grade_outlined)
                    else
                      ...notesParMatiere.entries.map((e) {
                        final valeurs = e.value.map((n) => double.tryParse('${n['valeur']}') ?? 0).toList();
                        final moyenne = valeurs.reduce((a, b) => a + b) / valeurs.length;
                        final detail = e.value.map((n) => '${n['type_evaluation']}: ${n['valeur']}').join(', ');
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(nomOf(e.key), style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(detail, style: const TextStyle(fontSize: 12)),
                            trailing: Text('${moyenne.toStringAsFixed(2)}/20', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Moyenne du trimestre',
                            value: moyenneSelectionnee != null ? '${moyenneSelectionnee.toStringAsFixed(2)}/20' : '—',
                            icon: Icons.functions_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'Meilleure matière',
                            value: meilleureMatiere ?? '—',
                            icon: Icons.stars_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StatCard(
                      title: 'Moyenne générale annuelle',
                      value: moyenneAnnuelle != null ? '${moyenneAnnuelle.toStringAsFixed(2)}/20' : '—',
                      subtitle: moyennesTrimestres.isNotEmpty ? 'Moyenne des ${moyennesTrimestres.length} trimestre(s) noté(s)' : 'Aucune note enregistrée',
                      icon: Icons.emoji_events_rounded,
                      accentColor: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    bulletinsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                      data: (bulletins) {
                        final bulletin = bulletins.where((b) => b['trimestre'] == selectedId).toList();
                        final b = bulletin.isNotEmpty ? bulletin.first : null;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.picture_as_pdf_outlined),
                            title: const Text('Bulletin', style: TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              b != null
                                  ? "${b['est_valide'] == true ? 'Validé' : 'En attente de validation'} — Rang ${b['rang'] ?? '—'}/${b['effectif_classe'] ?? '—'}"
                                  : "Pas encore généré par l'établissement pour ce trimestre.",
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
