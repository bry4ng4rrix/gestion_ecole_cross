import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';

final _cahierTextesParentProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/cahier-textes').list());

/// Miroir de `CahierTextePanel` en lecture seule (frontend/src/components/pedagogie/CahierTextePanel.jsx)
/// — un parent ne peut pas ajouter d'entrée, seulement consulter celles des classes de ses enfants.
class ParentCahierTexteScreen extends ConsumerWidget {
  const ParentCahierTexteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entreesAsync = ref.watch(_cahierTextesParentProvider);

    return entreesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Cahier de textes indisponible', onRetry: () => ref.invalidate(_cahierTextesParentProvider)),
      data: (entrees) {
        final triees = [...entrees]..sort((a, b) => '${b['date_seance']}'.compareTo('${a['date_seance']}'));
        if (triees.isEmpty) return const EmptyView(message: 'Aucune entrée dans le cahier de textes.', icon: Icons.menu_book_outlined);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_cahierTextesParentProvider),
          child: ListView(
            children: [
              const SectionHeader(title: 'Cahier de textes'),
              ...triees.map((entree) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('${entree['matiere_intitule'] ?? ''} — ${entree['classe_nom'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                              Text(entree['date_seance']?.toString() ?? '', style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(entree['contenu_seance']?.toString() ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          if ((entree['travail_a_faire'] as String?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Travail à faire', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                                  Text(entree['travail_a_faire'].toString()),
                                  if (entree['date_echeance_travail'] != null)
                                    Text('Pour le ${entree['date_echeance_travail']}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _lien(BuildContext context, String label, String url) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline)),
    );
  }
}
