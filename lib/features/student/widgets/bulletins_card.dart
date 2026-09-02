import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_message.dart';
import '../../../core/api/file_download.dart';
import '../student_providers.dart';

/// Carte d'export des bulletins — un bouton de téléchargement par trimestre plus un pour le
/// bulletin général (année complète, moyenne des 3 trimestres) — miroir étendu de `BulletinCard`
/// (frontend/src/pages/StudentDashboard.jsx), qui côté web n'affiche que le bulletin du
/// trimestre courant. Le bulletin annuel correspond à un `Bulletin` avec `trimestre = null`
/// (voir `services.bulletin.generer_bulletin` côté backend, qui gère déjà ce cas).
class BulletinsCard extends ConsumerStatefulWidget {
  const BulletinsCard({super.key});

  @override
  ConsumerState<BulletinsCard> createState() => _BulletinsCardState();
}

class _BulletinsCardState extends ConsumerState<BulletinsCard> {
  int? _telechargementEnCours;

  Future<void> _telecharger(Map<String, dynamic> bulletin, String suffixe) async {
    final id = bulletin['id'] as int;
    setState(() => _telechargementEnCours = id);
    try {
      await downloadAndOpen('/bulletins/$id/pdf/', 'bulletin_$suffixe.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e, 'Erreur lors du téléchargement du bulletin.'))));
      }
    } finally {
      if (mounted) setState(() => _telechargementEnCours = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimestresAsync = ref.watch(trimestresProvider);
    final bulletinsAsync = ref.watch(bulletinsProvider);

    return trimestresAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (trimestres) => bulletinsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => const SizedBox.shrink(),
        data: (bulletins) {
          final tries = [...trimestres]..sort((a, b) => (a['numero'] as num? ?? 0).compareTo(b['numero'] as num? ?? 0));
          final bulletinsAnnuels = bulletins.where((b) => b['trimestre'] == null).toList();

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bulletins', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Téléchargez votre bulletin par trimestre ou le bulletin général de l\'année.',
                    style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  ...tries.map((t) {
                    final bulletinsDuTrimestre = bulletins.where((b) => b['trimestre'] == t['id']).toList();
                    return _ligneBulletin(
                      context,
                      titre: 'Trimestre ${t['numero']}',
                      bulletin: bulletinsDuTrimestre.isNotEmpty ? bulletinsDuTrimestre.first : null,
                      suffixe: 'T${t['numero']}',
                    );
                  }),
                  const Divider(height: 22),
                  _ligneBulletin(
                    context,
                    titre: "Bulletin général (année, 3 trimestres)",
                    bulletin: bulletinsAnnuels.isNotEmpty ? bulletinsAnnuels.first : null,
                    suffixe: 'annuel',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ligneBulletin(BuildContext context, {required String titre, required Map<String, dynamic>? bulletin, required String suffixe}) {
    final scheme = Theme.of(context).colorScheme;
    final enCours = bulletin != null && _telechargementEnCours == bulletin['id'];
    final sousTitre = bulletin == null
        ? "Pas encore généré par l'établissement."
        : '${bulletin['est_valide'] == true ? 'Validé' : 'En attente de validation'} — Rang ${bulletin['rang'] ?? '—'}/${bulletin['effectif_classe'] ?? '—'}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(sousTitre, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (bulletin != null)
            OutlinedButton.icon(
              onPressed: enCours ? null : () => _telecharger(bulletin, suffixe),
              icon: enCours
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded, size: 16),
              label: const Text('Télécharger'),
            ),
        ],
      ),
    );
  }
}
