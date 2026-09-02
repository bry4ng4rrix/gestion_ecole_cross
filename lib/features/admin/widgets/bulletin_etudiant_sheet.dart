import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/widgets/common.dart';
import '../admin_providers.dart';

const _mentionColors = {
  'EXCELLENT': Colors.green,
  'TRES_BIEN': Colors.green,
  'BIEN': Colors.blue,
  'ASSEZ_BIEN': Colors.orange,
  'PASSABLE': Colors.orange,
  'INSUFFISANT': Colors.red,
};

/// Récapitulatif des notes d'un élève, toutes matières confondues, par trimestre — miroir
/// simplifié de `NotesEvaluationsPanel` / `Bulletin` (frontend/src/components/notes/,
/// frontend/src/pages/StudentDashboard.jsx « Notes & Résultats »), scopé à un seul élève.
Future<void> ouvrirBulletinEtudiant(BuildContext context, Map<String, dynamic> etudiant) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => _BulletinContent(etudiant: etudiant, scrollController: scrollController),
    ),
  );
}

class _BulletinContent extends ConsumerStatefulWidget {
  final Map<String, dynamic> etudiant;
  final ScrollController scrollController;
  const _BulletinContent({required this.etudiant, required this.scrollController});

  @override
  ConsumerState<_BulletinContent> createState() => _BulletinContentState();
}

class _BulletinContentState extends ConsumerState<_BulletinContent> {
  int? _trimestreId;

  int get _etudiantId => widget.etudiant['id'] as int;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notesAsync = ref.watch(notesDeLetudiantProvider(_etudiantId));
    final matieresAsync = ref.watch(adminMatieresProvider);
    final trimestresAsync = ref.watch(adminTrimestresProvider);
    final bulletinsAsync = ref.watch(bulletinsDeLetudiantProvider(_etudiantId));

    return SafeArea(
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Text('Bulletin — ${widget.etudiant['prenom']} ${widget.etudiant['nom']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${widget.etudiant['classe_actuelle'] ?? '—'}', style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          trimestresAsync.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => const Text('Trimestres indisponibles.'),
            data: (trimestres) {
              final tries = [...trimestres]..sort((a, b) => (a['numero'] as num? ?? 0).compareTo(b['numero'] as num? ?? 0));
              if (tries.isEmpty) return const Text('Aucun trimestre configuré.', style: TextStyle(fontSize: 13));
              final actif = tries.where((t) => t['est_actif'] == true).toList();
              final selectionId = _trimestreId ?? (actif.isNotEmpty ? actif.first['id'] as int : tries.first['id'] as int);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: tries.map((t) {
                      final id = t['id'] as int;
                      return ChoiceChip(
                        label: Text('Trimestre ${t['numero']}'),
                        selected: id == selectionId,
                        onSelected: (_) => setState(() => _trimestreId = id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  bulletinsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (bulletins) {
                      final bulletinsDuTrimestre = bulletins.where((b) => b['trimestre'] == selectionId).toList();
                      if (bulletinsDuTrimestre.isEmpty) return const SizedBox.shrink();
                      final b = bulletinsDuTrimestre.first;
                      final mention = b['mention']?.toString();
                      final couleur = _mentionColors[mention] ?? Colors.grey;
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: couleur.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: couleur.withValues(alpha: 0.3))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Moyenne générale', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                                  Text('${b['moyenne_generale'] ?? '—'}/20', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: couleur.shade700)),
                                ],
                              ),
                            ),
                            if (b['rang'] != null)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Rang', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                                    Text('${b['rang']}${b['effectif_classe'] != null ? ' / ${b['effectif_classe']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            if (mention != null)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Mention', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                                    Text(mention, style: TextStyle(fontWeight: FontWeight.w700, color: couleur.shade700)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  _MoyennePonderee(etudiantId: _etudiantId, trimestreId: selectionId),
                  const SizedBox(height: 16),
                  Text('Notes par matière', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  notesAsync.when(
                    loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => const Text('Notes indisponibles.'),
                    data: (notes) => matieresAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const Text('Matières indisponibles.'),
                      data: (matieres) {
                        final notesDuTrimestre = notes.where((n) => n['trimestre'] == selectionId).toList();
                        if (notesDuTrimestre.isEmpty) return const EmptyView(message: 'Aucune note pour ce trimestre.', icon: Icons.grade_outlined);

                        final parMatiere = <int, List<Map<String, dynamic>>>{};
                        for (final n in notesDuTrimestre) {
                          final matiereId = n['matiere'] as int?;
                          if (matiereId == null) continue;
                          parMatiere.putIfAbsent(matiereId, () => []).add(n);
                        }

                        return Column(
                          children: parMatiere.entries.map((entry) {
                            final matiere = matieres.where((m) => m['id'] == entry.key).toList();
                            final nomMatiere = matiere.isNotEmpty ? matiere.first['intitule']?.toString() ?? '—' : '—';
                            final coefficient = matiere.isNotEmpty ? matiere.first['coefficient'] : null;
                            final valeurs = entry.value.map((n) => double.tryParse('${n['valeur']}') ?? 0).toList();
                            final moyenneMatiere = valeurs.isEmpty ? null : valeurs.reduce((a, b) => a + b) / valeurs.length;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(text: nomMatiere, style: const TextStyle(fontWeight: FontWeight.w700)),
                                                if (coefficient != null) TextSpan(text: '  ·  coef. $coefficient', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (moyenneMatiere != null)
                                          Text('${moyenneMatiere.toStringAsFixed(2)}/20', style: TextStyle(fontWeight: FontWeight.w800, color: moyenneMatiere >= 10 ? Colors.green.shade700 : Colors.red.shade700)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: entry.value.map((n) {
                                        final valeur = double.tryParse('${n['valeur']}') ?? 0;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${valeur.toStringAsFixed(2)}/20', style: TextStyle(fontWeight: FontWeight.w700, color: valeur >= 10 ? Colors.green.shade700 : Colors.red.shade700)),
                                              Text(n['type_evaluation']?.toString() ?? '', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MoyennePonderee extends StatefulWidget {
  final int etudiantId;
  final int trimestreId;
  const _MoyennePonderee({required this.etudiantId, required this.trimestreId});

  @override
  State<_MoyennePonderee> createState() => _MoyennePondereeState();
}

class _MoyennePondereeState extends State<_MoyennePonderee> {
  double? _moyenne;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void didUpdateWidget(covariant _MoyennePonderee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trimestreId != widget.trimestreId || oldWidget.etudiantId != widget.etudiantId) _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final response = await ApiClient.instance.dio.get('/notes/moyenne/', queryParameters: {'etudiant': widget.etudiantId, 'trimestre': widget.trimestreId});
      final moyenne = response.data['moyenne'];
      if (mounted) setState(() => _moyenne = moyenne == null ? null : double.tryParse('$moyenne'));
    } catch (_) {
      if (mounted) setState(() => _moyenne = null);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) return const SizedBox.shrink();
    if (_moyenne == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('Moyenne pondérée par coefficient : ', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
          Text('${_moyenne!.toStringAsFixed(2)}/20', style: TextStyle(fontWeight: FontWeight.w800, color: _moyenne! >= 10 ? Colors.green.shade700 : Colors.red.shade700)),
        ],
      ),
    );
  }
}
