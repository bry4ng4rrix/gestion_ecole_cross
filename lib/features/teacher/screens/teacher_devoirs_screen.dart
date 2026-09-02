import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../teacher_providers.dart';

/// Miroir simplifié de `DevoirsPanel` (frontend/src/components/pedagogie/DevoirsPanel.jsx) :
/// création et liste des devoirs. Le scan OCR, la capture photo et le chat de classe restent
/// à porter (voir ROADMAP.md).
class TeacherDevoirsScreen extends ConsumerStatefulWidget {
  const TeacherDevoirsScreen({super.key});

  @override
  ConsumerState<TeacherDevoirsScreen> createState() => _TeacherDevoirsScreenState();
}

class _TeacherDevoirsScreenState extends ConsumerState<TeacherDevoirsScreen> {
  @override
  Widget build(BuildContext context) {
    final devoirsAsync = ref.watch(teacherCahierTextesProvider);

    return devoirsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Devoirs indisponibles', onRetry: () => ref.invalidate(teacherCahierTextesProvider)),
      data: (entrees) {
        final devoirs = entrees.where((e) => (e['travail_a_faire'] as String?)?.isNotEmpty == true).toList()
          ..sort((a, b) => '${b['date_echeance_travail']}'.compareTo('${a['date_echeance_travail']}'));

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _ouvrirFormulaire(context),
            icon: const Icon(Icons.add),
            label: const Text('Devoir'),
          ),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(teacherCahierTextesProvider),
            child: ListView(
              children: [
                const SectionHeader(title: 'Gestion des devoirs'),
                if (devoirs.isEmpty)
                  const EmptyView(message: 'Aucun devoir créé pour le moment.', icon: Icons.assignment_outlined)
                else
                  ...devoirs.map((d) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text('${d['matiere_intitule'] ?? ''} — ${d['classe_nom'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(d['travail_a_faire']?.toString() ?? ''),
                              const SizedBox(height: 4),
                              Text(
                                'Échéance : ${d['date_echeance_travail'] ?? '—'}',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _supprimer(d['id'] as int),
                          ),
                        ),
                      )),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _supprimer(int id) async {
    try {
      await ResourceService('/cahier-textes').remove(id);
      ref.invalidate(teacherCahierTextesProvider);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la suppression.')));
    }
  }

  Future<void> _ouvrirFormulaire(BuildContext context) async {
    final matieres = await ref.read(teacherMatieresProvider.future);
    final classes = await ref.read(teacherClassesProvider.future);
    if (matieres.isEmpty || classes.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune matière/classe disponible.')));
      return;
    }

    int matiereId = matieres.first['id'] as int;
    int classeId = classes.first['id'] as int;
    DateTime? echeance;
    final travailCtrl = TextEditingController();
    bool envoiEnCours = false;
    String? erreur;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nouveau devoir', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: matiereId,
                  decoration: const InputDecoration(labelText: 'Matière'),
                  items: matieres.map((m) => DropdownMenuItem(value: m['id'] as int, child: Text(m['intitule'].toString()))).toList(),
                  onChanged: (v) => setModalState(() => matiereId = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: classeId,
                  decoration: const InputDecoration(labelText: 'Classe'),
                  items: classes.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom'].toString()))).toList(),
                  onChanged: (v) => setModalState(() => classeId = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: travailCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Travail à faire', alignLabelWithHint: true),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(echeance == null ? "Date d'échéance" : DateFormat('dd/MM/yyyy').format(echeance!)),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setModalState(() => echeance = picked);
                  },
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
                            if (travailCtrl.text.trim().isEmpty) {
                              setModalState(() => erreur = 'Décrivez le travail à faire.');
                              return;
                            }
                            setModalState(() {
                              envoiEnCours = true;
                              erreur = null;
                            });
                            try {
                              await ResourceService('/cahier-textes').create({
                                'matiere': matiereId,
                                'classe': classeId,
                                'travail_a_faire': travailCtrl.text.trim(),
                                'date_seance': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                                if (echeance != null) 'date_echeance_travail': DateFormat('yyyy-MM-dd').format(echeance!),
                              });
                              ref.invalidate(teacherCahierTextesProvider);
                              if (context.mounted) Navigator.of(context).pop();
                            } catch (e) {
                              setModalState(() {
                                envoiEnCours = false;
                                erreur = "Erreur lors de la création du devoir.";
                              });
                            }
                          },
                    child: envoiEnCours ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Créer le devoir'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
