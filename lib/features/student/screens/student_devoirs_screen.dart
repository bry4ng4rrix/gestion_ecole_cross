import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/common.dart';
import '../student_providers.dart';

/// Miroir de `StudentDevoirs` (frontend/src/pages/StudentDashboard.jsx).
class StudentDevoirsScreen extends ConsumerWidget {
  const StudentDevoirsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entreesAsync = ref.watch(cahierTextesProvider);

    return entreesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Devoirs indisponibles', onRetry: () => ref.invalidate(cahierTextesProvider)),
      data: (entrees) {
        final aujourdhui = DateTime.now();
        final devoirs = entrees.where((e) => (e['travail_a_faire'] as String?)?.isNotEmpty == true).toList()
          ..sort((a, b) {
            final da = '${a['date_echeance_travail'] ?? ''}${a['heure_echeance_travail'] ?? ''}';
            final db = '${b['date_echeance_travail'] ?? ''}${b['heure_echeance_travail'] ?? ''}';
            return da.compareTo(db);
          });

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(cahierTextesProvider),
          child: ListView(
            children: [
              const SectionHeader(title: 'Devoirs', subtitle: 'Travail à faire pour votre classe'),
              if (devoirs.isEmpty)
                const EmptyView(message: 'Aucun devoir pour le moment.', icon: Icons.assignment_turned_in_outlined)
              else
                ...devoirs.map((d) => _devoirCard(context, d, aujourdhui)),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _devoirCard(BuildContext context, Map<String, dynamic> d, DateTime aujourdhui) {
    final echeanceStr = d['date_echeance_travail'] as String?;
    final statut = _statutDevoir(echeanceStr, aujourdhui);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(d['matiere_intitule']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statut.$2.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(statut.$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statut.$2)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(d['travail_a_faire']?.toString() ?? '', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'À rendre le ${echeanceStr ?? '—'}${(d['heure_echeance_travail'] as String?)?.isNotEmpty == true ? ' à ${(d['heure_echeance_travail'] as String).substring(0, 5)}' : ''}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            if ((d['piece_jointe'] as String?)?.isNotEmpty == true || (d['lien'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                children: [
                  if ((d['piece_jointe'] as String?)?.isNotEmpty == true)
                    _linkChip(context, 'Pièce jointe', d['piece_jointe'] as String),
                  if ((d['lien'] as String?)?.isNotEmpty == true) _linkChip(context, 'Lien', d['lien'] as String),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _linkChip(BuildContext context, String label, String url) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  (String, Color) _statutDevoir(String? echeance, DateTime aujourdhui) {
    if (echeance == null) return ('Sans échéance', Colors.grey);
    final date = DateTime.tryParse(echeance);
    if (date == null) return ('Sans échéance', Colors.grey);
    final today = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
    final due = DateTime(date.year, date.month, date.day);
    if (due.isBefore(today)) return ('En retard', const Color(0xFFD03B3B));
    if (due.isAtSameMomentAs(today)) return ("Pour aujourd'hui", const Color(0xFFEA580C));
    if (due.difference(today).inDays <= 3) return ('Bientôt', const Color(0xFFFAB219));
    return ('À venir', const Color(0xFF0CA30C));
  }
}
