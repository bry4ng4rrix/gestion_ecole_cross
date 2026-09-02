import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';

const _roleLabels = {'ETUDIANT': 'Étudiant', 'PARENT': 'Parent / Tuteur'};

final _demandesInscriptionProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/demandes-inscription').list());

/// Miroir simplifié de `DemandesInscriptionPanel` (frontend/src/components/inscriptions/DemandesInscriptionPanel.jsx) :
/// liste + valider/rejeter. La gestion détaillée des pièces jointes et du suivi de paiement
/// des frais d'inscription reste à porter (voir ROADMAP.md).
class AdminInscriptionsScreen extends ConsumerStatefulWidget {
  const AdminInscriptionsScreen({super.key});

  @override
  ConsumerState<AdminInscriptionsScreen> createState() => _AdminInscriptionsScreenState();
}

class _AdminInscriptionsScreenState extends ConsumerState<AdminInscriptionsScreen> {
  int? _busyId;

  Future<void> _valider(int id) async {
    setState(() => _busyId = id);
    try {
      await ApiClient.instance.dio.post('/demandes-inscription/$id/valider/');
      ref.invalidate(_demandesInscriptionProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte activé.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la validation.')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _rejeter(int id) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter la demande ?'),
        content: const Text('Cette action supprime définitivement le compte en attente.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Rejeter')),
        ],
      ),
    );
    if (confirme != true) return;
    setState(() => _busyId = id);
    try {
      await ApiClient.instance.dio.post('/demandes-inscription/$id/rejeter/');
      ref.invalidate(_demandesInscriptionProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande rejetée.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors du rejet.')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demandesAsync = ref.watch(_demandesInscriptionProvider);

    return demandesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Demandes indisponibles', onRetry: () => ref.invalidate(_demandesInscriptionProvider)),
      data: (demandes) {
        if (demandes.isEmpty) return const EmptyView(message: "Aucune demande d'inscription en attente.", icon: Icons.person_add_alt_outlined);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_demandesInscriptionProvider),
          child: ListView(
            children: [
              const SectionHeader(title: "Demandes d'inscription"),
              ...demandes.map((d) {
                final date = DateTime.tryParse(d['date_creation']?.toString() ?? '');
                final busy = _busyId == d['id'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('${d['first_name']} ${d['last_name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                              child: Text(_roleLabels[d['role']] ?? '${d['role']}', style: const TextStyle(fontSize: 10.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(d['email']?.toString() ?? '', style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        Text(
                          date != null ? 'Demandé le ${DateFormat('dd/MM/yyyy').format(date)}' : '',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: busy ? null : () => _valider(d['id'] as int),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Valider'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy ? null : () => _rejeter(d['id'] as int),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Rejeter'),
                              ),
                            ),
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
    );
  }
}
