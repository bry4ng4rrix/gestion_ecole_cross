import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/edt_agenda.dart';
import '../admin_providers.dart';
import 'calendrier_scolaire_screen.dart';

const _jourCodes = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM'];

final _edtAdminProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, classeId) => ResourceService('/emplois-du-temps').list({'classe': classeId}));
final _matieresForEdtProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/matieres').list());
final _sallesForEdtProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/salles').list());

/// Miroir de `EmploiDuTempsManagement` (frontend/src/pages/AdminDashboard.jsx) : deux onglets —
/// « Programme Scolaire » (calendrier des vacances/examens/événements, [CalendrierScolaireScreen])
/// et « Planning hebdomadaire » (grille Horaire×Jours façon Google Calendar par classe).
class AdminEdtScreen extends StatefulWidget {
  const AdminEdtScreen({super.key});

  @override
  State<AdminEdtScreen> createState() => _AdminEdtScreenState();
}

class _AdminEdtScreenState extends State<AdminEdtScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _tabIndex) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SectionHeader(title: 'Emploi du Temps', subtitle: 'Planning hebdomadaire et calendrier'),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Programme Scolaire'),
              Tab(text: 'Planning hebdomadaire'),
            ],
          ),
          Expanded(
            child: TabBarView(controller: _tabController, children: const [CalendrierScolaireScreen(), _PlanningHebdomadaire()]),
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 1 ? const _AjouterCreneauFab() : null,
    );
  }
}

class _AjouterCreneauFab extends ConsumerWidget {
  const _AjouterCreneauFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classeId = ref.watch(_classeAffichee);
    if (classeId == null) return const SizedBox.shrink();
    return FloatingActionButton(child: const Icon(Icons.add), onPressed: () => _ouvrirFormulaireCreneau(context, ref, classeId));
  }
}

/// Classe explicitement choisie dans le menu déroulant de l'onglet « Planning hebdomadaire »
/// (`null` tant que l'utilisateur n'a pas encore changé la sélection par défaut).
final _classeSelectionneeProvider = StateProvider<int?>((ref) => null);

/// Classe réellement affichée par la grille — la sélection explicite, ou sinon la première
/// classe disponible. Dérivé plutôt que poussé dans `_classeSelectionneeProvider` au build
/// pour que la grille et le FAB restent en accord sans passer par un `addPostFrameCallback`.
final _classeAffichee = Provider.autoDispose<int?>((ref) {
  final selection = ref.watch(_classeSelectionneeProvider);
  if (selection != null) return selection;
  return ref.watch(adminClassesProvider).maybeWhen(data: (classes) => classes.isNotEmpty ? classes.first['id'] as int : null, orElse: () => null);
});

class _PlanningHebdomadaire extends ConsumerWidget {
  const _PlanningHebdomadaire();

  Future<void> _supprimerCreneau(BuildContext context, WidgetRef ref, int classeId, Map<String, dynamic> creneau) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce créneau ?'),
        content: Text('${creneau['matiere_intitule'] ?? 'Ce créneau'} sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await ResourceService('/emplois-du-temps').remove(creneau['id']);
      ref.invalidate(_edtAdminProvider(classeId));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Créneau supprimé.')));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la suppression.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(adminClassesProvider);

    return classesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Classes indisponibles', onRetry: () => ref.invalidate(adminClassesProvider)),
      data: (classes) {
        if (classes.isEmpty) return const EmptyView(message: 'Aucune classe.');
        final classeId = ref.watch(_classeAffichee) ?? classes.first['id'] as int;
        final edtAsync = ref.watch(_edtAdminProvider(classeId));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int>(
              initialValue: classeId,
              decoration: const InputDecoration(labelText: 'Classe'),
              items: classes.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom'].toString()))).toList(),
              onChanged: (v) => ref.read(_classeSelectionneeProvider.notifier).state = v,
            ),
            const SizedBox(height: 16),
            edtAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => const ErrorView(message: 'Créneaux indisponibles'),
              data: (creneaux) => EdtWeekGrid(creneaux: creneaux, showClasse: false, onDelete: (creneau) => _supprimerCreneau(context, ref, classeId, creneau)),
            ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

Future<void> _ouvrirFormulaireCreneau(BuildContext context, WidgetRef ref, int classeId) async {
  final matieres = await ref.read(_matieresForEdtProvider.future);
  final personnel = await ref.read(adminPersonnelProvider.future);
  final salles = await ref.read(_sallesForEdtProvider.future);
  final enseignants = personnel.where((p) => p['role'] == 'ENSEIGNANT').toList();
  if (matieres.isEmpty || enseignants.isEmpty) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune matière/enseignant disponible.')));
    return;
  }

  int matiereId = matieres.first['id'] as int;
  int enseignantId = enseignants.first['id'] as int;
  int? salleId;
  String jour = 'LUN';
  TimeOfDay heureDebut = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay heureFin = const TimeOfDay(hour: 9, minute: 0);
  bool envoiEnCours = false;
  String? erreur;

  String fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  if (!context.mounted) return;
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
              const Text('Nouveau créneau', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: matiereId,
                decoration: const InputDecoration(labelText: 'Matière'),
                items: matieres.map((m) => DropdownMenuItem(value: m['id'] as int, child: Text(m['intitule'].toString()))).toList(),
                onChanged: (v) => setModalState(() => matiereId = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: enseignantId,
                decoration: const InputDecoration(labelText: 'Enseignant'),
                items: enseignants.map((e) => DropdownMenuItem(value: e['id'] as int, child: Text('${e['first_name']} ${e['last_name']}'))).toList(),
                onChanged: (v) => setModalState(() => enseignantId = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: jour,
                decoration: const InputDecoration(labelText: 'Jour'),
                items: _jourCodes.map((j) => DropdownMenuItem(value: j, child: Text(j))).toList(),
                onChanged: (v) => setModalState(() => jour = v!),
              ),
              if (salles.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: salleId,
                  decoration: const InputDecoration(labelText: 'Salle (optionnel)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    ...salles.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text(s['nom'].toString()))),
                  ],
                  onChanged: (v) => setModalState(() => salleId = v),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Début : ${heureDebut.format(context)}'),
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: heureDebut);
                        if (picked != null) setModalState(() => heureDebut = picked);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Fin : ${heureFin.format(context)}'),
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: heureFin);
                        if (picked != null) setModalState(() => heureFin = picked);
                      },
                    ),
                  ),
                ],
              ),
              if (erreur != null) ...[const SizedBox(height: 8), Text(erreur!, style: const TextStyle(color: Colors.red, fontSize: 12.5))],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: envoiEnCours
                      ? null
                      : () async {
                          setModalState(() {
                            envoiEnCours = true;
                            erreur = null;
                          });
                          try {
                            await ResourceService('/emplois-du-temps').create({'classe': classeId, 'matiere': matiereId, 'enseignant': enseignantId, 'jour': jour, 'heure_debut': fmt(heureDebut), 'heure_fin': fmt(heureFin), if (salleId != null) 'salle': salleId});
                            ref.invalidate(_edtAdminProvider(classeId));
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            setModalState(() {
                              envoiEnCours = false;
                              erreur = 'Erreur lors de la création (chevauchement de créneau ?).';
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
