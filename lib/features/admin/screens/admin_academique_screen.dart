import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../admin_providers.dart';

final _sallesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/salles').list());
final _matieresProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/matieres').list());

/// Miroir simplifié de `ClassesPanel` / `MatieresPanel` / `SallesPanel`
/// (frontend/src/components/academique/) : liste + création minimale par onglet. L'édition et
/// les champs avancés (tarifs, délégué, couleur...) restent à porter (voir ROADMAP.md).
class AdminAcademiqueScreen extends StatelessWidget {
  const AdminAcademiqueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Classes'), Tab(text: 'Matières'), Tab(text: 'Salles'), Tab(text: 'Année scolaire')]),
          const SizedBox(height: 12),
          const Expanded(
            child: TabBarView(children: [_ClassesTab(), _MatieresTab(), _SallesTab(), _AnneeScolaireTab()]),
          ),
        ],
      ),
    );
  }
}

const _moisLabels = [
  '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

/// Configuration des mois d'écolage actifs pour une année scolaire : les mois cochés sont
/// ceux où les élèves sont en cours et redevables de l'écolage mensuel — répercuté sur le
/// suivi mensuel affiché aux élèves/parents et sur le total dû (voir
/// `AnneeScolaire.mois_ecolage_actifs`, backend/application/models.py).
class _AnneeScolaireTab extends ConsumerStatefulWidget {
  const _AnneeScolaireTab();

  @override
  ConsumerState<_AnneeScolaireTab> createState() => _AnneeScolaireTabState();
}

class _AnneeScolaireTabState extends ConsumerState<_AnneeScolaireTab> {
  int? _anneeId;
  Set<int> _moisSelectionnes = {};
  bool _initialise = false;
  bool _sauvegardeEnCours = false;

  void _initialiserDepuis(Map<String, dynamic> annee) {
    _anneeId = annee['id'] as int;
    final mois = (annee['mois_ecolage_actifs'] as List?)?.cast<int>() ?? List.generate(12, (i) => i + 1);
    _moisSelectionnes = mois.toSet();
    _initialise = true;
  }

  Future<void> _sauvegarder() async {
    if (_anneeId == null) return;
    if (_moisSelectionnes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez au moins un mois.')));
      return;
    }
    setState(() => _sauvegardeEnCours = true);
    try {
      final tries = _moisSelectionnes.toList()..sort();
      await ResourceService('/annees-scolaires').update(_anneeId, {'mois_ecolage_actifs': tries});
      ref.invalidate(adminAnneesScolairesProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mois d'écolage enregistrés.")));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de l'enregistrement.")));
    } finally {
      if (mounted) setState(() => _sauvegardeEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anneesAsync = ref.watch(adminAnneesScolairesProvider);
    return anneesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Années scolaires indisponibles', onRetry: () => ref.invalidate(adminAnneesScolairesProvider)),
      data: (annees) {
        if (annees.isEmpty) return const EmptyView(message: 'Aucune année scolaire configurée.');
        if (!_initialise) {
          final actives = annees.where((a) => a['est_active'] == true).toList();
          _initialiserDepuis(actives.isNotEmpty ? actives.first : annees.first);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'Année scolaire', subtitle: "Mois où les élèves sont en cours et redevables de l'écolage."),
            const SizedBox(height: 12),
            if (annees.length > 1) ...[
              DropdownButtonFormField<int>(
                initialValue: _anneeId,
                decoration: const InputDecoration(labelText: 'Année scolaire'),
                items: annees
                    .map((a) => DropdownMenuItem(value: a['id'] as int, child: Text('${a['libelle']}${a['est_active'] == true ? ' (active)' : ''}')))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _initialiserDepuis(annees.firstWhere((a) => a['id'] == v)));
                },
              ),
              const SizedBox(height: 16),
            ],
            Text("Mois d'écolage actifs", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Ex : décochez novembre et décembre si les élèves ne sont pas en cours (donc pas redevables) ces mois-là.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(12, (i) {
                final mois = i + 1;
                final selectionne = _moisSelectionnes.contains(mois);
                return FilterChip(
                  label: Text(_moisLabels[mois]),
                  selected: selectionne,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _moisSelectionnes.add(mois);
                    } else {
                      _moisSelectionnes.remove(mois);
                    }
                  }),
                );
              }),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sauvegardeEnCours ? null : _sauvegarder,
                icon: _sauvegardeEnCours
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Enregistrer'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ClassesTab extends ConsumerWidget {
  const _ClassesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(adminClassesProvider);
    return classesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Classes indisponibles', onRetry: () => ref.invalidate(adminClassesProvider)),
      data: (classes) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () => _formulaireSimple(
            context: context,
            titre: 'Nouvelle classe',
            champLabel: 'Nom (ex: 2nde C)',
            onValider: (nom) async {
              await ResourceService('/classes').create({'nom': nom});
              ref.invalidate(adminClassesProvider);
            },
          ),
        ),
        body: classes.isEmpty
            ? const EmptyView(message: 'Aucune classe.')
            : ListView(
                children: classes
                    .map((c) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(c['nom']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${c['effectif']}/${c['capacite_max']} élèves${c['niveau_intitule'] != null ? ' · ${c['niveau_intitule']}' : ''}'),
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

class _MatieresTab extends ConsumerWidget {
  const _MatieresTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matieresAsync = ref.watch(_matieresProvider);
    return matieresAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Matières indisponibles', onRetry: () => ref.invalidate(_matieresProvider)),
      data: (matieres) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () => _formulaireSimple(
            context: context,
            titre: 'Nouvelle matière',
            champLabel: 'Nom de la matière',
            onValider: (intitule) async {
              await ResourceService('/matieres').create({'intitule': intitule, 'coefficient': 1});
              ref.invalidate(_matieresProvider);
            },
          ),
        ),
        body: matieres.isEmpty
            ? const EmptyView(message: 'Aucune matière.')
            : ListView(
                children: matieres
                    .map((m) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(m['intitule']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('Coefficient ${m['coefficient']}${m['enseignant'] != null ? ' · avec enseignant' : ' · sans enseignant'}'),
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

class _SallesTab extends ConsumerWidget {
  const _SallesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sallesAsync = ref.watch(_sallesProvider);
    return sallesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Salles indisponibles', onRetry: () => ref.invalidate(_sallesProvider)),
      data: (salles) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () => _formulaireSimple(
            context: context,
            titre: 'Nouvelle salle',
            champLabel: 'Nom (ex: Salle 12)',
            onValider: (nom) async {
              await ResourceService('/salles').create({'nom': nom});
              ref.invalidate(_sallesProvider);
            },
          ),
        ),
        body: salles.isEmpty
            ? const EmptyView(message: 'Aucune salle.')
            : ListView(
                children: salles
                    .map((s) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(s['nom']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('Capacité ${s['capacite']}${s['type_salle'] != null ? ' · ${s['type_salle']}' : ''}'),
                          ),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

Future<void> _formulaireSimple({
  required BuildContext context,
  required String titre,
  required String champLabel,
  required Future<void> Function(String valeur) onValider,
}) async {
  final ctrl = TextEditingController();
  bool envoiEnCours = false;
  String? erreur;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(controller: ctrl, decoration: InputDecoration(labelText: champLabel)),
            if (erreur != null) ...[
              const SizedBox(height: 8),
              Text(erreur!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: envoiEnCours
                    ? null
                    : () async {
                        if (ctrl.text.trim().isEmpty) {
                          setModalState(() => erreur = 'Ce champ est requis.');
                          return;
                        }
                        setModalState(() {
                          envoiEnCours = true;
                          erreur = null;
                        });
                        try {
                          await onValider(ctrl.text.trim());
                          if (context.mounted) Navigator.of(context).pop();
                        } catch (e) {
                          setModalState(() {
                            envoiEnCours = false;
                            erreur = 'Erreur lors de la création.';
                          });
                        }
                      },
                child: envoiEnCours ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Créer'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
