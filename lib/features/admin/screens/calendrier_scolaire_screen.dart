import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_message.dart';
import '../../../core/api/resource_service.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/widgets/common.dart';
import '../../../models/user.dart';

const _typeLabels = {'VACANCES': 'Vacances', 'EXAMEN': 'Examen', 'EVENEMENT': 'Événement', 'REUNION': 'Réunion', 'JOUR_FERIE': 'Jour férié', 'DEVOIR': 'Devoir'};
const _typeColors = {'VACANCES': Color(0xFF2563EB), 'EXAMEN': Color(0xFFDC2626), 'EVENEMENT': Color(0xFF9333EA), 'REUNION': Color(0xFFD97706), 'JOUR_FERIE': Color(0xFF059669), 'DEVOIR': Color(0xFF0D9488)};
const _joursCourts = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
const _moisNoms = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
const _rolesGestion = {UserRole.admin, UserRole.responsable, UserRole.secretariat};

final _evenementsCalendrierProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/evenements-calendrier').list());

String _formatDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Calendrier scolaire façon Google Calendar (vue mensuelle) — miroir de
/// `EvenementsCalendrierPanel` + `MonthCalendar` (frontend/src/components/calendrier/, ui/month-calendar.jsx) :
/// navigation mois par mois, vacances/examens/événements/réunions/jours fériés/devoirs affichés en
/// barres colorées par jour, synchronisation des jours fériés de Madagascar et gestion (créer/
/// supprimer) réservées à l'admin/responsable/secrétariat.
class CalendrierScolaireScreen extends ConsumerStatefulWidget {
  const CalendrierScolaireScreen({super.key});

  @override
  ConsumerState<CalendrierScolaireScreen> createState() => _CalendrierScolaireScreenState();
}

