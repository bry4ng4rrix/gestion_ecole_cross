import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/error_message.dart';
import '../../../core/api/file_download.dart';
import '../../../core/api/resource_service.dart';
import '../admin_providers.dart';

const _typeDocumentLabels = {
  'ACTE_NAISSANCE': 'Acte de naissance',
  'CIN': "CIN de l'étudiant",
  'CIN_PARENT': "CIN d'un parent/tuteur",
  'CERTIFICAT_MEDICAL': 'Certificat médical',
  'PHOTO_IDENTITE': "Photo d'identité",
  'BULLETIN_ANTERIEUR': 'Bulletin établissement antérieur',
  'AUTRE': 'Autre',
};

/// Miroir de `DossierEtudiantDialog` (frontend/src/components/etudiants/EtudiantsPanel.jsx) :
/// QR code / code-barres, génération de la carte d'étudiant et du certificat de scolarité,
/// historique scolaire (toutes les inscriptions) et gestion des documents justificatifs.
Future<void> ouvrirDossierEtudiant(BuildContext context, Map<String, dynamic> etudiant) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => _DossierContent(etudiant: etudiant, scrollController: scrollController),
    ),
  );
}

class _DossierContent extends ConsumerStatefulWidget {
  final Map<String, dynamic> etudiant;
  final ScrollController scrollController;
  const _DossierContent({required this.etudiant, required this.scrollController});

  @override
  ConsumerState<_DossierContent> createState() => _DossierContentState();
}

class _DossierContentState extends ConsumerState<_DossierContent> {
  Uint8List? _qrBytes;
  Uint8List? _barcodeBytes;
  String _typeDoc = 'ACTE_NAISSANCE';
  PlatformFile? _fichier;
  String? _actionEnCours;

  int get _etudiantId => widget.etudiant['id'] as int;

  Future<void> _executer(String cle, Future<void> Function() action, {String repli = 'Une erreur est survenue.'}) async {
    setState(() => _actionEnCours = cle);
    try {
      await action();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e, repli))));
    } finally {
      if (mounted) setState(() => _actionEnCours = null);
    }
  }

  Future<void> _voirQrCode() => _executer('qr', () async {
        final response = await ApiClient.instance.dio.get<List<int>>('/etudiants/$_etudiantId/qrcode/', options: Options(responseType: ResponseType.bytes));
        setState(() => _qrBytes = Uint8List.fromList(response.data!));
      });

  Future<void> _voirCodeBarre() => _executer('barcode', () async {
        final response = await ApiClient.instance.dio.get<List<int>>('/etudiants/$_etudiantId/codebarre/', options: Options(responseType: ResponseType.bytes));
        setState(() => _barcodeBytes = Uint8List.fromList(response.data!));
      });

  Future<void> _genererCarte() => _executer(
        'carte',
        () async {
          await downloadAndOpen('/etudiants/$_etudiantId/carte/', 'carte_${widget.etudiant['matricule']}.pdf');
        },
        repli: 'Erreur lors de la génération de la carte.',
      );

  Future<void> _genererCertificat() => _executer(
        'certificat',
        () async {
          await downloadAndOpenPost('/etudiants/$_etudiantId/certificat-scolarite/', 'certificat_scolarite_${widget.etudiant['matricule']}.pdf');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Certificat de scolarité généré.')));
        },
        repli: 'Erreur lors de la génération du certificat.',
      );

  Future<void> _choisirFichier() async {
    final resultat = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    if (resultat.isNotEmpty) setState(() => _fichier = resultat.first);
  }

  Future<void> _ajouterDocument() => _executer(
        'upload',
        () async {
          if (_fichier == null) return;
          final form = FormData.fromMap({
            'etudiant': _etudiantId,
            'type_document': _typeDoc,
            'fichier': MultipartFile.fromBytes(await _fichier!.readAsBytes(), filename: _fichier!.name),
          });
          await ApiClient.instance.dio.post('/documents-etudiants/', data: form);
          ref.invalidate(documentsDeLetudiantProvider);
          setState(() => _fichier = null);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document ajouté.')));
        },
        repli: "Erreur lors de l'ajout du document.",
      );

  Future<void> _supprimerDocument(int id) => _executer('doc-$id', () async {
        await ResourceService('/documents-etudiants').remove(id);
        ref.invalidate(documentsDeLetudiantProvider);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document supprimé.')));
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inscriptionsAsync = ref.watch(toutesInscriptionsDeLetudiantProvider(_etudiantId));
    final documentsAsync = ref.watch(documentsDeLetudiantProvider(_etudiantId));

    return SafeArea(
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Text('Dossier — ${widget.etudiant['prenom']} ${widget.etudiant['nom']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _actionEnCours == 'qr' ? null : _voirQrCode,
                icon: const Icon(Icons.qr_code_rounded, size: 18),
                label: const Text('QR Code'),
              ),
              OutlinedButton.icon(
                onPressed: _actionEnCours == 'barcode' ? null : _voirCodeBarre,
                icon: const Icon(Icons.barcode_reader, size: 18),
                label: const Text('Code-barres'),
              ),
              FilledButton.icon(
                onPressed: _actionEnCours == 'carte' ? null : _genererCarte,
                icon: _actionEnCours == 'carte' ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.badge_rounded, size: 18),
                label: const Text("Générer la carte d'étudiant"),
              ),
              FilledButton.icon(
                onPressed: _actionEnCours == 'certificat' ? null : _genererCertificat,
                icon: _actionEnCours == 'certificat' ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.fact_check_rounded, size: 18),
                label: const Text('Générer un certificat de scolarité'),
              ),
            ],
          ),
          if (_qrBytes != null) ...[
            const SizedBox(height: 16),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_qrBytes!, width: 128, height: 128)),
          ],
          if (_barcodeBytes != null) ...[
            const SizedBox(height: 16),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_barcodeBytes!)),
          ],
          const SizedBox(height: 24),
          Text('Historique scolaire', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          inscriptionsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
            error: (e, _) => const Text('Historique indisponible.'),
            data: (inscriptions) {
              if (inscriptions.isEmpty) return const Text('Aucune inscription enregistrée.', style: TextStyle(fontSize: 13));
              return Column(
                children: inscriptions.map((i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(i['classe_nom']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${i['statut'] ?? ''} — ${i['date_inscription'] ?? ''}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Documents', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _typeDoc,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  items: _typeDocumentLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _typeDoc = v ?? 'ACTE_NAISSANCE'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _choisirFichier, icon: const Icon(Icons.attach_file_rounded), tooltip: 'Choisir un fichier'),
              IconButton(
                onPressed: (_fichier == null || _actionEnCours == 'upload') ? null : _ajouterDocument,
                icon: _actionEnCours == 'upload' ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_rounded),
                tooltip: 'Ajouter',
              ),
            ],
          ),
          if (_fichier != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_fichier!.name, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
          const SizedBox(height: 10),
          documentsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
            error: (e, _) => const Text('Documents indisponibles.'),
            data: (documents) {
              if (documents.isEmpty) return const Text('Aucun document.', style: TextStyle(fontSize: 13));
              return Column(
                children: documents.map((d) {
                  final busy = _actionEnCours == 'doc-${d['id']}';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Expanded(child: Text(_typeDocumentLabels[d['type_document']] ?? d['type_document']?.toString() ?? '')),
                        IconButton(
                          onPressed: busy ? null : () => _supprimerDocument(d['id'] as int),
                          icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.close_rounded, size: 18, color: scheme.error),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
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
  }
}
