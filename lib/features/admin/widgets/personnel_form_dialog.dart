import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_message.dart';
import '../../../core/api/resource_service.dart';
import '../admin_providers.dart';

const _roleLabels = {
  'ADMIN': 'Administrateur',
  'RESPONSABLE': 'Responsable pédagogique',
  'ENSEIGNANT': 'Enseignant',
  'SECRETARIAT': 'Bureau administratif',
  'GARDIEN': "Gardien de l'école",
};

const _motDePasseTemporaire = '12345678';

/// Miroir de `PersonnelPanel` (frontend/src/components/personnel/PersonnelPanel.jsx) : création
/// ou modification d'un compte personnel. Pour un enseignant, propose en plus l'affectation des
/// matières enseignées, des classes où il intervient, de la classe dont il est titulaire et de
/// son salaire — ces liens sont portés par `Matiere.enseignant`/`Classe.enseignants`/
/// `Classe.titulaire`/`DossierEnseignant`, pas par le compte lui-même, donc appliqués via des
/// PATCH séparés juste après la création/modification du compte (même logique que le web).
Future<void> ouvrirFormulairePersonnel(BuildContext context, {Map<String, dynamic>? personnel, String? roleFilter}) {
  return showDialog(
    context: context,
    builder: (context) => _PersonnelFormDialog(personnel: personnel, roleFilter: roleFilter),
  );
}

class _PersonnelFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? personnel;
  final String? roleFilter;
  const _PersonnelFormDialog({this.personnel, this.roleFilter});

  @override
  ConsumerState<_PersonnelFormDialog> createState() => _PersonnelFormDialogState();
}