class _CalendrierScolaireScreenState extends ConsumerState<CalendrierScolaireScreen> {
  late int _mois;
  late int _annee;
  bool _syncEnCours = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _mois = now.month - 1;
    _annee = now.year;
  }

  void _naviguer(int dir) {
    setState(() {
      var m = _mois + dir;
      var a = _annee;
      if (m < 0) {
        m = 11;
        a -= 1;
      }
      if (m > 11) {
        m = 0;
        a += 1;
      }
      _mois = m;
      _annee = a;
    });
  }

  void _aujourdhui() {
    final now = DateTime.now();
    setState(() {
      _mois = now.month - 1;
      _annee = now.year;
    });
  }

  bool get _peutGerer => _rolesGestion.contains(ref.read(authProvider).user?.role);

  Future<void> _synchroniserJoursFeries() async {
    setState(() => _syncEnCours = true);
    try {
      final data = await ResourceService('/evenements-calendrier').action(null, 'synchroniser-jours-feries');
      ref.invalidate(_evenementsCalendrierProvider);
      final crees = (data is Map ? data['crees'] as int? : null) ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(crees > 0 ? '$crees jour${crees > 1 ? 's' : ''} férié${crees > 1 ? 's' : ''} importé${crees > 1 ? 's' : ''}.' : 'Déjà à jour — aucun nouveau jour férié.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e, 'Erreur lors de la synchronisation des jours fériés.'))));
      }
    } finally {
      if (mounted) setState(() => _syncEnCours = false);
    }
  }

  Future<void> _supprimer(int id) async {
    try {
      await ResourceService('/evenements-calendrier').remove(id);
      ref.invalidate(_evenementsCalendrierProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Événement supprimé.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la suppression.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final evenementsAsync = ref.watch(_evenementsCalendrierProvider);
    final scheme = Theme.of(context).colorScheme;
    final peutGerer = _peutGerer;

    return evenementsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Calendrier indisponible', onRetry: () => ref.invalidate(_evenementsCalendrierProvider)),
      data: (evenements) {
        final evenementsJour = _expanserParJour(evenements);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_evenementsCalendrierProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (peutGerer) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(onPressed: () => _ouvrirFormulaireEvenement(context), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Nouvel événement')),
                    OutlinedButton.icon(
                      onPressed: _syncEnCours ? null : _synchroniserJoursFeries,
                      icon: _syncEnCours ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.public_rounded, size: 18),
                      label: Text(_syncEnCours ? 'Synchronisation...' : 'Synchroniser les jours fériés (Madagascar)'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: _typeLabels.entries
                    .map(
                      (entry) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(color: _typeColors[entry.key], shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(entry.value, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              _moisHeader(context),
              const SizedBox(height: 8),
              _grilleMois(context, evenementsJour, peutGerer),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Map<String, List<Map<String, dynamic>>> _expanserParJour(List<Map<String, dynamic>> evenements) {
    final parJour = <String, List<Map<String, dynamic>>>{};
    for (final ev in evenements) {
      final debut = ev['date_debut']?.toString();
      if (debut == null) continue;
      final fin = ev['date_fin']?.toString() ?? debut;
      var jour = DateTime.parse(debut);
      final finDate = DateTime.parse(fin);
      var garde = 0;
      while (!jour.isAfter(finDate) && garde < 366) {
        parJour.putIfAbsent(_formatDate(jour), () => []).add(ev);
        jour = jour.add(const Duration(days: 1));
        garde++;
      }
    }
    return parJour;
  }

  Widget _moisHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton(onPressed: _aujourdhui, child: const Text("Aujourd'hui")),
        Row(
          children: [
            IconButton(onPressed: () => _naviguer(-1), icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Mois précédent'),
            SizedBox(
              width: 148,
              child: Text(
                '${_moisNoms[_mois]} $_annee',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            IconButton(onPressed: () => _naviguer(1), icon: const Icon(Icons.chevron_right_rounded), tooltip: 'Mois suivant'),
          ],
        ),
      ],
    );
  }

  Widget _grilleMois(BuildContext context, Map<String, List<Map<String, dynamic>>> evenementsJour, bool peutGerer) {
    final scheme = Theme.of(context).colorScheme;
    final bordure = scheme.outlineVariant.withValues(alpha: 0.5);
    final decalage = DateTime(_annee, _mois + 1, 1).weekday % 7;
    final nbJours = DateTime(_annee, _mois + 2, 0).day;
    final aujourdhui = DateTime.now();

    final cellules = <int?>[...List.filled(decalage, null), ...List.generate(nbJours, (i) => i + 1)];
    while (cellules.length % 7 != 0) {
      cellules.add(null);
    }
    final semaines = (cellules.length / 7).ceil();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bordure),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: scheme.surfaceContainerHighest,
            child: Row(
              children: _joursCourts
                  .map(
                    (j) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          j,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          ...List.generate(semaines, (semaine) {
            final jours = cellules.sublist(semaine * 7, semaine * 7 + 7);
            // `IntrinsicHeight` donne à cette Row une hauteur bornée calculée à partir de ses
            // enfants avant que `stretch` ne s'applique — sans lui, la Row hérite d'une
            // contrainte de hauteur non bornée (Column dans un ListView) et `stretch` force une
            // hauteur infinie sur les cellules : aucune exception en release (assertions
            // désactivées), juste une grille qui ne se peint jamais.
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: jours.map((jour) {
                  final estAujourdhui = jour != null && aujourdhui.year == _annee && aujourdhui.month == _mois + 1 && aujourdhui.day == jour;
                  final evts = jour == null ? const <Map<String, dynamic>>[] : (evenementsJour[_formatDate(DateTime(_annee, _mois + 1, jour))] ?? const []);
                  return Expanded(
                    child: InkWell(
                      onTap: jour == null || evts.isEmpty ? null : () => _ouvrirJour(context, jour, evts, peutGerer),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 84),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: bordure),
                            left: BorderSide(color: bordure),
                          ),
                          color: jour == null ? scheme.surfaceContainerLowest.withValues(alpha: 0.5) : null,
                        ),
                        child: jour == null
                            ? null
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: estAujourdhui ? scheme.primary : null),
                                    child: Text(
                                      '$jour',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: estAujourdhui ? scheme.onPrimary : scheme.onSurface),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  ...evts
                                      .take(2)
                                      .map(
                                        (e) => Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(bottom: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(color: _typeColors[e['type_evenement']] ?? Colors.grey, borderRadius: BorderRadius.circular(4)),
                                          child: Text(
                                            e['titre']?.toString() ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                  if (evts.length > 2) Text('+${evts.length - 2}', style: TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant)),
                                ],
                              ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _ouvrirJour(BuildContext context, int jour, List<Map<String, dynamic>> evts, bool peutGerer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Text('$jour ${_moisNoms[_mois]} $_annee', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              ...evts.map(
                (e) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(color: _typeColors[e['type_evenement']] ?? Colors.grey, borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _typeLabels[e['type_evenement']] ?? e['type_evenement']?.toString() ?? '',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _typeColors[e['type_evenement']]),
                              ),
                              Text(e['titre']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                              if (e['classe_nom'] != null) Text(e['classe_nom'].toString(), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              if ((e['description']?.toString() ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(e['description'].toString(), style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ),
                            ],
                          ),
                        ),
                        if (peutGerer)
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _supprimer(e['id'] as int);
                            },
                            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                            tooltip: 'Supprimer cet événement',
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ouvrirFormulaireEvenement(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final titreCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    String type = 'EVENEMENT';
    DateTime? dateDebut;
    DateTime? dateFin;
    bool envoiEnCours = false;
    String? erreur;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nouvel événement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titreCtrl,
                    decoration: const InputDecoration(labelText: 'Titre'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Titre requis.' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: "Type d'événement"),
                    items: _typeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setModalState(() => type = v!),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(dateDebut == null ? 'Date de début' : _formatDate(dateDebut!)),
                          onTap: () async {
                            final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                            if (picked != null) setModalState(() => dateDebut = picked);
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(dateFin == null ? 'Date de fin (optionnel)' : _formatDate(dateFin!)),
                          onTap: () async {
                            final picked = await showDatePicker(context: context, initialDate: dateDebut ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                            if (picked != null) setModalState(() => dateFin = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descriptionCtrl,
                    decoration: const InputDecoration(labelText: 'Description (optionnel)'),
                    maxLines: 2,
                  ),
                  if (erreur != null) ...[const SizedBox(height: 8), Text(erreur!, style: const TextStyle(color: Colors.red, fontSize: 12.5))],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: envoiEnCours
                          ? null
                          : () async {
                              if (!(formKey.currentState?.validate() ?? false)) return;
                              if (dateDebut == null) {
                                setModalState(() => erreur = 'Date de début requise.');
                                return;
                              }
                              setModalState(() {
                                envoiEnCours = true;
                                erreur = null;
                              });
                              try {
                                await ResourceService('/evenements-calendrier').create({'titre': titreCtrl.text.trim(), 'type_evenement': type, 'date_debut': _formatDate(dateDebut!), 'date_fin': _formatDate(dateFin ?? dateDebut!), if (descriptionCtrl.text.trim().isNotEmpty) 'description': descriptionCtrl.text.trim()});
                                ref.invalidate(_evenementsCalendrierProvider);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Événement ajouté.')));
                                }
                              } catch (e) {
                                setModalState(() {
                                  envoiEnCours = false;
                                  erreur = messageErreurChamps(e, "Erreur lors de l'ajout.");
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
      ),
    );
  }
}
