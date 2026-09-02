import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../parent_providers.dart';

const _statutLabels = {'PAYE': 'Payé', 'PARTIEL': 'Partiel', 'IMPAYE': 'Impayé', 'NON_CONFIGURE': 'Non configuré'};
const _statutColors = {'PAYE': Colors.green, 'PARTIEL': Colors.orange, 'IMPAYE': Colors.red, 'NON_CONFIGURE': Colors.grey};

final _anneesForPaiementsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/annees-scolaires').list());

final _dossierFinancierEnfantProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, ({int etudiantId, int anneeScolaireId})>((ref, args) async {
  final response = await ApiClient.instance.dio.get('/paiements/dossier/', queryParameters: {'etudiant': args.etudiantId, 'annee_scolaire': args.anneeScolaireId});
  return response.data as Map<String, dynamic>?;
});

/// Miroir de `PaymentsTab` / `ChildDossierCard` (frontend/src/pages/ParentDashboard.jsx).
class ParentPaiementsScreen extends ConsumerWidget {
  const ParentPaiementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enfantsAsync = ref.watch(mesEnfantsProvider);
    final anneesAsync = ref.watch(_anneesForPaiementsProvider);

    return enfantsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Enfants indisponibles', onRetry: () => ref.invalidate(mesEnfantsProvider)),
      data: (enfants) => anneesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'Années scolaires indisponibles'),
        data: (annees) {
          final actives = annees.where((a) => a['est_active'] == true).toList();
          final anneeId = actives.isNotEmpty ? actives.first['id'] as int : (annees.isNotEmpty ? annees.first['id'] as int : null);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mesEnfantsProvider),
            child: ListView(
              children: [
                const SectionHeader(title: 'Paiements'),
                if (enfants.isEmpty) const EmptyView(message: 'Aucun enfant rattaché à votre compte.'),
                ...enfants.map((enfant) {
                  final dossierAsync = anneeId != null
                      ? ref.watch(_dossierFinancierEnfantProvider((etudiantId: enfant['id'] as int, anneeScolaireId: anneeId)))
                      : const AsyncValue<Map<String, dynamic>?>.data(null);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${enfant['prenom']} ${enfant['nom']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 12),
                          dossierAsync.when(
                            data: (dossier) {
                              if (dossier == null) return const Text('Chargement...');
                              final statut = dossier['statut'];
                              return Row(
                                children: [
                                  Expanded(
                                    child: _tuile(context, 'Total dû', '${_fmt(dossier['total_du'])} Ar', Colors.blue),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _tuile(context, 'Reste à payer', '${_fmt(dossier['reste_du'])} Ar', Colors.orange),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _tuile(context, 'Statut', _statutLabels[statut] ?? '$statut', _statutColors[statut] ?? Colors.grey),
                                  ),
                                ],
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => const Text('Dossier financier indisponible', style: TextStyle(fontSize: 12)),
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

  Widget _tuile(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: color)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  String _fmt(dynamic value) {
    if (value == null) return '0';
    final n = double.tryParse('$value') ?? 0;
    final s = n.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}
