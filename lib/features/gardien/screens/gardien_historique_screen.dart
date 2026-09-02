import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/resource_service.dart';
import '../../../core/widgets/common.dart';

final _sortiesDuJourProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, DateTime>((ref, date) {
  return ResourceService('/sorties-etudiants').list({'date': DateFormat('yyyy-MM-dd').format(date)});
});

/// Historique des sorties contrôlées par le gardien, filtrable par date (par défaut aujourd'hui).
class GardienHistoriqueScreen extends ConsumerStatefulWidget {
  const GardienHistoriqueScreen({super.key});

  @override
  ConsumerState<GardienHistoriqueScreen> createState() => _GardienHistoriqueScreenState();
}

class _GardienHistoriqueScreenState extends ConsumerState<GardienHistoriqueScreen> {
  DateTime _date = DateTime.now();

  Future<void> _choisirDate() async {
    final choisie = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (choisie != null) setState(() => _date = choisie);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sortiesAsync = ref.watch(_sortiesDuJourProvider(_date));
    final estAujourdhui = DateUtils.isSameDay(_date, DateTime.now());

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_sortiesDuJourProvider(_date)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  title: 'Historique des sorties',
                  subtitle: estAujourdhui ? "Aujourd'hui" : DateFormat('dd/MM/yyyy').format(_date),
                ),
              ),
              OutlinedButton.icon(onPressed: _choisirDate, icon: const Icon(Icons.calendar_month_rounded, size: 16), label: const Text('Date')),
            ],
          ),
          const SizedBox(height: 12),
          sortiesAsync.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => ErrorView(message: 'Historique indisponible', onRetry: () => ref.invalidate(_sortiesDuJourProvider(_date))),
            data: (sorties) {
              if (sorties.isEmpty) return const EmptyView(message: 'Aucune sortie enregistrée.', icon: Icons.history_toggle_off_rounded);
              return Column(
                children: sorties.map((s) {
                  final date = DateTime.tryParse(s['date_sortie']?.toString() ?? '');
                  final heure = date != null ? DateFormat('HH:mm').format(date.toLocal()) : '--:--';
                  final annule = s['statut'] == 'ANNULE';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: annule ? scheme.errorContainer : scheme.primaryContainer,
                        child: Text(
                          heure.split(':').first,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: annule ? scheme.onErrorContainer : scheme.onPrimaryContainer),
                        ),
                      ),
                      title: Text(s['etudiant_nom']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${s['classe_nom'] ?? 'Classe non renseignée'} · Parent : ${s['parent_nom'] ?? '—'} · Gardien : ${s['gardien_nom'] ?? '—'}'),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(heure, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (annule) Text('Annulée', style: TextStyle(fontSize: 10.5, color: scheme.error)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