class _PersonnelFormDialogState extends ConsumerState<_PersonnelFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _nomCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _matriculeCtrl;
  late final TextEditingController _telephoneCtrl;
  late final TextEditingController _salaireCtrl;
  late String _role;
  final Set<int> _matieresChoisies = {};
  final Set<int> _classesChoisies = {};
  int? _classeTitulaire;
  bool _enCours = false;
  bool _initialise = false;

  bool get _estEdition => widget.personnel != null;
  bool get _creeUnEnseignant => widget.roleFilter == 'ENSEIGNANT' || (widget.roleFilter == null && _role == 'ENSEIGNANT');

  @override
  void initState() {
    super.initState();
    final p = widget.personnel;
    _prenomCtrl = TextEditingController(text: p?['first_name']?.toString() ?? '');
    _nomCtrl = TextEditingController(text: p?['last_name']?.toString() ?? '');
    _emailCtrl = TextEditingController(text: p?['email']?.toString() ?? '');
    _matriculeCtrl = TextEditingController(text: p?['matricule']?.toString() ?? '');
    _telephoneCtrl = TextEditingController(text: p?['telephone']?.toString() ?? '');
    _salaireCtrl = TextEditingController();
    _role = p?['role']?.toString() ?? widget.roleFilter ?? 'ENSEIGNANT';
  }

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _matriculeCtrl.dispose();
    _telephoneCtrl.dispose();
    _salaireCtrl.dispose();
    super.dispose();
  }

  void _initialiserAffectations(List<Map<String, dynamic>> matieres, List<Map<String, dynamic>> classes, List<Map<String, dynamic>> dossiersRH) {
    if (_initialise || !_estEdition) return;
    final id = widget.personnel!['id'] as int;
    _matieresChoisies.addAll(matieres.where((m) => m['enseignant'] == id).map((m) => m['id'] as int));
    _classesChoisies.addAll(classes.where((c) => (c['enseignants'] as List?)?.contains(id) == true).map((c) => c['id'] as int));
    final titulaire = classes.where((c) => c['titulaire'] == id).toList();
    _classeTitulaire = titulaire.isNotEmpty ? titulaire.first['id'] as int : null;
    final dossier = dossiersRH.where((d) => d['enseignant'] == id).toList();
    if (dossier.isNotEmpty && dossier.first['salaire'] != null) _salaireCtrl.text = dossier.first['salaire'].toString();
    _initialise = true;
  }

  Future<void> _appliquerAffectations(int enseignantId, List<Map<String, dynamic>> matieres, List<Map<String, dynamic>> classes) async {
    final service = ResourceService('/matieres');
    final classesService = ResourceService('/classes');

    final matieresAvant = matieres.where((m) => m['enseignant'] == enseignantId).map((m) => m['id'] as int).toSet();
    for (final id in _matieresChoisies.difference(matieresAvant)) {
      await service.update(id, {'enseignant': enseignantId});
    }
    for (final id in matieresAvant.difference(_matieresChoisies)) {
      await service.update(id, {'enseignant': null});
    }

    final classesAvant = classes.where((c) => (c['enseignants'] as List?)?.contains(enseignantId) == true).map((c) => c['id'] as int).toSet();
    for (final id in _classesChoisies.difference(classesAvant)) {
      final classe = classes.firstWhere((c) => c['id'] == id);
      final actuels = ((classe['enseignants'] as List?) ?? []).cast<int>().toSet()..add(enseignantId);
      await classesService.update(id, {'enseignants': actuels.toList()});
    }
    for (final id in classesAvant.difference(_classesChoisies)) {
      final classe = classes.firstWhere((c) => c['id'] == id);
      final actuels = ((classe['enseignants'] as List?) ?? []).cast<int>().where((e) => e != enseignantId).toList();
      await classesService.update(id, {'enseignants': actuels});
    }

    final titulaireAvant = classes.where((c) => c['titulaire'] == enseignantId).toList();
    final titulaireAvantId = titulaireAvant.isNotEmpty ? titulaireAvant.first['id'] as int : null;
    if (titulaireAvantId != _classeTitulaire) {
      if (titulaireAvantId != null) await classesService.update(titulaireAvantId, {'titulaire': null});
      if (_classeTitulaire != null) await classesService.update(_classeTitulaire, {'titulaire': enseignantId});
    }
  }

  Future<void> _appliquerSalaire(int enseignantId, List<Map<String, dynamic>> dossiersRH) async {
    final texte = _salaireCtrl.text.trim();
    if (texte.isEmpty) return;
    final salaire = num.tryParse(texte);
    if (salaire == null) return;
    final existants = dossiersRH.where((d) => d['enseignant'] == enseignantId).toList();
    final service = ResourceService('/dossiers-enseignants');
    if (existants.isNotEmpty) {
      final actuel = num.tryParse('${existants.first['salaire']}');
      if (actuel != salaire) await service.update(existants.first['id'], {'salaire': salaire});
    } else {
      await service.create({'enseignant': enseignantId, 'salaire': salaire});
    }
  }

  Future<void> _enregistrer(List<Map<String, dynamic>> matieres, List<Map<String, dynamic>> classes, List<Map<String, dynamic>> dossiersRH) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    try {
      final champs = <String, dynamic>{
        'first_name': _prenomCtrl.text.trim(),
        'last_name': _nomCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': _role,
        if (_telephoneCtrl.text.trim().isNotEmpty) 'telephone': _telephoneCtrl.text.trim(),
      };
      final service = ResourceService('/personnel');
      int enseignantId;
      if (_estEdition) {
        final resultat = await service.update(widget.personnel!['id'], champs);
        enseignantId = resultat['id'] as int;
      } else {
        if (_matriculeCtrl.text.trim().isNotEmpty) champs['matricule'] = _matriculeCtrl.text.trim();
        final resultat = await service.create(champs);
        enseignantId = resultat['id'] as int;
      }

      if (_creeUnEnseignant) {
        await _appliquerAffectations(enseignantId, matieres, classes);
        await _appliquerSalaire(enseignantId, dossiersRH);
      }

      ref.invalidate(adminPersonnelProvider);
      ref.invalidate(adminMatieresProvider);
      ref.invalidate(adminClassesProvider);
      ref.invalidate(adminDossiersEnseignantsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_estEdition ? 'Compte mis à jour.' : "Compte créé. Mot de passe temporaire : $_motDePasseTemporaire"),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreurChamps(e, "Erreur lors de l'enregistrement du compte."))));
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matieresAsync = ref.watch(adminMatieresProvider);
    final classesAsync = ref.watch(adminClassesProvider);
    final dossiersAsync = ref.watch(adminDossiersEnseignantsProvider);
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(_estEdition ? 'Modifier — ${widget.personnel!['first_name']} ${widget.personnel!['last_name']}' : 'Nouveau compte'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_estEdition)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Mot de passe temporaire attribué automatiquement : $_motDePasseTemporaire — à changer à la première connexion.',
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prenomCtrl,
                        decoration: const InputDecoration(labelText: 'Prénom *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _nomCtrl,
                        decoration: const InputDecoration(labelText: 'Nom *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _matriculeCtrl,
                  enabled: !_estEdition,
                  decoration: const InputDecoration(labelText: 'Matricule (identifiant de connexion, optionnel)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: (widget.roleFilter != null || _estEdition)
                          ? InputDecorator(
                              decoration: const InputDecoration(labelText: 'Rôle'),
                              child: Text(_roleLabels[_role] ?? _role, style: TextStyle(color: scheme.onSurfaceVariant)),
                            )
                          : DropdownButtonFormField<String>(
                              initialValue: _role,
                              decoration: const InputDecoration(labelText: 'Rôle'),
                              items: _roleLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                              onChanged: (v) => setState(() => _role = v ?? 'ENSEIGNANT'),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: _telephoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone'), keyboardType: TextInputType.phone)),
                  ],
                ),
                if (_creeUnEnseignant)
                  matieresAsync.when(
                    loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => const Text('Matières indisponibles.'),
                    data: (matieres) => classesAsync.when(
                      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
                      error: (e, _) => const Text('Classes indisponibles.'),
                      data: (classes) => dossiersAsync.when(
                        loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
                        error: (e, _) => const Text('Dossiers RH indisponibles.'),
                        data: (dossiersRH) {
                          _initialiserAffectations(matieres, classes, dossiersRH);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(padding: EdgeInsets.only(top: 16, bottom: 8), child: Divider(height: 1)),
                              Text('Matières enseignées', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                              const SizedBox(height: 6),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 160),
                                decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
                                child: matieres.isEmpty
                                    ? const Padding(padding: EdgeInsets.all(12), child: Text('Aucune matière créée.', style: TextStyle(fontSize: 12)))
                                    : ListView(
                                        shrinkWrap: true,
                                        children: matieres.map((m) {
                                          final id = m['id'] as int;
                                          return CheckboxListTile(
                                            dense: true,
                                            value: _matieresChoisies.contains(id),
                                            title: Text(m['intitule']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                                            subtitle: m['enseignant_nom'] != null ? Text('actuel : ${m['enseignant_nom']}', style: const TextStyle(fontSize: 11)) : null,
                                            onChanged: (v) => setState(() {
                                              if (v == true) {
                                                _matieresChoisies.add(id);
                                              } else {
                                                _matieresChoisies.remove(id);
                                              }
                                            }),
                                          );
                                        }).toList(),
                                      ),
                              ),
                              const SizedBox(height: 14),
                              Text('Classes qu\'il peut enseigner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                              const SizedBox(height: 6),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 160),
                                decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
                                child: classes.isEmpty
                                    ? const Padding(padding: EdgeInsets.all(12), child: Text('Aucune classe créée.', style: TextStyle(fontSize: 12)))
                                    : ListView(
                                        shrinkWrap: true,
                                        children: classes.map((c) {
                                          final id = c['id'] as int;
                                          return CheckboxListTile(
                                            dense: true,
                                            value: _classesChoisies.contains(id),
                                            title: Text(c['nom']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                                            onChanged: (v) => setState(() {
                                              if (v == true) {
                                                _classesChoisies.add(id);
                                              } else {
                                                _classesChoisies.remove(id);
                                              }
                                            }),
                                          );
                                        }).toList(),
                                      ),
                              ),
                              const SizedBox(height: 14),
                              Text('Classe dont il est titulaire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int?>(
                                initialValue: _classeTitulaire,
                                decoration: const InputDecoration(isDense: true),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Aucune')),
                                  ...classes.map((c) => DropdownMenuItem(
                                        value: c['id'] as int,
                                        child: Text('${c['nom']}${c['titulaire_nom'] != null ? ' (actuel : ${c['titulaire_nom']})' : ''}'),
                                      )),
                                ],
                                onChanged: (v) => setState(() => _classeTitulaire = v),
                              ),
                              const SizedBox(height: 14),
                              Text('Salaire (Ar/mois)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _salaireCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(isDense: true, hintText: 'Ex: 800000'),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _enCours ? null : () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: _enCours
              ? null
              : () {
                  final matieres = ref.read(adminMatieresProvider).value ?? [];
                  final classes = ref.read(adminClassesProvider).value ?? [];
                  final dossiersRH = ref.read(adminDossiersEnseignantsProvider).value ?? [];
                  _enregistrer(matieres, classes, dossiersRH);
                },
          child: _enCours
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_estEdition ? 'Enregistrer' : 'Créer le compte'),
        ),
      ],
    );
  }
}
