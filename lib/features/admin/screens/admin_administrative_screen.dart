import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_message.dart';
import '../../../core/api/file_download.dart';
import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/paginated_table.dart';
import '../admin_providers.dart';
import '../widgets/depense_form_dialog.dart';
import 'admin_personnel_screen.dart';

const _typeDocumentLabels = {
  'CERTIFICAT_SCOLARITE': 'Certificat de scolarité',
  'ATTESTATION': 'Attestation de fréquentation',
  'CERTIFICAT_REUSSITE': 'Certificat de réussite',
};

const _moisLabels = {
  1: 'Janvier', 2: 'Février', 3: 'Mars', 4: 'Avril', 5: 'Mai', 6: 'Juin',
  7: 'Juillet', 8: 'Août', 9: 'Septembre', 10: 'Octobre', 11: 'Novembre', 12: 'Décembre',
};

final _paiementsAdminProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/paiements').list());
final _demandesDocumentsAdminProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/demandes-documents').list());
final _depensesAdminProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/depenses').list());

String _fmtMontant(dynamic value) {
  final n = double.tryParse('$value') ?? 0;
  return NumberFormat('#,##0', 'fr_FR').format(n).replaceAll(',', ' ');
}

/// Miroir simplifié de `PaiementsPanel` / `DocumentsValidationPanel` / `PersonnelPanel`
/// (frontend/src/components/{finance,documents,personnel}/) réunis sous "Gestion Administrative",
/// comme sur le web — dont le suivi mensuel des dettes d'écolage par classe/mois avec export
/// XLSX/DOCX de la sélection, et le filtrage par classe/date sur la liste des paiements.
class AdminAdministrativeScreen extends StatelessWidget {
  const AdminAdministrativeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Paiements'), Tab(text: 'Caisse'), Tab(text: 'Documents'), Tab(text: 'Utilisateurs')]),
          const SizedBox(height: 12),
          const Expanded(
            child: TabBarView(children: [_PaiementsTab(), _CaisseTab(), _DocumentsTab(), AdminPersonnelScreen(title: 'Utilisateurs')]),
          ),
        ],
      ),
    );
  }
}

class _PaiementsTab extends ConsumerStatefulWidget {
  const _PaiementsTab();

  @override
  ConsumerState<_PaiementsTab> createState() => _PaiementsTabState();
}

class _PaiementsTabState extends ConsumerState<_PaiementsTab> {
  // Suivi mensuel par classe.
  int? _classeFiltreDettes;
  int? _moisFiltreDettes;
  final Set<int> _selectionDettes = {};
  bool _exportEnCours = false;
  int _pageDettes = 0;

  // Liste "Paiements" à plat, ci-dessous.
  String? _classeFiltreListe;
  DateTime? _dateDebutFiltre;
  DateTime? _dateFinFiltre;
  int _pagePaiements = 0;

  int? _anneeActiveId(List<Map<String, dynamic>> annees) {
    final actives = annees.where((a) => a['est_active'] == true).toList();
    if (actives.isNotEmpty) return actives.first['id'] as int;
    return annees.isNotEmpty ? annees.first['id'] as int : null;
  }

