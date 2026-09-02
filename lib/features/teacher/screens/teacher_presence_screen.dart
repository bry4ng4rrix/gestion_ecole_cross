import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../teacher_providers.dart';

const _statutLabels = {'P': 'Présent', 'A': 'Absent', 'R': 'En retard', 'E': 'Excusé'};
const _statutColors = {'P': PresenceColors.present, 'A': PresenceColors.absent, 'R': PresenceColors.retard, 'E': PresenceColors.excuse};

/// Miroir simplifié de `AttendancePanel` côté enseignant (appel groupé) :
/// POST /presences/appel/ avec matière, classe, date, créneau et le statut de chaque élève.
class TeacherPresenceScreen extends ConsumerStatefulWidget {
  const TeacherPresenceScreen({super.key});

  @override
  ConsumerState<TeacherPresenceScreen> createState() => _TeacherPresenceScreenState();
}

class _TeacherPresenceScreenState extends ConsumerState<TeacherPresenceScreen> {
  int? _matiereId;
  int? _classeId;
  DateTime _date = DateTime.now();
  TimeOfDay _heureDebut = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _heureFin = const TimeOfDay(hour: 9, minute: 0);
  final Map<int, String> _statuts = {};
  bool _envoiEnCours = false;

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _enregistrerAppel(List<Map<String, dynamic>> etudiants) async {
    if (_matiereId == null) return;
    setState(() => _envoiEnCours = true);
    try {
      await ApiClient.instance.dio.post('/presences/appel/', data: {
        'matiere': _matiereId,
        'date_cours': DateFormat('yyyy-MM-dd').format(_date),
        'heure_debut': _fmtTime(_heureDebut),
        'heure_fin': _fmtTime(_heureFin),
        'entrees': etudiants.map((e) => {'etudiant': e['id'], 'statut': _statuts[e['id']] ?? 'P'}).toList(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appel enregistré.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de l'enregistrement de l'appel.")));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matieresAsync = ref.watch(teacherMatieresProvider);
    final classesAsync = ref.watch(teacherClassesProvider);
    final etudiantsAsync = ref.watch(teacherEtudiantsProvider);

    return matieresAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => const ErrorView(message: 'Matières indisponibles'),
      data: (matieres) => classesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'Classes indisponibles'),
        data: (classes) {
          if (matieres.isEmpty || classes.isEmpty) return const EmptyView(message: 'Aucune matière/classe disponible.');
          final matiereId = _matiereId ?? matieres.first['id'] as int;
          final classeId = _classeId ?? classes.first['id'] as int;
          final classe = classes.firstWhere((c) => c['id'] == classeId);

          return etudiantsAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => const ErrorView(message: 'Élèves indisponibles'),
            data: (etudiants) {
              final roster = etudiants.where((e) => e['classe_actuelle'] == classe['nom']).toList();

              return ListView(
                children: [
                  const SectionHeader(title: 'Présence & Absences', subtitle: "Faire l'appel"),
                  DropdownButtonFormField<int>(
                    initialValue: matiereId,
                    decoration: const InputDecoration(labelText: 'Matière'),
                    items: matieres.map((m) => DropdownMenuItem(value: m['id'] as int, child: Text(m['intitule'].toString()))).toList(),
                    onChanged: (v) => setState(() => _matiereId = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: classeId,
                    decoration: const InputDecoration(labelText: 'Classe'),
                    items: classes.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom'].toString()))).toList(),
                    onChanged: (v) => setState(() => _classeId = v),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(DateFormat('dd/MM/yyyy').format(_date)),
                          trailing: const Icon(Icons.calendar_today_outlined, size: 16),
                          onTap: () async {
                            final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2035));
                            if (picked != null) setState(() => _date = picked);
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${_heureDebut.format(context)} - ${_heureFin.format(context)}'),
                          trailing: const Icon(Icons.access_time, size: 16),
                          onTap: () async {
                            final debut = await showTimePicker(context: context, initialTime: _heureDebut);
                            if (debut != null && mounted) {
                              final fin = await showTimePicker(context: context, initialTime: _heureFin);
                              setState(() {
                                _heureDebut = debut;
                                if (fin != null) _heureFin = fin;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (roster.isEmpty)
                    const EmptyView(message: 'Aucun élève dans cette classe.', icon: Icons.people_outline)
                  else
                    ...roster.map((e) {
                      final statut = _statuts[e['id']] ?? 'P';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text('${e['prenom']} ${e['nom']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                              Wrap(
                                spacing: 4,
                                children: _statutLabels.entries.map((entry) {
                                  final selected = statut == entry.key;
                                  return ChoiceChip(
                                    label: Text(entry.key, style: const TextStyle(fontSize: 11)),
                                    selected: selected,
                                    selectedColor: _statutColors[entry.key]?.withValues(alpha: 0.25),
                                    onSelected: (_) => setState(() => _statuts[e['id'] as int] = entry.key),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  if (roster.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _envoiEnCours ? null : () => _enregistrerAppel(roster),
                        child: _envoiEnCours ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Enregistrer l'appel"),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
