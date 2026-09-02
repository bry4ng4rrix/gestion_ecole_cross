import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';

final _matieresProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/matieres').list());
final _cahierTextesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/cahier-textes').list());

/// Miroir de `AcademicManagement` (frontend/src/pages/StudentDashboard.jsx) : matières de
/// l'établissement + cahier de textes de la classe, en lecture seule.
class StudentAcademiqueScreen extends ConsumerWidget {
  const StudentAcademiqueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matieresAsync = ref.watch(_matieresProvider);
    final entreesAsync = ref.watch(_cahierTextesProvider);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_matieresProvider);
        ref.invalidate(_cahierTextesProvider);
      },
      child: ListView(
        children: [
          const SectionHeader(title: 'Gestion Académique', subtitle: 'Matières et cahier de textes'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Matières de l'établissement", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  matieresAsync.when(
                    loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
                    error: (e, _) => const Text('Matières indisponibles.'),
                    data: (matieres) {
                      if (matieres.isEmpty) return const Text('Aucune matière.');
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: matieres.map((m) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(m['intitule']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Text('Coef. ${m['coefficient'] ?? '—'}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Cahier de textes', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          entreesAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: 'Cahier de textes indisponible', onRetry: () => ref.invalidate(_cahierTextesProvider)),
            data: (entrees) {
              final triees = [...entrees]..sort((a, b) => '${b['date_seance']}'.compareTo('${a['date_seance']}'));
              if (triees.isEmpty) return const EmptyView(message: 'Aucune entrée dans le cahier de textes.', icon: Icons.menu_book_outlined);
              return Column(
                children: triees.map((entree) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(entree['matiere_intitule']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                                Text(entree['date_seance']?.toString() ?? '', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(entree['contenu_seance']?.toString() ?? '', style: TextStyle(color: scheme.onSurfaceVariant)),
                            if ((entree['travail_a_faire'] as String?)?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Travail à faire', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.primary)),
                                    Text(entree['travail_a_faire'].toString()),
                                    if (entree['date_echeance_travail'] != null)
                                      Text('Pour le ${entree['date_echeance_travail']}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ],
                            if ((entree['piece_jointe'] as String?)?.isNotEmpty == true || (entree['lien'] as String?)?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 16,
                                children: [
                                  if ((entree['piece_jointe'] as String?)?.isNotEmpty == true)
                                    _lien(context, 'Pièce jointe', entree['piece_jointe'] as String),
                                  if ((entree['lien'] as String?)?.isNotEmpty == true) _lien(context, 'Lien', entree['lien'] as String),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    )).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _lien(BuildContext context, String label, String url) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline)),
    );
  }
}
