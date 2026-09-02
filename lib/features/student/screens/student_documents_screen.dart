import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/file_download.dart';
import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../student_providers.dart';

const _typeDocumentLabels = {
  'CERTIFICAT_SCOLARITE': 'Certificat de scolarité',
  'ATTESTATION': 'Attestation de fréquentation',
  'CERTIFICAT_REUSSITE': 'Certificat de réussite',
};
const _statutLabels = {'EN_ATTENTE': 'En attente', 'VALIDE': 'Validé', 'REFUSE': 'Refusé'};
const _statutColors = {'EN_ATTENTE': Colors.orange, 'VALIDE': Colors.green, 'REFUSE': Colors.red};

final _anneesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/annees-scolaires').list());
final _demandesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/demandes-documents').list());

/// Miroir de `MyDocuments` (frontend/src/pages/StudentDashboard.jsx).
class StudentDocumentsScreen extends ConsumerStatefulWidget {
  const StudentDocumentsScreen({super.key});

  @override
  ConsumerState<StudentDocumentsScreen> createState() => _StudentDocumentsScreenState();
}

class _StudentDocumentsScreenState extends ConsumerState<StudentDocumentsScreen> {
  bool _demandeEnCours = false;

  Future<void> _demander(String typeDocument, int etudiantId, int anneeScolaireId) async {
    setState(() => _demandeEnCours = true);
    try {
      await ResourceService('/demandes-documents').create({'etudiant': etudiantId, 'annee_scolaire': anneeScolaireId, 'type_document': typeDocument});
      ref.invalidate(_demandesProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Demande envoyée. Elle sera traitée par l'administration.")));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la demande.')));
    } finally {
      if (mounted) setState(() => _demandeEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dossierAsync = ref.watch(monDossierProvider);
    final anneesAsync = ref.watch(_anneesProvider);
    final demandesAsync = ref.watch(_demandesProvider);

    return dossierAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => const ErrorView(message: 'Dossier indisponible'),
      data: (dossier) => anneesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'Années scolaires indisponibles'),
        data: (annees) {
          final actives = annees.where((a) => a['est_active'] == true).toList();
          final anneeId = actives.isNotEmpty ? actives.first['id'] as int : (annees.isNotEmpty ? annees.first['id'] as int : null);
          final peutDemander = dossier != null && anneeId != null;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_demandesProvider),
            child: ListView(
              children: [
                const SectionHeader(title: 'Mes Documents', subtitle: 'Demande et téléchargement de vos documents administratifs'),
                ..._typeDocumentLabels.entries.map((e) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(e.value),
                        trailing: FilledButton.tonal(
                          onPressed: (!peutDemander || _demandeEnCours) ? null : () => _demander(e.key, dossier['id'] as int, anneeId),
                          child: const Text('Demander'),
                        ),
                      ),
                    )),
                const SizedBox(height: 16),
                Text('Mes demandes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                demandesAsync.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => const ErrorView(message: 'Demandes indisponibles'),
                  data: (demandes) {
                    if (demandes.isEmpty) return const EmptyView(message: "Aucune demande pour l'instant.");
                    return Column(
                      children: demandes.map((d) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.insert_drive_file_outlined),
                            title: Text(_typeDocumentLabels[d['type_document']] ?? '${d['type_document']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: (_statutColors[d['statut']] ?? Colors.grey).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                  child: Text(_statutLabels[d['statut']] ?? '${d['statut']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statutColors[d['statut']] ?? Colors.grey)),
                                ),
                                if (d['statut'] == 'VALIDE')
                                  IconButton(
                                    icon: const Icon(Icons.download_outlined),
                                    onPressed: () async {
                                      try {
                                        await downloadAndOpen('/demandes-documents/${d['id']}/pdf/', '${d['type_document'].toString().toLowerCase()}.pdf');
                                      } catch (_) {
                                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir le document.")));
                                      }
                                    },
                                  ),
                              ],
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
}
