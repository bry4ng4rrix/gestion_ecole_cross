import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/file_download.dart';
import '../../../core/widgets/common.dart';
import '../parent_providers.dart';

/// Miroir de `BulletinsTab` (frontend/src/pages/ParentDashboard.jsx).
class ParentBulletinsScreen extends ConsumerWidget {
  const ParentBulletinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enfantsAsync = ref.watch(mesEnfantsProvider);
    final bulletinsAsync = ref.watch(parentBulletinsProvider);

    return enfantsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Enfants indisponibles', onRetry: () => ref.invalidate(mesEnfantsProvider)),
      data: (enfants) => bulletinsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'Bulletins indisponibles', onRetry: () => ref.invalidate(parentBulletinsProvider)),
        data: (bulletins) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(parentBulletinsProvider),
          child: ListView(
            children: [
              const SectionHeader(title: 'Bulletins'),
              ...enfants.map((enfant) {
                final siens = bulletins.where((b) => b['etudiant'] == enfant['id']).toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${enfant['prenom']} ${enfant['nom']}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (siens.isEmpty)
                        const Padding(padding: EdgeInsets.only(bottom: 8), child: Text("Aucun bulletin généré pour l'instant."))
                      else
                        ...siens.map((b) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(b['trimestre_numero'] != null ? 'Trimestre ${b['trimestre_numero']}' : 'Annuel', style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  'Moyenne : ${b['moyenne_generale'] ?? '—'}/20 · Rang : ${b['rang'] ?? '—'}/${b['effectif_classe'] ?? '—'}\n'
                                  '${b['est_valide'] == true ? 'Validé' : 'En attente de validation'}',
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  icon: const Icon(Icons.download_outlined),
                                  tooltip: 'Voir',
                                  onPressed: () async {
                                    try {
                                      await downloadAndOpen('/bulletins/${b['id']}/pdf/', 'bulletin_${b['id']}.pdf');
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir le bulletin.')));
                                      }
                                    }
                                  },
                                ),
                              ),
                            )),
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
