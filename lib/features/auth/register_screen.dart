import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';

enum _Mode { join, create }

/// Miroir de `Register.jsx` (frontend/src/pages/Register.jsx) : deux modes — auto-inscription
/// élève/parent (compte en attente de validation) et création d'un nouvel établissement
/// (avec son compte administrateur).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  _Mode _mode = _Mode.join;
  String? _error;
  String? _success;
  bool _loading = false;

  void _setMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _success = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF312E81), Color(0xFF0F172A), Color(0xFF581C87)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    Card(
                      color: const Color(0xE60B0F1A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B))),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E293B))),
                              child: Row(
                                children: [
                                  Expanded(child: _modeButton('Élève / Parent', Icons.school_outlined, _Mode.join)),
                                  Expanded(child: _modeButton('Établissement', Icons.apartment_outlined, _Mode.create)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text('Création de compte', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            const Text(
                              'Remplissez les champs ci-dessous pour vous inscrire',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                            ),
                            const SizedBox(height: 20),
                            if (_success != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))),
                                child: Text(_success!, style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 12.5)),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (_error != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (_mode == _Mode.join)
                              _JoinForm(
                                loading: _loading,
                                onSubmitting: (v) => setState(() => _loading = v),
                                onError: (m) => setState(() {
                                  _error = m;
                                  _success = null;
                                }),
                                onSuccess: (m) => setState(() {
                                  _success = m;
                                  _error = null;
                                }),
                              )
                            else
                              _CreateEcoleForm(
                                loading: _loading,
                                onSubmitting: (v) => setState(() => _loading = v),
                                onError: (m) => setState(() {
                                  _error = m;
                                  _success = null;
                                }),
                                onSuccess: (m) => setState(() {
                                  _success = m;
                                  _error = null;
                                }),
                              ),
                            const SizedBox(height: 8),
                            const Divider(color: Color(0xFF1E293B)),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: () => context.go('/login'),
                                child: RichText(
                                  text: const TextSpan(
                                    style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                    children: [
                                      TextSpan(text: 'Déjà un compte ? '),
                                      TextSpan(text: 'Se connecter', style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('© ${DateTime.now().year} SIG-Lycée • Tous droits réservés', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton(String label, IconData icon, _Mode mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => _setMode(mode),
      child: Container(
        height: 40,
        decoration: BoxDecoration(color: selected ? const Color(0xFF4F46E5) : Colors.transparent, borderRadius: BorderRadius.circular(9)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

/// Petit champ texte au thème sombre, cohérent avec `LoginScreen`.
Widget darkField({
  required TextEditingController controller,
  required String label,
  IconData? icon,
  String? hint,
  bool obscure = false,
  bool required = true,
  TextInputType? keyboardType,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label${required ? ' *' : ''}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Ce champ est requis' : null : null,
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF94A3B8), size: 18) : null,
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
        ),
      ),
    ],
  );
}

Widget darkDropdown<T>({
  required String label,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
  String? hint,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label *', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        dropdownColor: const Color(0xFF0F172A),
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        hint: hint != null ? Text(hint, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)) : null,
        validator: (v) => v == null ? 'Ce champ est requis' : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E293B))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
        ),
      ),
    ],
  );
}

