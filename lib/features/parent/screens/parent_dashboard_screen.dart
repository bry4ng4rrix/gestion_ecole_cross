import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../parent_providers.dart';

/// Miroir de `HomeTab` (frontend/src/pages/ParentDashboard.jsx).
class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enfantsAsync = ref.watch(mesEnfantsProvider);
    final trimestresAsync = ref.watch(parentTrimestresProvider);

    return enfantsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Impossible de charger vos enfants.', onRetry: () => ref.invalidate(mesEnfantsProvider)),
      data: (enfants) {
        if (enfants.isEmpty) return const EmptyView(message: 'Aucun enfant rattaché à votre compte.', icon: Icons.family_restroom_outlined);
        return trimestresAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => const ErrorView(message: 'Trimestres indisponibles'),
          data: (trimestres) {
            final actif = trimestres.where((t) => t['est_actif'] == true).toList();
            final trimestreActifId = actif.isNotEmpty ? actif.first['id'] as int : (trimestres.isNotEmpty ? trimestres.first['id'] as int : null);

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(mesEnfantsProvider);
                ref.invalidate(parentTrimestresProvider);
              },
              child: ListView(
                children: [
                  const SectionHeader(title: 'Accueil', subtitle: 'Vue d\'ensemble de vos enfants'),
                  ...enfants.map((enfant) {
                    final moyenneAsync = trimestreActifId != null
                        ? ref.watch(moyenneEnfantProvider((etudiantId: enfant['id'] as int, trimestreId: trimestreActifId)))
                        : const AsyncValue<double?>.data(null);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${enfant['prenom']} ${enfant['nom']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 10),
                            _infoRow(context, 'Classe', enfant['classe_actuelle']?.toString() ?? '—'),
                            _infoRow(context, 'Matricule', enfant['matricule']?.toString() ?? '—'),
                            _infoRow(
                              context,
                              'Moyenne générale',
                              moyenneAsync.when(
                                data: (m) => m != null ? '${m.toStringAsFixed(2)}/20' : '—',
                                loading: () => '…',
                                error: (e, _) => '—',
                              ),
                              valueColor: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label : ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: valueColor)),
        ],
      ),
    );
  }
}
