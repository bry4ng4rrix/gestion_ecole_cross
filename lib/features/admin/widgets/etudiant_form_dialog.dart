import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/common.dart';
import '../admin_providers.dart';

/// Miroir de `EMPTY_FORM` + `startEdit`/`handleSubmit` (frontend/src/components/etudiants/EtudiantsPanel.jsx) :
/// création ou modification d'un dossier élève. En création uniquement : matricule (obligatoire,
/// non modifiable ensuite) et affectation à une classe (crée l'inscription associée) — le
/// changement de classe ultérieur passe par l'action dédiée "Changer de classe".
Future<void> ouvrirFormulaireEtudiant(BuildContext context, {Map<String, dynamic>? etudiant, int? anneeScolaireId}) {
  return showDialog(
    context: context,
    builder: (context) => _EtudiantFormDialog(etudiant: etudiant, anneeScolaireId: anneeScolaireId),
  );
}

class _EtudiantFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? etudiant;
  final int? anneeScolaireId;
  const _EtudiantFormDialog({this.etudiant, this.anneeScolaireId});

  @override
  ConsumerState<_EtudiantFormDialog> createState() => _EtudiantFormDialogState();
}

class _EtudiantFormDialogState extends ConsumerState<_EtudiantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _matriculeCtrl;
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _nomCtrl;
  late final TextEditingController _lieuNaissanceCtrl;
  late final TextEditingController _adresseCtrl;
  late final TextEditingController _telephoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _contactUrgenceNomCtrl;
  late final TextEditingController _contactUrgenceTelCtrl;
  String _genre = 'H';
  DateTime? _dateNaissance;
  int? _classeId;
  XFile? _photo;
  bool _enCours = false;

  bool get _estEdition => widget.etudiant != null;

  @override
  void initState() {
    super.initState();
    final e = widget.etudiant;
    _matriculeCtrl = TextEditingController(text: e?['matricule']?.toString() ?? '');
    _prenomCtrl = TextEditingController(text: e?['prenom']?.toString() ?? '');
    _nomCtrl = TextEditingController(text: e?['nom']?.toString() ?? '');
    _lieuNaissanceCtrl = TextEditingController(text: e?['lieu_naissance']?.toString() ?? '');
    _adresseCtrl = TextEditingController(text: e?['adresse']?.toString() ?? '');
    _telephoneCtrl = TextEditingController(text: e?['telephone']?.toString() ?? '');
    _emailCtrl = TextEditingController(text: e?['email']?.toString() ?? '');
    _contactUrgenceNomCtrl = TextEditingController(text: e?['contact_urgence_nom']?.toString() ?? '');
    _contactUrgenceTelCtrl = TextEditingController(text: e?['contact_urgence_telephone']?.toString() ?? '');
    _genre = e?['genre']?.toString() ?? 'H';
    if (e?['date_naissance'] != null) {
      _dateNaissance = DateTime.tryParse(e!['date_naissance'].toString());
    }
  }

  @override
  void dispose() {
    _matriculeCtrl.dispose();
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _lieuNaissanceCtrl.dispose();
    _adresseCtrl.dispose();
    _telephoneCtrl.dispose();
    _emailCtrl.dispose();
    _contactUrgenceNomCtrl.dispose();
    _contactUrgenceTelCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final maintenant = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(maintenant.year - 15),
      firstDate: DateTime(1950),
      lastDate: maintenant,
    );
    if (choisie != null) setState(() => _dateNaissance = choisie);
  }

  Future<void> _choisirPhoto() async {
    final fichier = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (fichier != null) setState(() => _photo = fichier);
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateNaissance == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La date de naissance est requise.')));
      return;
    }
    setState(() => _enCours = true);
    try {
      final champs = <String, dynamic>{
        'prenom': _prenomCtrl.text.trim(),
        'nom': _nomCtrl.text.trim(),
        'genre': _genre,
        'date_naissance': DateFormat('yyyy-MM-dd').format(_dateNaissance!),
        'lieu_naissance': _lieuNaissanceCtrl.text.trim(),
        if (_adresseCtrl.text.trim().isNotEmpty) 'adresse': _adresseCtrl.text.trim(),
        if (_telephoneCtrl.text.trim().isNotEmpty) 'telephone': _telephoneCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
        if (_contactUrgenceNomCtrl.text.trim().isNotEmpty) 'contact_urgence_nom': _contactUrgenceNomCtrl.text.trim(),
        if (_contactUrgenceTelCtrl.text.trim().isNotEmpty) 'contact_urgence_telephone': _contactUrgenceTelCtrl.text.trim(),
      };
      if (!_estEdition) champs['matricule'] = _matriculeCtrl.text.trim();

      final dio = ApiClient.instance.dio;
      Map<String, dynamic> resultat;
      if (_estEdition) {
        final id = widget.etudiant!['id'];
        if (_photo != null) {
          final form = FormData.fromMap({...champs, 'photo': MultipartFile.fromBytes(await _photo!.readAsBytes(), filename: _photo!.name)});
          final response = await dio.patch('/etudiants/$id/', data: form);
          resultat = response.data as Map<String, dynamic>;
        } else {
          final response = await dio.patch('/etudiants/$id/', data: champs);
          resultat = response.data as Map<String, dynamic>;
        }
      } else {
        if (_photo != null) {
          final form = FormData.fromMap({...champs, 'photo': MultipartFile.fromBytes(await _photo!.readAsBytes(), filename: _photo!.name)});
          final response = await dio.post('/etudiants/', data: form);
          resultat = response.data as Map<String, dynamic>;
        } else {
          final response = await dio.post('/etudiants/', data: champs);
          resultat = response.data as Map<String, dynamic>;
        }
        if (_classeId != null && widget.anneeScolaireId != null) {
          await dio.post('/inscriptions/', data: {
            'etudiant': resultat['id'],
            'classe': _classeId,
            'annee_scolaire': widget.anneeScolaireId,
          });
        }
      }

      ref.invalidate(adminEtudiantsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_estEdition ? 'Étudiant mis à jour.' : "Étudiant inscrit. Mot de passe temporaire : 12345678"),
        ));
      }
    } on DioException catch (err) {
      final data = err.response?.data;
      final message = data is Map ? data.values.expand((v) => v is List ? v : [v]).join(' ') : "Erreur lors de l'enregistrement.";
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de l'enregistrement.")));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(adminClassesProvider);

    return AlertDialog(
      title: Text(_estEdition ? 'Modifier — ${widget.etudiant!['prenom']} ${widget.etudiant!['nom']}' : 'Nouvel étudiant'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _choisirPhoto,
                    child: Stack(
                      children: [
                        _photo != null
                            ? FutureBuilder<Uint8List>(
                                future: _photo!.readAsBytes(),
                                builder: (context, snapshot) => CircleAvatar(
                                  radius: 36,
                                  backgroundImage: snapshot.hasData ? MemoryImage(snapshot.data!) : null,
                                ),
                              )
                            : UserAvatar(photoUrl: widget.etudiant?['photo'] as String?, initials: _prenomCtrl.text.isNotEmpty ? _prenomCtrl.text[0] : '?', radius: 36),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                            child: Icon(Icons.camera_alt_rounded, size: 14, color: Theme.of(context).colorScheme.onPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!_estEdition) ...[
                  TextFormField(
                    controller: _matriculeCtrl,
                    decoration: const InputDecoration(labelText: 'Matricule *', hintText: 'ex: 2026-LBL-0001'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                ],
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _genre,
                        decoration: const InputDecoration(labelText: 'Genre'),
                        items: const [
                          DropdownMenuItem(value: 'H', child: Text('Homme')),
                          DropdownMenuItem(value: 'F', child: Text('Femme')),
                          DropdownMenuItem(value: 'A', child: Text('Autre')),
                        ],
                        onChanged: (v) => setState(() => _genre = v ?? 'H'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _choisirDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Naissance *'),
                          child: Text(_dateNaissance != null ? DateFormat('dd/MM/yyyy').format(_dateNaissance!) : '—'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lieuNaissanceCtrl,
                  decoration: const InputDecoration(labelText: 'Lieu de naissance *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _adresseCtrl, decoration: const InputDecoration(labelText: 'Adresse')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _telephoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone'), keyboardType: TextInputType.phone)),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _contactUrgenceNomCtrl, decoration: const InputDecoration(labelText: "Contact d'urgence"))),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: _contactUrgenceTelCtrl, decoration: const InputDecoration(labelText: 'Téléphone urgence'), keyboardType: TextInputType.phone)),
                  ],
                ),
                if (!_estEdition) ...[
                  const SizedBox(height: 12),
                  classesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (classes) => DropdownButtonFormField<int>(
                      initialValue: _classeId,
                      decoration: const InputDecoration(labelText: 'Classe (optionnel)'),
                      items: classes.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom']?.toString() ?? ''))).toList(),
                      onChanged: (v) => setState(() => _classeId = v),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _enCours ? null : () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: _enCours ? null : _enregistrer,
          child: _enCours ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