/// Sélecteur de date au même thème sombre que [darkField] — `showDatePicker` n'a pas
/// d'équivalent "champ texte" natif, contrairement à un `TextFormField`.
Widget darkDateField({required String label, required DateTime? value, required VoidCallback onTap, bool required = true}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label${required ? ' *' : ''}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E293B))),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: Color(0xFF94A3B8), size: 16),
              const SizedBox(width: 10),
              Text(
                value != null ? DateFormat('dd/MM/yyyy').format(value) : 'jj/mm/aaaa',
                style: TextStyle(color: value != null ? Colors.white : const Color(0xFF64748B), fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _JoinForm extends StatefulWidget {
  final bool loading;
  final ValueChanged<bool> onSubmitting;
  final ValueChanged<String> onError;
  final ValueChanged<String> onSuccess;

  const _JoinForm({required this.loading, required this.onSubmitting, required this.onError, required this.onSuccess});

  @override
  State<_JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends State<_JoinForm> {
  final _formKey = GlobalKey<FormState>();
  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _matriculeEnfantCtrl = TextEditingController();
  // Dossier étudiant (rôle Élève uniquement) — miroir de « Inscription nouvel étudiant »
  // (frontend/src/components/etudiants/EtudiantsPanel.jsx), pour que l'administration n'ait
  // pas à ressaisir ces informations à l'activation du compte. Le matricule et la classe ne
  // sont volontairement pas demandés ici : le matricule est généré côté serveur, et affecter
  // une classe reste une décision de l'établissement à l'activation.
  final _lieuNaissanceCtrl = TextEditingController();
  final _nationaliteCtrl = TextEditingController(text: 'Malagasy');
  final _adresseCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();
  final _situationFamilialeCtrl = TextEditingController();
  final _ancienEtablissementCtrl = TextEditingController();
  final _dossierMedicalCtrl = TextEditingController();
  final _contactUrgenceNomCtrl = TextEditingController();
  final _contactUrgenceTelCtrl = TextEditingController();
  DateTime? _dateNaissance;
  XFile? _photo;
  String _role = 'ETUDIANT';
  String _genre = 'H';
  int? _ecoleId;
  List<Map<String, dynamic>> _ecoles = [];
  bool _ecolesEnCours = true;

  @override
  void initState() {
    super.initState();
    _chargerEcoles();
  }

  Future<void> _chargerEcoles() async {
    try {
      final response = await ApiClient.instance.dio.get('/ecoles/publiques/');
      if (!mounted) return;
      setState(() {
        _ecoles = (response.data as List).cast<Map<String, dynamic>>();
        _ecolesEnCours = false;
      });
    } catch (_) {
      if (mounted) setState(() => _ecolesEnCours = false);
    }
  }

  Future<void> _choisirDateNaissance() async {
    final maintenant = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: DateTime(maintenant.year - 15),
      firstDate: DateTime(1950),
      lastDate: maintenant,
    );
    if (choisie != null) setState(() => _dateNaissance = choisie);
  }

  Future<void> _choisirPhoto() async {
    final fichier = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (fichier != null) setState(() => _photo = fichier);
  }

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _matriculeEnfantCtrl.dispose();
    _lieuNaissanceCtrl.dispose();
    _nationaliteCtrl.dispose();
    _adresseCtrl.dispose();
    _telephoneCtrl.dispose();
    _situationFamilialeCtrl.dispose();
    _ancienEtablissementCtrl.dispose();
    _dossierMedicalCtrl.dispose();
    _contactUrgenceNomCtrl.dispose();
    _contactUrgenceTelCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == 'PARENT' && _matriculeEnfantCtrl.text.trim().isEmpty) {
      widget.onError("Veuillez fournir le matricule de votre enfant.");
      return;
    }
    if (_role == 'ETUDIANT' && _dateNaissance == null) {
      widget.onError('La date de naissance est requise.');
      return;
    }
    if (_role == 'ETUDIANT' && _lieuNaissanceCtrl.text.trim().isEmpty) {
      widget.onError('Le lieu de naissance est requis.');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      widget.onError('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }
    widget.onSubmitting(true);
    try {
      await AuthService().register({
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'first_name': _prenomCtrl.text.trim(),
        'last_name': _nomCtrl.text.trim(),
        'role': _role,
        'genre': _genre,
        'ecole': _ecoleId,
        if (_matriculeEnfantCtrl.text.trim().isNotEmpty) 'matricule_enfant': _matriculeEnfantCtrl.text.trim(),
        if (_role == 'ETUDIANT') ...{
          'date_naissance': DateFormat('yyyy-MM-dd').format(_dateNaissance!),
          'lieu_naissance': _lieuNaissanceCtrl.text.trim(),
          if (_nationaliteCtrl.text.trim().isNotEmpty) 'nationalite': _nationaliteCtrl.text.trim(),
          if (_adresseCtrl.text.trim().isNotEmpty) 'adresse': _adresseCtrl.text.trim(),
          if (_telephoneCtrl.text.trim().isNotEmpty) 'telephone': _telephoneCtrl.text.trim(),
          if (_situationFamilialeCtrl.text.trim().isNotEmpty) 'situation_familiale': _situationFamilialeCtrl.text.trim(),
          if (_ancienEtablissementCtrl.text.trim().isNotEmpty) 'ancien_etablissement': _ancienEtablissementCtrl.text.trim(),
          if (_dossierMedicalCtrl.text.trim().isNotEmpty) 'dossier_medical': _dossierMedicalCtrl.text.trim(),
          if (_contactUrgenceNomCtrl.text.trim().isNotEmpty) 'contact_urgence_nom': _contactUrgenceNomCtrl.text.trim(),
          if (_contactUrgenceTelCtrl.text.trim().isNotEmpty) 'contact_urgence_telephone': _contactUrgenceTelCtrl.text.trim(),
        },
      }, photo: _role == 'ETUDIANT' ? _photo : null);
      widget.onSuccess("Inscription réussie ! Votre compte doit être activé par l'administration de l'établissement avant de pouvoir vous connecter.");
      if (mounted) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) context.go('/login');
        });
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String message = "Erreur lors de l'inscription";
      if (data is Map) {
        message = _premierMessage(data, ['email', 'password', 'role', 'ecole']) ?? message;
      }
      widget.onError(message);
    } catch (_) {
      widget.onError('Impossible de contacter le serveur.');
    } finally {
      widget.onSubmitting(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: darkField(controller: _prenomCtrl, label: 'Prénom', icon: Icons.person_outline, hint: 'Votre prénom')),
              const SizedBox(width: 10),
              Expanded(child: darkField(controller: _nomCtrl, label: 'Nom', icon: Icons.person_outline, hint: 'Votre nom')),
            ],
          ),
          const SizedBox(height: 14),
          darkField(controller: _emailCtrl, label: 'Email', icon: Icons.mail_outline, hint: 'exemple@lycee.mg', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          darkField(controller: _passwordCtrl, label: 'Mot de passe', icon: Icons.lock_outline, hint: 'Au moins 6 caractères', obscure: true),
          const SizedBox(height: 14),
          _ecolesEnCours
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: CircularProgressIndicator()))
              : darkDropdown<int>(
                  label: 'Établissement',
                  value: _ecoleId,
                  hint: 'Sélectionnez votre établissement',
                  items: _ecoles.map((e) => DropdownMenuItem(value: e['id'] as int, child: Text(e['nom']?.toString() ?? ''))).toList(),
                  onChanged: (v) => setState(() => _ecoleId = v),
                ),
          const SizedBox(height: 14),
          darkDropdown<String>(
            label: 'Vous êtes',
            value: _role,
            items: const [
              DropdownMenuItem(value: 'ETUDIANT', child: Text('Élève')),
              DropdownMenuItem(value: 'PARENT', child: Text('Parent')),
            ],
            onChanged: (v) => setState(() => _role = v ?? 'ETUDIANT'),
          ),
          const SizedBox(height: 4),
          const Text(
            "Les comptes du personnel (enseignant, administration...) sont créés par l'établissement.",
            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
          if (_role == 'PARENT') ...[
            const SizedBox(height: 14),
            darkField(controller: _matriculeEnfantCtrl, label: "Matricule de l'enfant", hint: 'Ex: 2023-INF-0001'),
          ],
          const SizedBox(height: 14),
          darkDropdown<String>(
            label: 'Genre',
            value: _genre,
            items: const [
              DropdownMenuItem(value: 'H', child: Text('Masculin')),
              DropdownMenuItem(value: 'F', child: Text('Féminin')),
              DropdownMenuItem(value: 'A', child: Text('Autre / Non précisé')),
            ],
            onChanged: (v) => setState(() => _genre = v ?? 'H'),
          ),
          if (_role == 'ETUDIANT') ...[
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF1E293B)),
            const SizedBox(height: 12),
            const Text('DOSSIER ÉLÈVE', style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                onTap: _choisirPhoto,
                child: Stack(
                  children: [
                    _photo != null
                        ? FutureBuilder<Uint8List>(
                            future: _photo!.readAsBytes(),
                            builder: (context, snapshot) => CircleAvatar(
                              radius: 32,
                              backgroundColor: const Color(0xFF0F172A),
                              backgroundImage: snapshot.hasData ? MemoryImage(snapshot.data!) : null,
                            ),
                          )
                        : const CircleAvatar(radius: 32, backgroundColor: Color(0xFF0F172A), child: Icon(Icons.person_outline, color: Color(0xFF64748B), size: 28)),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: darkDateField(label: 'Date de naissance', value: _dateNaissance, onTap: _choisirDateNaissance)),
                const SizedBox(width: 10),
                Expanded(child: darkField(controller: _lieuNaissanceCtrl, label: 'Lieu de naissance', hint: 'Antananarivo')),
              ],
            ),
            const SizedBox(height: 14),
            darkField(controller: _nationaliteCtrl, label: 'Nationalité', required: false),
            const SizedBox(height: 14),
            darkField(controller: _adresseCtrl, label: 'Adresse', required: false),
            const SizedBox(height: 14),
            darkField(controller: _telephoneCtrl, label: 'Téléphone', required: false, keyboardType: TextInputType.phone),
            const SizedBox(height: 14),
            darkField(controller: _situationFamilialeCtrl, label: 'Situation familiale', required: false, hint: 'Ex: Vit avec ses parents'),
            const SizedBox(height: 14),
            darkField(controller: _ancienEtablissementCtrl, label: 'Ancien établissement', required: false),
            const SizedBox(height: 14),
            darkField(controller: _dossierMedicalCtrl, label: 'Dossier médical', required: false, hint: 'Allergies, traitements en cours...'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: darkField(controller: _contactUrgenceNomCtrl, label: "Contact d'urgence", required: false)),
                const SizedBox(width: 10),
                Expanded(child: darkField(controller: _contactUrgenceTelCtrl, label: 'Téléphone urgence', required: false, keyboardType: TextInputType.phone)),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.loading ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: widget.loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Créer mon compte', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateEcoleForm extends StatefulWidget {
  final bool loading;
  final ValueChanged<bool> onSubmitting;
  final ValueChanged<String> onError;
  final ValueChanged<String> onSuccess;

  const _CreateEcoleForm({required this.loading, required this.onSubmitting, required this.onError, required this.onSuccess});

  @override
  State<_CreateEcoleForm> createState() => _CreateEcoleFormState();
}

