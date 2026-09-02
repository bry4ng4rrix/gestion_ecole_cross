import 'package:flutter/material.dart';

import 'common.dart';

const joursSemaine = [
  {'code': 'LUN', 'label': 'Lundi', 'court': 'Lun'},
  {'code': 'MAR', 'label': 'Mardi', 'court': 'Mar'},
  {'code': 'MER', 'label': 'Mercredi', 'court': 'Mer'},
  {'code': 'JEU', 'label': 'Jeudi', 'court': 'Jeu'},
  {'code': 'VEN', 'label': 'Vendredi', 'court': 'Ven'},
  {'code': 'SAM', 'label': 'Samedi', 'court': 'Sam'},
];

const _timeColWidth = 76.0;
const _dayColWidth = 148.0;

/// Emploi du temps en grille Horaire × Jours façon Google Calendar — miroir de la
/// `<table>` de `EmploiDuTempsCalendar` / `StudentEmploiDuTemps` / `MonEmploiDuTempsPanel`
/// (frontend/src/components/academique/EmploiDuTempsCalendar.jsx,
/// frontend/src/pages/*Dashboard.jsx), avec défilement horizontal pour les petits écrans
/// (équivalent de `overflow-x-auto`).
class EdtWeekGrid extends StatelessWidget {
  final List<Map<String, dynamic>> creneaux;
  final bool showEnseignant;
  final bool showClasse;
  final void Function(Map<String, dynamic> creneau)? onDelete;

  const EdtWeekGrid({super.key, required this.creneaux, this.showEnseignant = true, this.showClasse = false, this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (creneaux.isEmpty) {
      return const EmptyView(message: 'Aucun créneau enregistré.', icon: Icons.calendar_today_outlined);
    }
    final scheme = Theme.of(context).colorScheme;
    final bordure = scheme.outlineVariant.withValues(alpha: 0.6);

    final creneauxTries = {for (final c in creneaux) '${c['heure_debut']}|${c['heure_fin']}': true}.keys.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bordure),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(color: bordure),
            verticalInside: BorderSide(color: bordure),
          ),
          columnWidths: {0: const FixedColumnWidth(_timeColWidth), for (var i = 1; i <= joursSemaine.length; i++) i: const FixedColumnWidth(_dayColWidth)},
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            TableRow(
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
              children: [_headerCell(context, 'Horaire'), ...joursSemaine.map((j) => _headerCell(context, j['label']!))],
            ),
            ...creneauxTries.map((cle) {
              final parts = cle.split('|');
              final heureDebut = parts[0];
              final heureFin = parts[1];
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(
                      '${_shortTime(heureDebut)}–${_shortTime(heureFin)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  ...joursSemaine.map((jour) {
                    final slot = creneaux.where((c) => c['jour'] == jour['code'] && c['heure_debut'] == heureDebut).toList();
                    return slot.isEmpty ? const SizedBox(height: 64) : _slotCell(context, slot.first);
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface),
    ),
  );

  Widget _slotCell(BuildContext context, Map<String, dynamic> s) {
    final scheme = Theme.of(context).colorScheme;
    final couleur = _parseHexColor(s['matiere_couleur'] as String? ?? '#6366f1');
    final groupe = s['groupe']?.toString();
    final salle = s['salle_nom']?.toString();
    final enseignantNom = s['enseignant_nom']?.toString();

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: couleur.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(s['matiere_intitule']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
                if (onDelete != null)
                  InkWell(
                    onTap: () => onDelete!(s),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close_rounded, size: 14, color: Colors.red.shade400),
                    ),
                  ),
              ],
            ),
            if (groupe != null && groupe.isNotEmpty)
              Text(
                groupe,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
              ),
            if (showClasse && s['classe_nom'] != null) Text(s['classe_nom'].toString(), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            if (showEnseignant && enseignantNom != null) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  UserAvatar(photoUrl: s['enseignant_photo'] as String?, initials: _initialesEnseignant(enseignantNom), radius: 8),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      enseignantNom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            if (salle != null) Text(salle, style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  String _initialesEnseignant(String nom) {
    final parts = nom.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _shortTime(dynamic value) {
    final s = value?.toString() ?? '';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  Color _parseHexColor(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF6366F1);
  }
}
