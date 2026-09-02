import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../teacher_providers.dart';

/// Miroir simplifié de `GradesEvaluation` (frontend/src/pages/TeacherDashboard.jsx) :
/// sélection d'une matière + d'un trimestre, liste des élèves avec leur moyenne, saisie
/// d'une note via une feuille modale.
class TeacherNotesScreen extends ConsumerStatefulWidget {
  const TeacherNotesScreen({super.key});

  @override
  ConsumerState<TeacherNotesScreen> createState() => _TeacherNotesScreenState();
}

class _TeacherNotesScreenState extends ConsumerState<TeacherNotesScreen> {
  int? _matiereId;
  int? _trimestreId;

  @override
  Widget build(BuildContext context) {
    final matieresAsync = ref.watch(teacherMatieresProvider);
    final trimestresAsync = ref.watch(teacherTrimestresProvider);
    final etudiantsAsync = ref.watch(teacherEtudiantsProvider);
    final notesAsync = ref.watch(teacherNotesProvider);

    return matieresAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Matières indisponibles', onRetry: () => ref.invalidate(teacherMatieresProvider)),
      data: (matieres) {
        if (matieres.isEmpty) return const EmptyView(message: "Aucune matière ne vous est assignée.");
        final matiereId = _matiereId ?? matieres.first['id'] as int;

        return trimestresAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => const ErrorView(message: 'Trimestres indisponibles'),
          data: (trimestres) {
            if (trimestres.isEmpty) return const EmptyView(message: 'Aucun trimestre configuré.');
            final actif = trimestres.firstWhere((t) => t['est_actif'] == true, orElse: () => trimestres.first);
            final trimestreId = _trimestreId ?? actif['id'] as int;

            return etudiantsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => const ErrorView(message: 'Élèves indisponibles'),
              data: (etudiants) => notesAsync.when(
                loading: () => const LoadingView(),
                error: (e, _) => const ErrorView(message: 'Notes indisponibles'),
                data: (notes) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(teacherEtudiantsProvider);
                      ref.invalidate(teacherNotesProvider);
                    },
                    child: ListView(
                      children: [
                        const SectionHeader(title: 'Notes & Évaluations', subtitle: 'Saisie des notes de vos matières'),
                        DropdownButtonFormField<int>(
                          initialValue: matiereId,
                          decoration: const InputDecoration(labelText: 'Matière'),
                          items: matieres.map((m) => DropdownMenuItem(value: m['id'] as int, child: Text(m['intitule'].toString()))).toList(),
                          onChanged: (v) => setState(() => _matiereId = v),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: trimestres.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final t = trimestres[i];
                              final selected = t['id'] == trimestreId;
                              return ChoiceChip(
                                label: Text('Trimestre ${t['numero']}'),
                                selected: selected,
                                onSelected: (_) => setState(() => _trimestreId = t['id'] as int),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (etudiants.isEmpty)
                          const EmptyView(message: 'Aucun élève trouvé.', icon: Icons.people_outline)
                        else
                          ...etudiants.map((etu) {
                            final notesEleve = notes
                                .where((n) => n['etudiant'] == etu['id'] && n['matiere'] == matiereId && n['trimestre'] == trimestreId)
                                .toList();
                            final moyenne = notesEleve.isEmpty
                                ? null
                                : notesEleve.map((n) => double.tryParse('${n['valeur']}') ?? 0).reduce((a, b) => a + b) / notesEleve.length;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text('${etu['prenom']} ${etu['nom']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(notesEleve.isEmpty ? 'Aucune note' : notesEleve.map((n) => '${n['type_evaluation']}: ${n['valeur']}').join(', ')),
                                trailing: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  children: [
                                    if (moyenne != null)
                                      Text('${moyenne.toStringAsFixed(2)}/20', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      tooltip: 'Ajouter une note',
                                      onPressed: () => _ouvrirSaisie(context, etu, matiereId, trimestreId),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _ouvrirSaisie(BuildContext context, Map<String, dynamic> etudiant, int matiereId, int trimestreId) async {
    final typeCtrl = TextEditingController();
    final valeurCtrl = TextEditingController();
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
              Text('Note — ${etudiant['prenom']} ${etudiant['nom']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 16),
              TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: "Type d'évaluation (ex: Devoir, Composition)")),
              const SizedBox(height: 12),
              TextField(
                controller: valeurCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Note sur 20'),
              ),
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
                          if (typeCtrl.text.trim().isEmpty || valeurCtrl.text.trim().isEmpty) {
                            setModalState(() => erreur = 'Veuillez remplir tous les champs.');
                            return;
                          }
                          setModalState(() {
                            envoiEnCours = true;
                            erreur = null;
                          });
                          try {
                            await ResourceService('/notes').create({
                              'etudiant': etudiant['id'],
                              'matiere': matiereId,
                              'trimestre': trimestreId,
                              'type_evaluation': typeCtrl.text.trim(),
                              'valeur': valeurCtrl.text.trim(),
                            });
                            ref.invalidate(teacherNotesProvider);
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            setModalState(() {
                              envoiEnCours = false;
                              erreur = "Erreur lors de l'enregistrement (note déjà saisie pour ce type ?).";
                            });
                          }
                        },
                  child: envoiEnCours ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
