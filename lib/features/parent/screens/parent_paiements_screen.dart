import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/file_download.dart';
import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../parent_providers.dart';

const _statutLabels = {'PAYE': 'Payé', 'PARTIEL': 'Partiel', 'IMPAYE': 'Impayé', 'NON_CONFIGURE': 'Non configuré'};
const _statutColors = {'PAYE': Colors.green, 'PARTIEL': Colors.orange, 'IMPAYE': Colors.red, 'NON_CONFIGURE': Colors.grey};

const _moisLabels = [
  '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

/// Marqueur distinguant un paiement "droit d'inscription/réinscription" d'un paiement
/// d'écolage mensuel ordinaire — même convention que côté admin (`paiements_etudiant_sheet.dart`).
const _marqueurInscription = "Droit d'inscription/réinscription";

final _dossierFinancierEnfantProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, ({int etudiantId, int anneeScolaireId})>((ref, args) async {
  final response = await ApiClient.instance.dio.get('/paiements/dossier/', queryParameters: {'etudiant': args.etudiantId, 'annee_scolaire': args.anneeScolaireId});
  return response.data as Map<String, dynamic>?;
});

/// Paiements d'écolage d'un enfant pour une année — lecture seule côté parent (pas d'action
/// de marquage, juste le statut mensuel et le téléchargement de facture sur les mois payés).
final _paiementsEnfantProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, ({int etudiantId, int anneeScolaireId})>((ref, args) {
  return ResourceService('/paiements').list({'etudiant': args.etudiantId, 'annee_scolaire': args.anneeScolaireId});
});

/// Miroir de `PaymentsTab` / `ChildDossierCard` (frontend/src/pages/ParentDashboard.jsx),
/// enrichi du calendrier mensuel janvier→décembre par enfant (statut payé/non payé) avec
/// téléchargement de facture sur les mois déjà payés.
class ParentPaiementsScreen extends ConsumerWidget {
  const ParentPaiementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enfantsAsync = ref.watch(mesEnfantsProvider);
    final anneesAsync = ref.watch(anneesScolairesProvider);

    return enfantsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Enfants indisponibles', onRetry: () => ref.invalidate(mesEnfantsProvider)),
      data: (enfants) => anneesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'Années scolaires indisponibles'),
        data: (annees) {
          final actives = annees.where((a) => a['est_active'] == true).toList();
          final anneeActive = actives.isNotEmpty ? actives.first : (annees.isNotEmpty ? annees.first : null);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mesEnfantsProvider),
            child: ListView(
              children: [
                const SectionHeader(title: 'Paiements'),
                if (enfants.isEmpty) const EmptyView(message: 'Aucun enfant rattaché à votre compte.'),
                if (enfants.isNotEmpty && anneeActive == null) const EmptyView(message: 'Aucune année scolaire active.'),
                ...enfants.map((enfant) => _EnfantPaiementsCard(enfant: enfant, anneeActive: anneeActive)),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EnfantPaiementsCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> enfant;
  final Map<String, dynamic>? anneeActive;

  const _EnfantPaiementsCard({required this.enfant, required this.anneeActive});

  @override
  ConsumerState<_EnfantPaiementsCard> createState() => _EnfantPaiementsCardState();
}

class _EnfantPaiementsCardState extends ConsumerState<_EnfantPaiementsCard> {
  String? _factureEnCours;

  int get _etudiantId => widget.enfant['id'] as int;

  String _dateEcheancePourMois(Map<String, dynamic> anneeActive, int mois) {
    final anneeDebut = DateTime.parse(anneeActive['date_debut'].toString()).year;
    final moisDebut = (anneeActive['mois_debut_annee_scolaire'] as num?)?.toInt() ?? 9;
    final jourEcheance = (anneeActive['jour_echeance_mensuelle'] as num?)?.toInt() ?? 5;
    final annee = mois >= moisDebut ? anneeDebut : anneeDebut + 1;
    return '$annee-${mois.toString().padLeft(2, '0')}-${jourEcheance.toString().padLeft(2, '0')}';
  }

  Future<void> _telechargerFacture(int anneeId, int mois) async {
    setState(() => _factureEnCours = 'mois-$mois');
    try {
      final matricule = widget.enfant['matricule'];
      await downloadAndOpen(
        '/etudiants/$_etudiantId/facture-ecolage/?annee_scolaire=$anneeId&mois=$mois&allow_paye=1',
        'facture_${matricule}_mois_$mois.pdf',
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la génération de la facture.')));
    } finally {
      if (mounted) setState(() => _factureEnCours = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anneeActive = widget.anneeActive;
    final anneeId = anneeActive?['id'] as int?;
    final dossierAsync = anneeId != null
        ? ref.watch(_dossierFinancierEnfantProvider((etudiantId: _etudiantId, anneeScolaireId: anneeId)))
        : const AsyncValue<Map<String, dynamic>?>.data(null);
    final paiementsAsync = anneeId != null
        ? ref.watch(_paiementsEnfantProvider((etudiantId: _etudiantId, anneeScolaireId: anneeId)))
        : const AsyncValue<List<Map<String, dynamic>>>.data(<Map<String, dynamic>>[]);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.enfant['prenom']} ${widget.enfant['nom']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            dossierAsync.when(
              data: (dossier) {
                if (dossier == null) return const Text('Chargement...');
                final statut = dossier['statut'];
                return Row(
                  children: [
                    Expanded(child: _tuile(context, 'Total dû', '${_fmt(dossier['total_du'])} Ar', Colors.blue)),
                    const SizedBox(width: 8),
                    Expanded(child: _tuile(context, 'Reste à payer', '${_fmt(dossier['reste_du'])} Ar', Colors.orange)),
                    const SizedBox(width: 8),
                    Expanded(child: _tuile(context, 'Statut', _statutLabels[statut] ?? '$statut', _statutColors[statut] ?? Colors.grey)),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => const Text('Dossier financier indisponible', style: TextStyle(fontSize: 12)),
            ),
            if (anneeActive != null) ...[
              const SizedBox(height: 20),
              Text('Suivi mensuel — Janvier à Décembre', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              paiementsAsync.when(
                loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => const Text('Paiements indisponibles', style: TextStyle(fontSize: 12)),
                data: (paiements) {
                  final aujourdhui = DateTime.now().toIso8601String().substring(0, 10);
                  return Column(
                    children: List.generate(12, (i) {
                      final mois = i + 1;
                      final lignes = paiements.where((p) => p['mois_couvert'] == mois && p['commentaire'] != _marqueurInscription).toList();
                      final echeance = _dateEcheancePourMois(anneeActive, mois);
                      final busy = _factureEnCours == 'mois-$mois';

                      if (lignes.isEmpty) {
                        final enRetard = echeance.compareTo(aujourdhui) < 0;
                        return _ligneMois(
                          context,
                          label: _moisLabels[mois],
                          sousTitre: 'Échéance : $echeance',
                          badge: _badge(enRetard ? 'En retard' : 'Non payé', enRetard ? Colors.red : Colors.grey),
                        );
                      }
                      final p = lignes.first;
                      final statut = p['statut']?.toString() ?? 'EN_ATTENTE';
                      final paye = statut == 'PAYE';
                      return _ligneMois(
                        context,
                        label: _moisLabels[mois],
                        sousTitre: paye ? 'Payé le ${p['date_paiement'] ?? '—'}' : 'Échéance : $echeance',
                        badge: _badge(_statutLabels[statut] ?? statut, _statutColors[statut] ?? Colors.grey),
                        bouton: paye
                            ? _petitBouton('Facture', Colors.blue, busy, () => _telechargerFacture(anneeId!, mois))
                            : null,
                      );
                    }),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tuile(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: color)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _badge(String texte, MaterialColor couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(texte, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: couleur.shade700)),
    );
  }

  Widget _petitBouton(String texte, MaterialColor couleur, bool busy, VoidCallback onPressed) {
    return SizedBox(
      height: 28,
      child: TextButton(
        onPressed: busy ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: couleur.withValues(alpha: 0.15),
          foregroundColor: couleur.shade700,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
        child: busy ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: couleur.shade700)) : Text(texte),
      ),
    );
  }

  Widget _ligneMois(BuildContext context, {required String label, required String sousTitre, required Widget badge, Widget? bouton}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(sousTitre, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            badge,
            if (bouton != null) ...[const SizedBox(width: 8), bouton],
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic value) {
    if (value == null) return '0';
    final n = double.tryParse('$value') ?? 0;
    final s = n.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}
