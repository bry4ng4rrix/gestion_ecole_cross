import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_service.dart';
import '../../core/widgets/common.dart';

/// Miroir de `MonProfilPanel` (frontend/src/components/parametres/MonProfilPanel.jsx) —
/// partagé par les 4 rôles (mêmes champs, même endpoint `PATCH /auth/profile/`), accessible
/// depuis la feuille de profil de `RoleShell`.
class MonProfilScreen extends ConsumerStatefulWidget {
  const MonProfilScreen({super.key});

  @override
  ConsumerState<MonProfilScreen> createState() => _MonProfilScreenState();
}

class _MonProfilScreenState extends ConsumerState<MonProfilScreen> {
  final _service = AuthService();
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _nomCtrl;
  late final TextEditingController _telephoneCtrl;
  XFile? _nouvellePhoto;
  bool _enregistrementEnCours = false;

  final _ancienCtrl = TextEditingController();
  final _nouveauCtrl = TextEditingController();
  bool _changementEnCours = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _prenomCtrl = TextEditingController(text: user?.firstName ?? '');
    _nomCtrl = TextEditingController(text: user?.lastName ?? '');
    _telephoneCtrl = TextEditingController(text: user?.telephone ?? '');
  }

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _telephoneCtrl.dispose();
    _ancienCtrl.dispose();
    _nouveauCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirPhoto() async {
    final fichier = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (fichier != null) setState(() => _nouvellePhoto = fichier);
  }

  Future<void> _enregistrer() async {
    setState(() => _enregistrementEnCours = true);
    try {
      final utilisateur = await _service.updateProfile({
        'first_name': _prenomCtrl.text.trim(),
        'last_name': _nomCtrl.text.trim(),
        'telephone': _telephoneCtrl.text.trim(),
      }, photo: _nouvellePhoto);
      ref.read(authProvider.notifier).setUser(utilisateur);
      setState(() => _nouvellePhoto = null);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Échec de la mise à jour du profil.')));
    } finally {
      if (mounted) setState(() => _enregistrementEnCours = false);
    }
  }

  Future<void> _changerMotDePasse() async {
    if (_ancienCtrl.text.isEmpty || _nouveauCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le nouveau mot de passe doit contenir au moins 8 caractères.')));
      return;
    }
    setState(() => _changementEnCours = true);
    try {
      await _service.changePassword(_ancienCtrl.text, _nouveauCtrl.text);
      _ancienCtrl.clear();
      _nouveauCtrl.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe modifié.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ancien mot de passe incorrect.')));
    } finally {
      if (mounted) setState(() => _changementEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon Profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _choisirPhoto,
                child: Stack(
                  children: [
                    _nouvellePhoto != null
                        ? FutureBuilder<Uint8List>(
                            future: _nouvellePhoto!.readAsBytes(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return CircleAvatar(radius: 44, backgroundColor: scheme.primaryContainer);
                              return CircleAvatar(radius: 44, backgroundImage: MemoryImage(snapshot.data!));
                            },
                          )
                        : UserAvatar(photoUrl: user?.photo, initials: user?.initials ?? '?', radius: 44),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle, border: Border.all(color: scheme.surface, width: 2)),
                        child: Icon(Icons.camera_alt_rounded, size: 16, color: scheme.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Informations personnelles', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    TextField(controller: _prenomCtrl, decoration: const InputDecoration(labelText: 'Prénom')),
                    const SizedBox(height: 12),
                    TextField(controller: _nomCtrl, decoration: const InputDecoration(labelText: 'Nom')),
                    const SizedBox(height: 12),
                    TextField(controller: _telephoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone'), keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(labelText: 'Email', hintText: user?.email),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _enregistrementEnCours ? null : _enregistrer,
                        child: _enregistrementEnCours
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Enregistrer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Changer le mot de passe', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    TextField(controller: _ancienCtrl, decoration: const InputDecoration(labelText: 'Ancien mot de passe'), obscureText: true),
                    const SizedBox(height: 12),
                    TextField(controller: _nouveauCtrl, decoration: const InputDecoration(labelText: 'Nouveau mot de passe (8 caractères min.)'), obscureText: true),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _changementEnCours ? null : _changerMotDePasse,
                        child: _changementEnCours
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Modifier le mot de passe'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
