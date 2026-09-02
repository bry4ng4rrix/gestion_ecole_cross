import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/file_download.dart';
import '../../../core/widgets/common.dart';
import '../parent_providers.dart';

/// Bottom sheet listant les bulletins d'UN enfant — raccourci depuis la carte de l'enfant
/// dans "Mes Enfants" pour éviter d'avoir à basculer sur l'onglet "Bulletins" séparé.
Future<void> ouvrirBulletinsEnfant(BuildContext context, Map<String, dynamic> enfant) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => _BulletinsEnfantContent(enfant: enfant, scrollController: scrollController),
    ),
  );
}

class _BulletinsEnfantContent extends ConsumerWidget {
  final Map<String, dynamic> enfant;
  final ScrollController scrollController;

  const _BulletinsEnfantContent({required this.enfant, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bulletinsAsync = ref.watch(parentBulletinsProvider);

    return SafeArea(
      child: bulletinsAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
        error: (e, _) => ErrorView(message: 'Bulletins indisponibles', onRetry: () => ref.invalidate(parentBulletinsProvider)),
        data: (bulletins) {
          final siens = bulletins.where((b) => b['etudiant'] == enfant['id']).toList();
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bulletins — ${enfant['prenom']} ${enfant['nom']}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 12),
              if (siens.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 8), child: Text("Aucun bulletin généré pour l'instant."))
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
                          tooltip: 'Télécharger',
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
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}
