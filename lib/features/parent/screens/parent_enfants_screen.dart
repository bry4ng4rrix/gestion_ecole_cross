import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/file_download.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/widgets/common.dart';
import '../parent_providers.dart';
import '../widgets/bulletins_enfant_sheet.dart';

/// Miroir de `ChildrenTab` (frontend/src/pages/ParentDashboard.jsx), enrichi du QR code de
/// sortie affiché directement dans la liste (au lieu d'un onglet séparé) et d'une carte
/// d'identité scolaire téléchargeable (photo + infos + QR).
class ParentEnfantsScreen extends ConsumerWidget {
  const ParentEnfantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enfantsAsync = ref.watch(mesEnfantsProvider);
    final trimestresAsync = ref.watch(parentTrimestresProvider);
    final anneesAsync = ref.watch(anneesScolairesProvider);

    return enfantsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Enfants indisponibles', onRetry: () => ref.invalidate(mesEnfantsProvider)),
      data: (enfants) => trimestresAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'Trimestres indisponibles'),
        data: (trimestres) {
          final actif = trimestres.where((t) => t['est_actif'] == true).toList();
          final trimestreActifId = actif.isNotEmpty ? actif.first['id'] as int : (trimestres.isNotEmpty ? trimestres.first['id'] as int : null);
          final annees = anneesAsync.asData?.value ?? const <Map<String, dynamic>>[];
          final anneeActive = annees.where((a) => a['est_active'] == true).toList();
          final libelleAnnee = _libelleAnnee(anneeActive.isNotEmpty ? anneeActive.first : (annees.isNotEmpty ? annees.first : null));

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mesEnfantsProvider),
            child: ListView(
              children: [
                const SectionHeader(title: 'Mes Enfants'),
                if (enfants.isEmpty) const EmptyView(message: 'Aucun enfant rattaché à votre compte.'),
                ...enfants.map((enfant) {
                  final moyenneAsync = trimestreActifId != null
                      ? ref.watch(moyenneEnfantProvider((etudiantId: enfant['id'] as int, trimestreId: trimestreActifId)))
                      : const AsyncValue<double?>.data(null);
                  return _EnfantCard(enfant: enfant, moyenneAsync: moyenneAsync, libelleAnnee: libelleAnnee);
                }),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  String _libelleAnnee(Map<String, dynamic>? annee) {
    if (annee == null) return '—';
    final l = annee['libelle'] ?? annee['nom'];
    if (l != null) return l.toString();
    final debut = DateTime.tryParse(annee['date_debut']?.toString() ?? '');
    if (debut == null) return '—';
    return '${debut.year}-${debut.year + 1}';
  }
}

class _EnfantCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> enfant;
  final AsyncValue<double?> moyenneAsync;
  final String libelleAnnee;

  const _EnfantCard({required this.enfant, required this.moyenneAsync, required this.libelleAnnee});

  @override
  ConsumerState<_EnfantCard> createState() => _EnfantCardState();
}

class _EnfantCardState extends ConsumerState<_EnfantCard> {
  final _carteKey = GlobalKey();
  bool _exportEnCours = false;

  Map<String, dynamic> get _enfant => widget.enfant;

  String get _nomComplet => '${_enfant['prenom']} ${_enfant['nom']}';

  String get _dateNaissanceFormatee {
    final d = DateTime.tryParse(_enfant['date_naissance']?.toString() ?? '');
    return d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);
  }

  String _initiales() {
    final p = _enfant['prenom'] as String? ?? '';
    final n = _enfant['nom'] as String? ?? '';
    final r = '${p.isNotEmpty ? p[0] : ''}${n.isNotEmpty ? n[0] : ''}'.toUpperCase();
    return r.isEmpty ? '?' : r;
  }

  Future<void> _telechargerCarte() async {
    setState(() => _exportEnCours = true);
    try {
      final boundary = _carteKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final matricule = _enfant['matricule'] ?? _enfant['id'];
      await enregistrerEtOuvrir(Uint8List.fromList(bytes), 'carte_identite_$matricule.png');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la génération de la carte.')));
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final id = _enfant['id'] as int;
    final parentNom = ref.watch(authProvider).user?.fullName ?? '—';
    final qrAsync = ref.watch(qrSortieBytesProvider(id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_nomComplet, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
                  child: Text(_enfant['classe_actuelle']?.toString() ?? '—', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
                ),
              ],
            ),
            Text('Matricule : ${_enfant['matricule'] ?? '—'}', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Moyenne',
                    value: widget.moyenneAsync.when(data: (m) => m != null ? '${m.toStringAsFixed(2)}/20' : '—', loading: () => '…', error: (e, _) => '—'),
                    icon: Icons.bar_chart_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: StatCard(title: 'Statut', value: _enfant['statut']?.toString() ?? '—', icon: Icons.verified_outlined)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ouvrirBulletinsEnfant(context, _enfant),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('Voir les bulletins'),
              ),
            ),
            const Divider(height: 28),
            Text('Carte d\'identité scolaire', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            RepaintBoundary(
              key: _carteKey,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserAvatar(photoUrl: _enfant['photo'] as String?, initials: _initiales(), radius: 32),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_nomComplet, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text('Né(e) le $_dateNaissanceFormatee', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                              Text('Classe : ${_enfant['classe_actuelle']?.toString() ?? '—'}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                              Text('Année scolaire : ${widget.libelleAnnee}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                              Text('Parent : $parentNom', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    qrAsync.when(
                      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator()),
                      error: (e, _) => const Text('QR code indisponible', style: TextStyle(fontSize: 12)),
                      data: (bytes) => Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
                        child: Image.memory(bytes, width: 140, height: 140),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exportEnCours ? null : _telechargerCarte,
                icon: _exportEnCours
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 18),
                label: const Text('Télécharger la carte'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
