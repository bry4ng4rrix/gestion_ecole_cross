import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_message.dart';
import '../../../core/api/file_download.dart';
import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/paginated_table.dart';
import '../admin_providers.dart';
import '../widgets/personnel_form_dialog.dart';

const _roleLabels = {
  'ADMIN': 'Administrateur',
  'RESPONSABLE': 'Responsable pédagogique',
  'ENSEIGNANT': 'Enseignant',
  'SECRETARIAT': 'Bureau administratif',
  'GARDIEN': "Gardien de l'école",
};

/// Miroir de `PersonnelPanel` (frontend/src/components/personnel/PersonnelPanel.jsx) : liste +
/// création/modification/suppression de compte. Pour un enseignant, affiche ses matières/classes
/// affectées (miroir de la colonne "Matières / Classe" du web).
class AdminPersonnelScreen extends ConsumerStatefulWidget {
  final String? roleFilter;
  final String title;
  const AdminPersonnelScreen({super.key, this.roleFilter, required this.title});

  @override
  ConsumerState<AdminPersonnelScreen> createState() => _AdminPersonnelScreenState();
}

class _AdminPersonnelScreenState extends ConsumerState<AdminPersonnelScreen> {
  int _page = 0;
  bool _exportEnCours = false;

  Future<void> _supprimer(Map<String, dynamic> personnel) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text('${personnel['first_name']} ${personnel['last_name']} sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await ResourceService('/personnel').remove(personnel['id']);
      ref.invalidate(adminPersonnelProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte supprimé.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la suppression.')));
    }
  }

  Future<void> _exporter(String type) async {
    setState(() => _exportEnCours = true);
    try {
      final params = <String, String>{'type': type, if (widget.roleFilter != null) 'role': widget.roleFilter!};
      final requete = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
      await downloadAndOpen('/personnel/export/?$requete', 'personnel.$type');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e, "Erreur lors de l'export."))));
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final personnelAsync = ref.watch(adminPersonnelProvider);
    final matieresAsync = ref.watch(adminMatieresProvider);
    final classesAsync = ref.watch(adminClassesProvider);
    final scheme = Theme.of(context).colorScheme;

    return personnelAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Personnel indisponible', onRetry: () => ref.invalidate(adminPersonnelProvider)),
      data: (personnel) {
        final liste = widget.roleFilter != null ? personnel.where((p) => p['role'] == widget.roleFilter).toList() : personnel;
        final matieres = matieresAsync.value ?? [];
        final classes = classesAsync.value ?? [];
        final avecAffectations = widget.roleFilter == 'ENSEIGNANT';

        String affectations(int id) {
          if (!avecAffectations) return '';
          final mats = matieres.where((m) => m['enseignant'] == id).map((m) => m['intitule']?.toString() ?? '').join(', ');
          final classesEnseignees = classes.where((c) => (c['enseignants'] as List?)?.contains(id) == true).map((c) => c['nom']?.toString() ?? '').toList();
          final titulaireDe = classes.where((c) => c['titulaire'] == id).toList();
          final buffer = StringBuffer(mats.isEmpty ? '—' : mats);
          if (classesEnseignees.isNotEmpty) buffer.write(' · Classes : ${classesEnseignees.join(', ')}');
          if (titulaireDe.isNotEmpty) buffer.write(' · Titulaire : ${titulaireDe.first['nom']}');
          return buffer.toString();
        }

        final totalPages = liste.isEmpty ? 1 : (liste.length / lignesParPage).ceil();
        final page = _page.clamp(0, totalPages - 1);
        final debut = page * lignesParPage;
        final fin = (debut + lignesParPage).clamp(0, liste.length);
        final pagePersonnel = liste.sublist(debut, fin);

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => ouvrirFormulairePersonnel(context, roleFilter: widget.roleFilter),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Compte'),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminPersonnelProvider);
              ref.invalidate(adminMatieresProvider);
              ref.invalidate(adminClassesProvider);
            },
            child: ListView(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SectionHeader(title: widget.title)),
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
                const SizedBox(height: 10),
                if (liste.isEmpty)
                  const EmptyView(message: 'Aucun compte.', icon: Icons.people_outline)
                else ...[
                  ResponsiveDataTable(
                    table: DataTable(
                      columnSpacing: 16,
                      headingRowHeight: 40,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 64,
                      columns: [
                        const DataColumn(label: Text('Nom'), columnWidth: FlexColumnWidth()),
                        const DataColumn(label: Text('Contact')),
                        if (widget.roleFilter == null) const DataColumn(label: Text('Rôle')),
                        if (avecAffectations) const DataColumn(label: Text('Affectations'), columnWidth: FlexColumnWidth()),
                        const DataColumn(label: Text('')),
                      ],
                      rows: pagePersonnel.map((p) {
                        final id = p['id'] as int;
                        return DataRow(cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                UserAvatar(photoUrl: p['photo'] as String?, initials: _initials(p), radius: 15),
                                const SizedBox(width: 10),
                                Flexible(child: Text('${p['first_name']} ${p['last_name']}', style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                          DataCell(Text('${p['email'] ?? ''}${p['matricule'] != null ? ' · ${p['matricule']}' : ''}')),
                          if (widget.roleFilter == null)
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                                child: Text(_roleLabels[p['role']] ?? '${p['role']}', style: const TextStyle(fontSize: 10.5)),
                              ),
                            ),
                          if (avecAffectations) DataCell(Text(affectations(id), style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Modifier',
                                  onPressed: () => ouvrirFormulairePersonnel(context, personnel: p, roleFilter: widget.roleFilter),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 20, color: scheme.error),
                                  tooltip: 'Supprimer',
                                  onPressed: () => _supprimer(p),
                                ),
                              ],
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                  PaginationBar(page: page, totalPages: totalPages, totalLignes: liste.length, onPageChange: (p) => setState(() => _page = p)),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  String _initials(Map<String, dynamic> p) {
    final f = (p['first_name'] as String? ?? '').isNotEmpty ? (p['first_name'] as String)[0] : '';
    final l = (p['last_name'] as String? ?? '').isNotEmpty ? (p['last_name'] as String)[0] : '';
    final r = '$f$l'.toUpperCase();
    return r.isEmpty ? '?' : r;
  }
}
