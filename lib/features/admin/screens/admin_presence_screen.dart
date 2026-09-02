import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_message.dart';
import '../../../core/api/file_download.dart';
import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/paginated_table.dart';

final _presencesAdminProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/presences').list());

/// Miroir de la partie oversight de `AttendancePanel` (frontend/src/components/presences/AttendancePanel.jsx) :
/// indicateurs + validation des justificatifs. La saisie d'appel n'est pas reprise ici (voir
/// l'écran équivalent côté enseignant, qui couvre le même besoin).
class AdminPresenceScreen extends ConsumerStatefulWidget {
  const AdminPresenceScreen({super.key});

  @override
  ConsumerState<AdminPresenceScreen> createState() => _AdminPresenceScreenState();
}

class _AdminPresenceScreenState extends ConsumerState<AdminPresenceScreen> {
  int? _busyId;
  int _page = 0;
  bool _exportEnCours = false;

  Future<void> _agirSurJustificatif(int id, bool accepter) async {
    setState(() => _busyId = id);
    try {
      await ApiClient.instance.dio.post('/presences/$id/${accepter ? 'valider' : 'refuser'}-justification/');
      ref.invalidate(_presencesAdminProvider);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors du traitement du justificatif.')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _exporter(String type) async {
    setState(() => _exportEnCours = true);
    try {
      await downloadAndOpen('/presences/export/?type=$type', 'presences.$type');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e, "Erreur lors de l'export."))));
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presencesAsync = ref.watch(_presencesAdminProvider);

    return presencesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Présences indisponibles', onRetry: () => ref.invalidate(_presencesAdminProvider)),
      data: (presences) {
        final total = presences.length;
        final compteurs = <String, int>{};
        for (final p in presences) {
          final s = p['statut'] as String? ?? '';
          compteurs[s] = (compteurs[s] ?? 0) + 1;
        }
        final tauxPresence = total > 0 ? ((compteurs['P'] ?? 0) / total * 100).toStringAsFixed(1) : null;
        final nonJustifiees = presences.where((p) => p['statut'] == 'A' && (p['justificatif'] == null || p['justificatif'] == '')).toList();
        final enAttente = presences.where((p) => p['justification_statut'] == 'EN_ATTENTE').toList();

        final totalPages = nonJustifiees.isEmpty ? 1 : (nonJustifiees.length / lignesParPage).ceil();
        final page = _page.clamp(0, totalPages - 1);
        final debut = page * lignesParPage;
        final fin = (debut + lignesParPage).clamp(0, nonJustifiees.length);
        final pageNonJustifiees = nonJustifiees.sublist(debut, fin);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_presencesAdminProvider),
          child: ListView(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: SectionHeader(title: 'Présence & Absences')),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _exportEnCours ? null : () => _exporter('xlsx'),
                        icon: const Icon(Icons.grid_on_rounded, size: 16),
                        label: const Text('XLSX'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _exportEnCours ? null : () => _exporter('docx'),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('DOCX'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: StatCard(title: 'Taux présence général', value: tauxPresence != null ? '$tauxPresence%' : '—', icon: Icons.check_circle_outline)),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(title: 'Absences', value: '${compteurs['A'] ?? 0}', icon: Icons.cancel_outlined)),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(title: 'Non justifiées', value: '${nonJustifiees.length}', icon: Icons.warning_amber_outlined, accentColor: Colors.orange)),
                ],
              ),
              if (enAttente.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Justificatifs en attente', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ResponsiveDataTable(
                  table: DataTable(
                    columnSpacing: 16,
                    headingRowHeight: 40,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 64,
                    columns: const [
                      DataColumn(label: Text('Élève')),
                      DataColumn(label: Text('Cours')),
                      DataColumn(label: Text('Justificatif'), columnWidth: FlexColumnWidth()),
                      DataColumn(label: Text('')),
                    ],
                    rows: enAttente.map((item) {
                      final id = item['id'] as int;
                      final busy = _busyId == id;
                      return DataRow(cells: [
                        DataCell(Text(item['etudiant_nom']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text('${item['date_cours']} · ${item['matiere_intitule'] ?? ''}')),
                        DataCell(Text(item['justificatif']?.toString() ?? '—')),
                        DataCell(
                          busy
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                                      tooltip: 'Accepter',
                                      onPressed: () => _agirSurJustificatif(id, true),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                                      tooltip: 'Refuser',
                                      onPressed: () => _agirSurJustificatif(id, false),
                                    ),
                                  ],
                                ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text('Absences non justifiées', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (nonJustifiees.isEmpty)
                const EmptyView(message: 'Aucune absence non justifiée.', icon: Icons.event_available_outlined)
              else ...[
                ResponsiveDataTable(
                  table: DataTable(
                    columnSpacing: 20,
                    headingRowHeight: 40,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 52,
                    columns: const [
                      DataColumn(label: Text('Élève'), columnWidth: FlexColumnWidth()),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Matière')),
                    ],
                    rows: pageNonJustifiees.map((item) {
                      return DataRow(cells: [
                        DataCell(Text(item['etudiant_nom']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(item['date_cours']?.toString() ?? '')),
                        DataCell(Text(item['matiere_intitule']?.toString() ?? '')),
                      ]);
                    }).toList(),
                  ),
                ),
                PaginationBar(page: page, totalPages: totalPages, totalLignes: nonJustifiees.length, onPageChange: (p) => setState(() => _page = p)),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