class _CreateEcoleFormState extends State<_CreateEcoleForm> {
  final _formKey = GlobalKey<FormState>();
  final _ecoleNomCtrl = TextEditingController();
  final _ecoleCodeCtrl = TextEditingController();
  final _ecoleAdresseCtrl = TextEditingController();
  final _ecoleTelephoneCtrl = TextEditingController();
  final _ecoleEmailCtrl = TextEditingController();
  final _adminPrenomCtrl = TextEditingController();
  final _adminNomCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();
  final _adminTelephoneCtrl = TextEditingController();

  @override
  void dispose() {
    _ecoleNomCtrl.dispose();
    _ecoleCodeCtrl.dispose();
    _ecoleAdresseCtrl.dispose();
    _ecoleTelephoneCtrl.dispose();
    _ecoleEmailCtrl.dispose();
    _adminPrenomCtrl.dispose();
    _adminNomCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPasswordCtrl.dispose();
    _adminTelephoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_adminPasswordCtrl.text.length < 6) {
      widget.onError('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }
    widget.onSubmitting(true);
    try {
      await AuthService().registerEcole({
        'ecole_nom': _ecoleNomCtrl.text.trim(),
        'ecole_code': _ecoleCodeCtrl.text.trim(),
        'ecole_adresse': _ecoleAdresseCtrl.text.trim(),
        'ecole_telephone': _ecoleTelephoneCtrl.text.trim(),
        'ecole_email': _ecoleEmailCtrl.text.trim(),
        'admin_first_name': _adminPrenomCtrl.text.trim(),
        'admin_last_name': _adminNomCtrl.text.trim(),
        'admin_email': _adminEmailCtrl.text.trim(),
        'admin_password': _adminPasswordCtrl.text,
        'admin_telephone': _adminTelephoneCtrl.text.trim(),
      });
      widget.onSuccess('Établissement créé ! Vous pouvez vous connecter dès maintenant avec votre compte administrateur.');
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) context.go('/login');
        });
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String message = "Erreur lors de la création de l'établissement";
      if (data is Map) {
        message = _premierMessage(data, ['ecole_code', 'ecole_nom', 'admin_email', 'admin_password']) ?? message;
      }
      widget.onError(message);
    } catch (_) {
      widget.onError('Impossible de contacter le serveur.');
    } finally {
      widget.onSubmitting(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ÉTABLISSEMENT', style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: darkField(controller: _ecoleNomCtrl, label: "Nom de l'établissement", hint: 'Lycée Saint-Michel')),
              const SizedBox(width: 10),
              Expanded(child: darkField(controller: _ecoleCodeCtrl, label: 'Code établissement', hint: 'LYC-SM')),
            ],
          ),
          const SizedBox(height: 14),
          darkField(controller: _ecoleAdresseCtrl, label: 'Adresse', hint: "Adresse de l'établissement", required: false),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: darkField(controller: _ecoleTelephoneCtrl, label: 'Téléphone établissement', hint: '+261 34 00 000 00', required: false)),
              const SizedBox(width: 10),
              Expanded(child: darkField(controller: _ecoleEmailCtrl, label: 'Email établissement', hint: 'contact@etablissement.mg', required: false, keyboardType: TextInputType.emailAddress)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 12),
          const Text('VOTRE COMPTE ADMINISTRATEUR', style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: darkField(controller: _adminPrenomCtrl, label: 'Prénom', hint: 'Votre prénom')),
              const SizedBox(width: 10),
              Expanded(child: darkField(controller: _adminNomCtrl, label: 'Nom', hint: 'Votre nom')),
            ],
          ),
          const SizedBox(height: 14),
          darkField(controller: _adminEmailCtrl, label: 'Email', icon: Icons.mail_outline, hint: 'admin@etablissement.mg', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          darkField(controller: _adminPasswordCtrl, label: 'Mot de passe', icon: Icons.lock_outline, hint: 'Au moins 6 caractères', obscure: true),
          const SizedBox(height: 14),
          darkField(controller: _adminTelephoneCtrl, label: 'Téléphone', hint: '+261 34 00 000 00', required: false),
          const SizedBox(height: 12),
          const Text(
            'Vous serez administrateur de cet établissement avec un accès complet. Vous pourrez ensuite créer les comptes du personnel depuis votre tableau de bord.',
            style: TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.loading ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: widget.loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Créer mon établissement', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

String? _premierMessage(Map data, List<String> champs) {
  for (final champ in champs) {
    final valeur = data[champ];
    if (valeur is List && valeur.isNotEmpty) return valeur.first.toString();
    if (valeur is String) return valeur;
  }
  final nonField = data['non_field_errors'];
  if (nonField is List && nonField.isNotEmpty) return nonField.first.toString();
  if (data['detail'] != null) return data['detail'].toString();
  return null;
}
