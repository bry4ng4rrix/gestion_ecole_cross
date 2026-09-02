import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../student_providers.dart';

const _statutLabels = {'PAYE': 'Payé', 'PARTIEL': 'Partiel', 'IMPAYE': 'Impayé', 'NON_CONFIGURE': 'Non configuré'};

final _anneesScolairesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/annees-scolaires').list());
final _paiementsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/paiements').list());

final _dossierFinancierProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, ({int etudiantId, int anneeScolaireId})>((ref, args) async {
  final response = await ApiClient.instance.dio.get('/paiements/dossier/', queryParameters: {'etudiant': args.etudiantId, 'annee_scolaire': args.anneeScolaireId});
  return response.data as Map<String, dynamic>?;
});

/// Miroir simplifié de `AdministrativeStatus` (frontend/src/pages/StudentDashboard.jsx) : les
/// 3 indicateurs financiers + l'historique des paiements en liste (le calendrier mensuel
/// détaillé de `FraisEcolageCalendar` n'est pas repris ici, voir ROADMAP.md).
class StudentAdministratifScreen extends ConsumerWidget {
  const StudentAdministratifScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dossierAsync = ref.watch(monDossierProvider);
    final anneesAsync = ref.watch(_anneesScolairesProvider);
    final paiementsAsync = ref.watch(_paiementsProvider);

    return dossierAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => const ErrorView(message: 'Dossier indisponible'),
      data: (dossier) => anneesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'Années scolaires indisponibles'),
        data: (annees) {
          final actives = annees.where((a) => a['est_active'] == true).toList();
          final anneeId = actives.isNotEmpty ? actives.first['id'] as int : (annees.isNotEmpty ? annees.first['id'] as int : null);
          final dossierFinancierAsync = (dossier != null && anneeId != null)
              ? ref.watch(_dossierFinancierProvider((etudiantId: dossier['id'] as int, anneeScolaireId: anneeId)))
              : const AsyncValue<Map<String, dynamic>?>.data(null);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_paiementsProvider);
              if (dossier != null && anneeId != null) {
                ref.invalidate(_dossierFinancierProvider((etudiantId: dossier['id'] as int, anneeScolaireId: anneeId)));
              }
            },
            child: ListView(
              children: [
                const SectionHeader(title: 'Gestion Administrative', subtitle: 'Consultation de vos paiements et statut'),
                dossierFinancierAsync.when(
                  data: (df) => Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: StatCard(title: 'Total dû', value: df != null ? '${_fmt(df['total_du'])} Ar' : '—', icon: Icons.account_balance_wallet_outlined)),
                          const SizedBox(width: 10),
                          Expanded(child: StatCard(title: 'Reste à payer', value: df != null ? '${_fmt(df['reste_du'])} Ar' : '—', icon: Icons.pending_actions_outlined)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      StatCard(title: 'Statut', value: df != null ? (_statutLabels[df['statut']] ?? '${df['statut']}') : '—', icon: Icons.info_outline),
                    ],
                  ),
                  loading: () => const LoadingView(),
                  error: (e, _) => const ErrorView(message: 'Dossier financier indisponible'),
                ),
                const SizedBox(height: 20),
                Text('Historique des paiements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                paiementsAsync.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => const ErrorView(message: 'Paiements indisponibles'),
                  data: (paiements) {
                    final triees = [...paiements]..sort((a, b) => '${b['date_paiement'] ?? b['date_echeance']}'.compareTo('${a['date_paiement'] ?? a['date_echeance']}'));
                    if (triees.isEmpty) return const EmptyView(message: 'Aucun paiement enregistré.', icon: Icons.receipt_long_outlined);
                    return Column(
                      children: triees.map((p) {
                        final date = DateTime.tryParse(p['date_paiement']?.toString() ?? p['date_echeance']?.toString() ?? '');
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('${_fmt(p['montant'])} Ar', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${p['mois_couvert'] != null ? 'Mois ${p['mois_couvert']} · ' : ''}${date != null ? DateFormat('dd/MM/yyyy').format(date) : ''}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: _statutColor(p['statut']).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                              child: Text(_statutLabels[p['statut']] ?? '${p['statut']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statutColor(p['statut']))),
                            ),
                          ),
                        );
                      }).toList(),
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
  }

  String _fmt(dynamic value) {
    if (value == null) return '0';
    final n = double.tryParse('$value') ?? 0;
    return NumberFormat('#,##0', 'fr_FR').format(n).replaceAll(',', ' ');
  }

  Color _statutColor(dynamic statut) {
    switch (statut) {
      case 'PAYE':
        return Colors.green;
      case 'PARTIEL':
        return Colors.orange;
      case 'IMPAYE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
