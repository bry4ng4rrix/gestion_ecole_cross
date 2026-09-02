import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../parent_providers.dart';

/// Miroir de `ChildrenTab` (frontend/src/pages/ParentDashboard.jsx).
class ParentEnfantsScreen extends ConsumerWidget {
  const ParentEnfantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enfantsAsync = ref.watch(mesEnfantsProvider);
    final trimestresAsync = ref.watch(parentTrimestresProvider);

    return enfantsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Enfants indisponibles', onRetry: () => ref.invalidate(mesEnfantsProvider)),
      data: (enfants) => trimestresAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'Trimestres indisponibles'),
        data: (trimestres) {
          final actif = trimestres.where((t) => t['est_actif'] == true).toList();
          final trimestreActifId = actif.isNotEmpty ? actif.first['id'] as int : (trimestres.isNotEmpty ? trimestres.first['id'] as int : null);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mesEnfantsProvider),
            child: ListView(
              children: [
                const SectionHeader(title: 'Mes Enfants'),
                if (enfants.isEmpty) const EmptyView(message: 'Aucun enfant rattaché à votre compte.'),
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
                          Row(
                            children: [
                              Expanded(
                                child: Text('${enfant['prenom']} ${enfant['nom']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
                                child: Text(enfant['classe_actuelle']?.toString() ?? '—', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                              ),
                            ],
                          ),
                          Text('Matricule : ${enfant['matricule'] ?? '—'}', style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: StatCard(
                                  title: 'Moyenne',
                                  value: moyenneAsync.when(data: (m) => m != null ? '${m.toStringAsFixed(2)}/20' : '—', loading: () => '…', error: (e, _) => '—'),
                                  icon: Icons.bar_chart_rounded,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: StatCard(title: 'Statut', value: enfant['statut']?.toString() ?? '—', icon: Icons.verified_outlined)),
                            ],
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
      ),
    );
  }
}