  Future<void> _exporter(String type, int anneeId) async {
    setState(() => _exportEnCours = true);
    try {
      final params = <String, String>{
        'annee_scolaire': '$anneeId',
        'type': type,
        if (_classeFiltreDettes != null) 'classe': '$_classeFiltreDettes',
        if (_moisFiltreDettes != null) 'mois': '$_moisFiltreDettes',
        if (_selectionDettes.isNotEmpty) 'etudiants': _selectionDettes.join(','),
      };
      final requete = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
      await downloadAndOpen('/paiements/dettes-par-classe-export/?$requete', 'dettes_ecolage.$type');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e, "Erreur lors de l'export."))));
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  Future<void> _choisirDate({required bool debut}) async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: (debut ? _dateDebutFiltre : _dateFinFiltre) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (choisie == null) return;
    setState(() {
      if (debut) {
        _dateDebutFiltre = choisie;
      } else {
        _dateFinFiltre = choisie;
      }
      _pagePaiements = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paiementsAsync = ref.watch(_paiementsAdminProvider);
    final classesAsync = ref.watch(adminClassesProvider);
    final anneesAsync = ref.watch(adminAnneesScolairesProvider);
    final etudiantsAsync = ref.watch(adminEtudiantsProvider);

    return anneesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Années scolaires indisponibles', onRetry: () => ref.invalidate(adminAnneesScolairesProvider)),
      data: (annees) {
        final anneeId = _anneeActiveId(annees);
        final dettesAsync = ref.watch(dettesParClasseProvider((anneeScolaireId: anneeId, classeId: _classeFiltreDettes, mois: _moisFiltreDettes)));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_paiementsAdminProvider);
            ref.invalidate(dettesParClasseProvider((anneeScolaireId: anneeId, classeId: _classeFiltreDettes, mois: _moisFiltreDettes)));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Suivi mensuel par classe', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Écolages impayés, filtrés par classe et par mois', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              classesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (classes) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<int?>(
                        initialValue: _classeFiltreDettes,
                        decoration: const InputDecoration(labelText: 'Classe', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Toutes')),
                          ...classes.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom'].toString()))),
                        ],
                        onChanged: (v) => setState(() {
                          _classeFiltreDettes = v;
                          _selectionDettes.clear();
                          _pageDettes = 0;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<int?>(
                        initialValue: _moisFiltreDettes,
                        decoration: const InputDecoration(labelText: 'Mois', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tous')),
                          ..._moisLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                        ],
                        onChanged: (v) => setState(() {
                          _moisFiltreDettes = v;
                          _selectionDettes.clear();
                          _pageDettes = 0;
                        }),
                      ),
                    ),
                    if (anneeId != null) ...[
                      OutlinedButton.icon(
                        onPressed: _exportEnCours ? null : () => _exporter('xlsx', anneeId),
                        icon: const Icon(Icons.grid_on_rounded, size: 16),
                        label: const Text('Exporter XLSX'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _exportEnCours ? null : () => _exporter('docx', anneeId),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('Exporter DOCX'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              dettesAsync.when(
                loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => const ErrorView(message: 'Suivi indisponible'),
                data: (classesDettes) {
                  final lignes = <Map<String, dynamic>>[];
                  for (final classe in classesDettes) {
                    for (final moisData in (classe['mois'] as List)) {
                      for (final etu in (moisData['endettes'] as List)) {
                        lignes.add({
                          'etudiant_id': etu['etudiant_id'] as int,
                          'classe_nom': classe['classe_nom'],
                          'mois_label': _moisLabels[moisData['mois'] as int],
                          'matricule': etu['matricule'],
                          'nom_complet': '${etu['prenom']} ${etu['nom']}',
                          'montant_du': etu['montant_du'],
                          'reste': etu['reste'],
                        });
                      }
                    }
                  }
                  if (lignes.isEmpty) return const EmptyView(message: 'Aucune dette pour ce filtre.', icon: Icons.check_circle_outline);
                  final totalPagesDettes = (lignes.length / lignesParPage).ceil();
                  final pageDettes = _pageDettes.clamp(0, totalPagesDettes - 1);
                  final debutDettes = pageDettes * lignesParPage;
                  final finDettes = (debutDettes + lignesParPage).clamp(0, lignes.length);
                  final pageLignes = lignes.sublist(debutDettes, finDettes);
                  return Column(
                    children: [
                      if (_selectionDettes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "${_selectionDettes.length} élève(s) sélectionné(s) — l'export ne portera que sur cette sélection.",
                              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: DataTable(
                                columnSpacing: 20,
                                headingRowHeight: 40,
                                dataRowMinHeight: 44,
                                dataRowMaxHeight: 52,
                                columns: const [
                                  DataColumn(label: Text('Élève'), columnWidth: FlexColumnWidth()),
                                  DataColumn(label: Text('Classe')),
                                  DataColumn(label: Text('Mois')),
                                  DataColumn(label: Text('Matricule')),
                                  DataColumn(label: Text('Montant dû'), numeric: true),
                                  DataColumn(label: Text('Reste'), numeric: true),
                                ],
                                rows: pageLignes.map((l) {
                                  final etudiantId = l['etudiant_id'] as int;
                                  return DataRow(
                                    selected: _selectionDettes.contains(etudiantId),
                                    onSelectChanged: (v) => setState(() {
                                      if (v == true) {
                                        _selectionDettes.add(etudiantId);
                                      } else {
                                        _selectionDettes.remove(etudiantId);
                                      }
                                    }),
                                    cells: [
                                      DataCell(Text(l['nom_complet'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                      DataCell(Text(l['classe_nom'].toString())),
                                      DataCell(Text(l['mois_label'].toString())),
                                      DataCell(Text(l['matricule'].toString())),
                                      DataCell(Text('${_fmtMontant(l['montant_du'])} Ar')),
                                      DataCell(Text('${_fmtMontant(l['reste'])} Ar', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red))),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      PaginationBar(
                        page: pageDettes,
                        totalPages: totalPagesDettes,
                        totalLignes: lignes.length,
                        onPageChange: (p) => setState(() => _pageDettes = p),
                      ),
                    ],
                  );
                },
              ),
              const Divider(height: 32),
              Text('Paiements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              classesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (classes) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _classeFiltreListe,
                        decoration: const InputDecoration(labelText: 'Classe', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Toutes')),
                          ...{for (final c in classes) c['nom']?.toString() ?? ''}.where((n) => n.isNotEmpty).map((n) => DropdownMenuItem(value: n, child: Text(n))),
                        ],
                        onChanged: (v) => setState(() {
                          _classeFiltreListe = v;
                          _pagePaiements = 0;
                        }),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _choisirDate(debut: true),
                      child: Text(_dateDebutFiltre == null ? 'Date début' : DateFormat('dd/MM/yyyy').format(_dateDebutFiltre!)),
                    ),
                    OutlinedButton(
                      onPressed: () => _choisirDate(debut: false),
                      child: Text(_dateFinFiltre == null ? 'Date fin' : DateFormat('dd/MM/yyyy').format(_dateFinFiltre!)),
                    ),
                    if (_classeFiltreListe != null || _dateDebutFiltre != null || _dateFinFiltre != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _classeFiltreListe = null;
                          _dateDebutFiltre = null;
                          _dateFinFiltre = null;
                          _pagePaiements = 0;
                        }),
                        child: const Text('Réinitialiser'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              paiementsAsync.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(message: 'Paiements indisponibles', onRetry: () => ref.invalidate(_paiementsAdminProvider)),
                data: (paiements) {
                  final etudiantParId = <int, Map<String, dynamic>>{
                    for (final e in etudiantsAsync.value ?? const <Map<String, dynamic>>[]) e['id'] as int: e,
                  };
                  var triees = [...paiements]..sort((a, b) => '${b['date_paiement'] ?? ''}'.compareTo('${a['date_paiement'] ?? ''}'));
                  triees = triees.where((p) {
                    final classeActuelle = etudiantParId[p['etudiant']]?['classe_actuelle']?.toString();
                    if (_classeFiltreListe != null && classeActuelle != _classeFiltreListe) return false;
                    final datePaiement = DateTime.tryParse(p['date_paiement']?.toString() ?? '');
                    if (_dateDebutFiltre != null && (datePaiement == null || datePaiement.isBefore(_dateDebutFiltre!))) return false;
                    if (_dateFinFiltre != null && (datePaiement == null || datePaiement.isAfter(_dateFinFiltre!))) return false;
                    return true;
                  }).toList();
                  if (triees.isEmpty) return const EmptyView(message: 'Aucun paiement enregistré.', icon: Icons.receipt_long_outlined);
                  final totalPagesPaiements = (triees.length / lignesParPage).ceil();
                  final pagePaiements = _pagePaiements.clamp(0, totalPagesPaiements - 1);
                  final debutPaiements = pagePaiements * lignesParPage;
                  final finPaiements = (debutPaiements + lignesParPage).clamp(0, triees.length);
                  final pageTriees = triees.sublist(debutPaiements, finPaiements);
                  return Column(
                    children: [
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: DataTable(
                                columnSpacing: 24,
                                headingRowHeight: 40,
                                dataRowMinHeight: 44,
                                dataRowMaxHeight: 52,
                                columns: const [
                                  DataColumn(label: Text('Étudiant'), columnWidth: FlexColumnWidth()),
                                  DataColumn(label: Text('Montant'), numeric: true),
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Statut')),
                                ],
                                rows: pageTriees.map((p) {
                                  final date = DateTime.tryParse(p['date_paiement']?.toString() ?? '');
                                  return DataRow(cells: [
                                    DataCell(Text(p['etudiant_nom']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                                    DataCell(Text('${_fmtMontant(p['montant'])} Ar')),
                                    DataCell(Text(date != null ? DateFormat('dd/MM/yyyy').format(date) : '')),
                                    DataCell(Text(p['statut']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      PaginationBar(
                        page: pagePaiements,
                        totalPages: totalPagesPaiements,
                        totalLignes: triees.length,
                        onPageChange: (p) => setState(() => _pagePaiements = p),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

class _DocumentsTab extends ConsumerStatefulWidget {
  const _DocumentsTab();

  @override
  ConsumerState<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends ConsumerState<_DocumentsTab> {
  int? _busyId;

  Future<void> _valider(int id) async {
    setState(() => _busyId = id);
    try {
      await ApiClient.instance.dio.post('/demandes-documents/$id/valider/');
      ref.invalidate(_demandesDocumentsAdminProvider);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la validation.')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _refuser(int id) async {
    final motifCtrl = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motif du refus'),
        content: TextField(controller: motifCtrl, decoration: const InputDecoration(hintText: 'Motif...')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(motifCtrl.text), child: const Text('Refuser')),
        ],
      ),
    );
    if (motif == null) return;
    setState(() => _busyId = id);
    try {
      await ApiClient.instance.dio.post('/demandes-documents/$id/refuser/', data: {'motif': motif});
      ref.invalidate(_demandesDocumentsAdminProvider);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors du refus.')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demandesAsync = ref.watch(_demandesDocumentsAdminProvider);
    return demandesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Demandes indisponibles', onRetry: () => ref.invalidate(_demandesDocumentsAdminProvider)),
      data: (demandes) {
        final enAttente = demandes.where((d) => d['statut'] == 'EN_ATTENTE').toList();
        if (enAttente.isEmpty) return const EmptyView(message: 'Aucune demande en attente.', icon: Icons.description_outlined);
        return ListView(
          children: enAttente.map((d) {
            final busy = _busyId == d['id'];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['etudiant_nom']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(_typeDocumentLabels[d['type_document']] ?? '${d['type_document']}', style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton(onPressed: busy ? null : () => _valider(d['id'] as int), child: const Text('Valider')),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: busy ? null : () => _refuser(d['id'] as int), child: const Text('Rejeter')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Caisse de l'établissement : total entrées (écolage/frais encaissés, cf. `PaiementEcolage.
/// montant_paye`) vs sorties (dépenses saisies manuellement, ex: loyer, facturation), avec un
/// filtre pour basculer entre les deux listes de mouvements.
class _CaisseTab extends ConsumerStatefulWidget {
  const _CaisseTab();

  @override
  ConsumerState<_CaisseTab> createState() => _CaisseTabState();
}

class _CaisseTabState extends ConsumerState<_CaisseTab> {
  String _filtre = 'entree';
  int _page = 0;
  bool _exportEnCours = false;

  double _sommeEntrees(List<Map<String, dynamic>> paiements) {
    return paiements.where((p) => p['statut'] != 'ANNULE').fold(0.0, (acc, p) => acc + (double.tryParse('${p['montant_paye']}') ?? 0));
  }

  double _sommeSorties(List<Map<String, dynamic>> depenses) {
    return depenses.fold(0.0, (acc, d) => acc + (double.tryParse('${d['montant']}') ?? 0));
  }

  Future<void> _exporter(String type) async {
    setState(() => _exportEnCours = true);
    try {
      await downloadAndOpen('/depenses/export-caisse/?filtre=$_filtre&type=$type', 'caisse_$_filtre.$type');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e, "Erreur lors de l'export."))));
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paiementsAsync = ref.watch(_paiementsAdminProvider);
    final depensesAsync = ref.watch(_depensesAdminProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_paiementsAdminProvider);
        ref.invalidate(_depensesAdminProvider);
      },
      child: paiementsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'Caisse indisponible', onRetry: () => ref.invalidate(_paiementsAdminProvider)),
        data: (paiements) => depensesAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: 'Caisse indisponible', onRetry: () => ref.invalidate(_depensesAdminProvider)),
          data: (depenses) {
            final totalEntrees = _sommeEntrees(paiements);
            final totalSorties = _sommeSorties(depenses);
            final solde = totalEntrees - totalSorties;
            final entreesTriees = paiements.where((p) => p['statut'] != 'ANNULE').toList()
              ..sort((a, b) => '${b['date_paiement'] ?? ''}'.compareTo('${a['date_paiement'] ?? ''}'));
            final sortiesTriees = [...depenses]..sort((a, b) => '${b['date_depense'] ?? ''}'.compareTo('${a['date_depense'] ?? ''}'));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Caisse', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Total encaissé, dépenses et solde de caisse', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(width: 190, child: StatCard(title: 'Total entrées', value: '${_fmtMontant(totalEntrees)} Ar', icon: Icons.arrow_downward_rounded, accentColor: Colors.green)),
                    SizedBox(width: 190, child: StatCard(title: 'Total sorties', value: '${_fmtMontant(totalSorties)} Ar', icon: Icons.arrow_upward_rounded, accentColor: Colors.red)),
                    SizedBox(
                      width: 190,
                      child: StatCard(
                        title: 'Solde de caisse',
                        value: '${_fmtMontant(solde)} Ar',
                        icon: Icons.account_balance_wallet_rounded,
                        accentColor: solde >= 0 ? scheme.primary : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Entrées'),
                      selected: _filtre == 'entree',
                      onSelected: (_) => setState(() {
                        _filtre = 'entree';
                        _page = 0;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Sorties'),
                      selected: _filtre == 'sortie',
                      onSelected: (_) => setState(() {
                        _filtre = 'sortie';
                        _page = 0;
                      }),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exportEnCours ? null : () => _exporter('xlsx'),
                      icon: const Icon(Icons.grid_on_rounded, size: 16),
                      label: const Text('Exporter XLSX'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exportEnCours ? null : () => _exporter('docx'),
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: const Text('Exporter DOCX'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => ouvrirFormulaireDepense(
                        context,
                        onEnregistre: () {
                          ref.invalidate(_depensesAdminProvider);
                          setState(() {
                            _filtre = 'sortie';
                            _page = 0;
                          });
                        },
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Ajouter une dépense'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_filtre == 'entree')
                  if (entreesTriees.isEmpty)
                    const EmptyView(message: 'Aucune entrée enregistrée.', icon: Icons.arrow_downward_rounded)
                  else
                    Builder(builder: (context) {
                      final totalPages = (entreesTriees.length / lignesParPage).ceil();
                      final page = _page.clamp(0, totalPages - 1);
                      final debut = page * lignesParPage;
                      final fin = (debut + lignesParPage).clamp(0, entreesTriees.length);
                      final pageLignes = entreesTriees.sublist(debut, fin);
                      return Column(
                        children: [
                          ResponsiveDataTable(
                            table: DataTable(
                              columnSpacing: 20,
                              headingRowHeight: 40,
                              dataRowMinHeight: 44,
                              dataRowMaxHeight: 52,
                              columns: const [
                                DataColumn(label: Text('Élève'), columnWidth: FlexColumnWidth()),
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Mode')),
                                DataColumn(label: Text('Montant'), numeric: true),
                              ],
                              rows: pageLignes.map((p) {
                                final date = DateTime.tryParse(p['date_paiement']?.toString() ?? '');
                                return DataRow(cells: [
                                  DataCell(Text(p['etudiant_nom']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(Text(date != null ? DateFormat('dd/MM/yyyy').format(date) : '')),
                                  DataCell(Text(p['mode_paiement']?.toString() ?? '')),
                                  DataCell(Text('+${_fmtMontant(p['montant_paye'])} Ar', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green))),
                                ]);
                              }).toList(),
                            ),
                          ),
                          PaginationBar(page: page, totalPages: totalPages, totalLignes: entreesTriees.length, onPageChange: (p) => setState(() => _page = p)),
                        ],
                      );
                    })
                else if (sortiesTriees.isEmpty)
                  const EmptyView(message: 'Aucune dépense enregistrée.', icon: Icons.arrow_upward_rounded)
                else
                  Builder(builder: (context) {
                    final totalPages = (sortiesTriees.length / lignesParPage).ceil();
                    final page = _page.clamp(0, totalPages - 1);
                    final debut = page * lignesParPage;
                    final fin = (debut + lignesParPage).clamp(0, sortiesTriees.length);
                    final pageLignes = sortiesTriees.sublist(debut, fin);
                    return Column(
                      children: [
                        ResponsiveDataTable(
                          table: DataTable(
                            columnSpacing: 20,
                            headingRowHeight: 40,
                            dataRowMinHeight: 44,
                            dataRowMaxHeight: 52,
                            columns: const [
                              DataColumn(label: Text('Titre'), columnWidth: FlexColumnWidth()),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Note'), columnWidth: FlexColumnWidth()),
                              DataColumn(label: Text('Montant'), numeric: true),
                              DataColumn(label: Text('')),
                            ],
                            rows: pageLignes.map((d) {
                              final date = DateTime.tryParse(d['date_depense']?.toString() ?? '');
                              return DataRow(cells: [
                                DataCell(Text(d['titre']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(date != null ? DateFormat('dd/MM/yyyy').format(date) : '')),
                                DataCell(Text(d['note']?.toString() ?? '—')),
                                DataCell(Text('-${_fmtMontant(d['montant'])} Ar', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red))),
                                DataCell(IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  tooltip: 'Supprimer',
                                  onPressed: () async {
                                    await ResourceService('/depenses').remove(d['id']);
                                    ref.invalidate(_depensesAdminProvider);
                                  },
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                        PaginationBar(page: page, totalPages: totalPages, totalLignes: sortiesTriees.length, onPageChange: (p) => setState(() => _page = p)),
                      ],
                    );
                  }),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }
}
