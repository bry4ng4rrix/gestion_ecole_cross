import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../teacher_providers.dart';

/// Miroir de `CahierTextePanel` (frontend/src/components/pedagogie/CahierTextePanel.jsx) —
/// même ressource `cahier-textes` que Devoirs, mais orientée "compte-rendu de séance"
/// (`contenu_seance` obligatoire) plutôt que "devoir à faire".
class TeacherCahierTexteScreen extends ConsumerStatefulWidget {
  const TeacherCahierTexteScreen({super.key});

  @override
  ConsumerState<TeacherCahierTexteScreen> createState() => _TeacherCahierTexteScreenState();
}

class _TeacherCahierTexteScreenState extends ConsumerState<TeacherCahierTexteScreen> {
  @override
  Widget build(BuildContext context) {
    final entreesAsync = ref.watch(teacherCahierTextesProvider);

    return entreesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Cahier de textes indisponible', onRetry: () => ref.invalidate(teacherCahierTextesProvider)),
      data: (entrees) {
        final triees = [...entrees]..sort((a, b) => '${b['date_seance']}'.compareTo('${a['date_seance']}'));

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _ouvrirFormulaire(context),
            icon: const Icon(Icons.add),
            label: const Text('Entrée'),
          ),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(teacherCahierTextesProvider),
            child: ListView(
              children: [
                const SectionHeader(title: 'Cahier de textes'),
                if (triees.isEmpty)
                  const EmptyView(message: 'Aucune entrée dans le cahier de textes.', icon: Icons.menu_book_outlined)
                else
                  ...triees.map((entree) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text('${entree['matiere_intitule'] ?? ''} — ${entree['classe_nom'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                                  Text(entree['date_seance']?.toString() ?? '', style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(entree['contenu_seance']?.toString() ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              if ((entree['travail_a_faire'] as String?)?.isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Travail à faire', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                                      Text(entree['travail_a_faire'].toString()),
                                      if (entree['date_echeance_travail'] != null)
                                        Text('Pour le ${entree['date_echeance_travail']}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                              ],
                              if ((entree['piece_jointe'] as String?)?.isNotEmpty == true || (entree['lien'] as String?)?.isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 16,
                                  children: [
                                    if ((entree['piece_jointe'] as String?)?.isNotEmpty == true)
                                      _lienTexte(context, 'Pièce jointe', entree['piece_jointe'] as String),
                                    if ((entree['lien'] as String?)?.isNotEmpty == true) _lienTexte(context, 'Lien', entree['lien'] as String),
                                  ],
                                ),
                              ],
                            ],
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

  Widget _lienTexte(BuildContext context, String label, String url) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline)),
    );
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
    DateTime dateSeance = DateTime.now();
    final contenuCtrl = TextEditingController();
    final travailCtrl = TextEditingController();
    final lienCtrl = TextEditingController();
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
                const Text('Nouvelle entrée', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: classeId,
                  decoration: const InputDecoration(labelText: 'Classe'),
                  items: classes.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom'].toString()))).toList(),
                  onChanged: (v) => setModalState(() => classeId = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: matiereId,
                  decoration: const InputDecoration(labelText: 'Matière'),
                  items: matieres.map((m) => DropdownMenuItem(value: m['id'] as int, child: Text(m['intitule'].toString()))).toList(),
                  onChanged: (v) => setModalState(() => matiereId = v!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Séance du ${DateFormat('dd/MM/yyyy').format(dateSeance)}'),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: dateSeance, firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (picked != null) setModalState(() => dateSeance = picked);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: contenuCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Contenu de la séance', alignLabelWithHint: true)),
                const SizedBox(height: 12),
                TextField(controller: travailCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Travail à faire (optionnel)', alignLabelWithHint: true)),
                const SizedBox(height: 12),
                TextField(controller: lienCtrl, decoration: const InputDecoration(labelText: 'Lien externe (optionnel)')),
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
                            if (contenuCtrl.text.trim().isEmpty) {
                              setModalState(() => erreur = 'Décrivez le contenu de la séance.');
                              return;
                            }
                            setModalState(() {
                              envoiEnCours = true;
                              erreur = null;
                            });
                            try {
                              await ResourceService('/cahier-textes').create({
                                'classe': classeId,
                                'matiere': matiereId,
                                'date_seance': DateFormat('yyyy-MM-dd').format(dateSeance),
                                'contenu_seance': contenuCtrl.text.trim(),
                                if (travailCtrl.text.trim().isNotEmpty) 'travail_a_faire': travailCtrl.text.trim(),
                                if (lienCtrl.text.trim().isNotEmpty) 'lien': lienCtrl.text.trim(),
                              });
                              ref.invalidate(teacherCahierTextesProvider);
                              if (context.mounted) Navigator.of(context).pop();
                            } catch (e) {
                              setModalState(() {
                                envoiEnCours = false;
                                erreur = "Erreur lors de l'ajout.";
                              });
                            }
                          },
                    child: envoiEnCours ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Ajouter'),
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
