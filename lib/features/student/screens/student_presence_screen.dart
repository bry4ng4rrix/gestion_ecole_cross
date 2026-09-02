import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/resource_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../student_providers.dart';

const _statutLabels = {'P': 'Présent', 'A': 'Absent', 'R': 'En retard', 'E': 'Absence justifiée'};
const _justificationLabels = {
  'AUCUNE': null,
  'EN_ATTENTE': 'Justificatif en attente',
  'ACCEPTEE': 'Justificatif accepté',
  'REFUSEE': 'Justificatif refusé',
};

/// Miroir de `AttendanceTracking` (frontend/src/pages/StudentDashboard.jsx).
class StudentPresenceScreen extends ConsumerStatefulWidget {
  const StudentPresenceScreen({super.key});

  @override
  ConsumerState<StudentPresenceScreen> createState() => _StudentPresenceScreenState();
}

class _StudentPresenceScreenState extends ConsumerState<StudentPresenceScreen> {
  int? _justifiantId;
  final _texteCtrl = TextEditingController();
  bool _envoiEnCours = false;

  @override
  void dispose() {
    _texteCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyerJustificatif(int presenceId) async {
    setState(() => _envoiEnCours = true);
    try {
      await ResourceService('/presences').action(presenceId, 'justifier', payload: {'justificatif': _texteCtrl.text});
      setState(() {
        _justifiantId = null;
        _texteCtrl.clear();
      });
      ref.invalidate(presencesProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Justificatif envoyé.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de l'envoi du justificatif.")));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presencesAsync = ref.watch(presencesProvider);

    return presencesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Présences indisponibles', onRetry: () => ref.invalidate(presencesProvider)),
      data: (presences) {
        final compteurs = <String, int>{};
        for (final p in presences) {
          final s = p['statut'] as String? ?? '';
          compteurs[s] = (compteurs[s] ?? 0) + 1;
        }
        final historique = presences.where((p) => p['statut'] != 'P').toList()
          ..sort((a, b) => (b['date_cours'] as String? ?? '').compareTo(a['date_cours'] as String? ?? ''));

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(presencesProvider),
          child: ListView(
            children: [
              const SectionHeader(title: 'Suivi de Présence', subtitle: 'Consultation de votre présence et absences'),
              Row(
                children: [
                  Expanded(child: StatCard(title: 'Présences', value: '${compteurs['P'] ?? 0}', icon: Icons.check_circle_outline, accentColor: PresenceColors.present)),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(title: 'Absences', value: '${compteurs['A'] ?? 0}', icon: Icons.cancel_outlined, accentColor: PresenceColors.absent)),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(title: 'Retards', value: '${compteurs['R'] ?? 0}', icon: Icons.schedule_rounded, accentColor: PresenceColors.retard)),
                ],
              ),
              const SizedBox(height: 20),
              Text('Historique des absences et retards', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (historique.isEmpty)
                const EmptyView(message: 'Aucune absence ou retard enregistré.', icon: Icons.event_available_outlined)
              else
                ...historique.map((record) {
                  final id = record['id'] as int;
                  final statut = record['statut'] as String? ?? '';
                  final justifLabel = _justificationLabels[record['justification_statut']];
                  final estJustifiee = statut == 'E';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${record['date_cours']} — ${record['matiere_intitule'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                    const SizedBox(height: 2),
                                    Text(
                                      [record['justificatif']?.toString().isNotEmpty == true ? record['justificatif'] : 'Aucun justificatif', if (justifLabel != null) '($justifLabel)']
                                          .join(' '),
                                      style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: (estJustifiee ? PresenceColors.present : PresenceColors.retard).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _statutLabels[statut] ?? statut,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: estJustifiee ? PresenceColors.present : PresenceColors.retard),
                                ),
                              ),
                            ],
                          ),
                          if (record['justification_statut'] == 'AUCUNE') ...[
                            const SizedBox(height: 8),
                            if (_justifiantId == id)
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _texteCtrl,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(hintText: 'Motif du justificatif...', isDense: true),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: (_texteCtrl.text.isEmpty || _envoiEnCours) ? null : () => _envoyerJustificatif(id),
                                    child: const Text('Envoyer'),
                                  ),
                                ],
                              )
                            else
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton(
                                  onPressed: () => setState(() => _justifiantId = id),
                                  child: const Text('Justifier'),
                                ),
                              ),
                          ],
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
    );
  }
}
