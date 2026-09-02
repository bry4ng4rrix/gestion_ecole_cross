import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/api/error_message.dart';
import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';

/// Écran de contrôle de sortie du gardien : scanne le QR code présenté par le parent, affiche
/// une fiche de vérification (photo/nom/classe/parent) sans rien enregistrer, puis n'enregistre
/// la sortie qu'à la confirmation explicite du gardien. Miroir du flux caméra → aperçu →
/// confirmation → succès de `dossier_etudiant_sheet.dart` (état local + try/catch/finally),
/// adapté à un enchaînement d'écrans plutôt qu'à de simples actions ponctuelles.
class GardienScannerScreen extends ConsumerStatefulWidget {
  const GardienScannerScreen({super.key});

  @override
  ConsumerState<GardienScannerScreen> createState() => _GardienScannerScreenState();
}

class _GardienScannerScreenState extends ConsumerState<GardienScannerScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  Timer? _retourTimer;

  bool _verificationEnCours = false;
  bool _confirmationEnCours = false;
  String? _tokenScanne;
  Map<String, dynamic>? _etudiant;
  Map<String, dynamic>? _sortieConfirmee;
  String? _messageErreur;
  bool _dejaSorti = false;

  bool get _enPause => _etudiant != null || _sortieConfirmee != null || _messageErreur != null;

  @override
  void dispose() {
    _retourTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_verificationEnCours || _enPause || capture.barcodes.isEmpty) return;
    final token = capture.barcodes.first.rawValue;
    if (token == null || token.isEmpty) return;

    setState(() => _verificationEnCours = true);
    await _controller.stop();
    try {
      final data = await ResourceService('/sorties-etudiants').action(null, 'scan-qr', payload: {'token': token});
      if (!mounted) return;
      setState(() {
        _tokenScanne = token;
        _etudiant = (data as Map<String, dynamic>)['etudiant'] as Map<String, dynamic>;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final erreur = _analyserErreur(e, repli: 'QR code invalide ou élève introuvable.');
      setState(() {
        _dejaSorti = erreur.dejaSorti;
        _messageErreur = erreur.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dejaSorti = false;
        _messageErreur = 'Erreur inattendue lors de la vérification du QR code.';
      });
    } finally {
      if (mounted) setState(() => _verificationEnCours = false);
    }
  }

  Future<void> _confirmerSortie() async {
    final token = _tokenScanne;
    if (token == null) return;
    setState(() => _confirmationEnCours = true);
    try {
      final data = await ResourceService('/sorties-etudiants').action(null, 'confirmer', payload: {'token': token});
      if (!mounted) return;
      setState(() {
        _etudiant = null;
        _sortieConfirmee = data as Map<String, dynamic>;
      });
      _retourTimer?.cancel();
      _retourTimer = Timer(const Duration(seconds: 4), _reprendreScan);
    } on DioException catch (e) {
      if (!mounted) return;
      final erreur = _analyserErreur(e, repli: 'Erreur lors de la confirmation de la sortie.');
      setState(() {
        _etudiant = null;
        _dejaSorti = erreur.dejaSorti;
        _messageErreur = erreur.message;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e, 'Erreur lors de la confirmation de la sortie.'))));
    } finally {
      if (mounted) setState(() => _confirmationEnCours = false);
    }
  }

  ({bool dejaSorti, String message}) _analyserErreur(DioException e, {required String repli}) {
    final statut = e.response?.statusCode;
    if (statut == 409) {
      return (dejaSorti: true, message: messageErreur(e, 'Cet élève a déjà été enregistré comme sorti aujourd\'hui.'));
    }
    return (dejaSorti: false, message: messageErreur(e, repli));
  }

  Future<void> _reprendreScan() async {
    _retourTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _etudiant = null;
      _sortieConfirmee = null;
      _messageErreur = null;
      _dejaSorti = false;
      _tokenScanne = null;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _erreurCamera(context, error),
          ),
          if (!_enPause && !_verificationEnCours) _viseur(context),
          if (_verificationEnCours) _chargement(context),
          if (_etudiant != null) _ficheEleve(context),
          if (_sortieConfirmee != null) _ecranSucces(context),
          if (_messageErreur != null) _ecranErreur(context),
        ],
      ),
    );
  }

  Widget _viseur(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
            child: const Text('Présentez le QR code de sortie à la caméra', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _scrim(Widget enfant) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: enfant),
    );
  }

  Widget _chargement(BuildContext context) {
    return _scrim(
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Vérification du QR code...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ficheEleve(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = _etudiant!;
    final parent = e['parent'] as Map<String, dynamic>?;
    return _scrim(
      Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(photoUrl: e['photo'] as String?, initials: _initiales(e['prenom'] as String?, e['nom'] as String?), radius: 44),
              const SizedBox(height: 14),
              Text('${e['prenom'] ?? ''} ${e['nom'] ?? ''}'.trim(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(e['matricule']?.toString() ?? '', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
              const SizedBox(height: 12),
              _ligneInfo(context, Icons.class_outlined, e['classe']?.toString() ?? 'Classe non renseignée'),
              const SizedBox(height: 6),
              _ligneInfo(context, Icons.family_restroom_rounded, parent != null ? 'Parent : ${parent['nom']}' : 'Aucun parent rattaché'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _confirmationEnCours ? null : _reprendreScan, child: const Text('Annuler'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _confirmationEnCours ? null : _confirmerSortie,
                      icon: _confirmationEnCours
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded),
                      label: const Text('Confirmer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ecranSucces(BuildContext context) {
    final s = _sortieConfirmee!;
    final date = DateTime.tryParse(s['date_sortie']?.toString() ?? '');
    final heure = date != null ? DateFormat('HH:mm').format(date.toLocal()) : '';
    return _scrim(
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
              const SizedBox(height: 14),
              const Text('Sortie enregistrée', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 6),
              Text('${s['etudiant_nom'] ?? ''}${heure.isNotEmpty ? ' à $heure' : ''}', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _reprendreScan, child: const Text('Scanner un autre élève'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ecranErreur(BuildContext context) {
    final avertissement = _dejaSorti;
    return _scrim(
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(avertissement ? Icons.warning_amber_rounded : Icons.cancel_rounded, color: avertissement ? Colors.orange : Colors.red, size: 56),
              const SizedBox(height: 14),
              Text(avertissement ? 'Élève déjà sorti' : 'QR code invalide', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 8),
              Text(_messageErreur ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _reprendreScan, child: const Text('Scanner à nouveau'))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _erreurCamera(BuildContext context, MobileScannerException error) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          const Text('Caméra indisponible', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            "Vérifiez que la permission caméra est accordée à l'application.",
            style: TextStyle(color: Colors.white70, fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _ligneInfo(BuildContext context, IconData icon, String texte) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(child: Text(texte, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13))),
      ],
    );
  }

  String _initiales(String? prenom, String? nom) {
    final p = (prenom ?? '').isNotEmpty ? prenom![0] : '';
    final n = (nom ?? '').isNotEmpty ? nom![0] : '';
    final r = '$p$n'.toUpperCase();
    return r.isEmpty ? '?' : r;
  }
}
