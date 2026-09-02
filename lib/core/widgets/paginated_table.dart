import 'package:flutter/material.dart';

/// Nombre de lignes par page pour tout `DataTable` paginé manuellement de l'app — un seul
/// endroit à changer si on veut un jour rendre ça configurable.
const lignesParPage = 25;

/// Numéros de page à afficher autour de la page courante, avec des trous (-1) condensés en "…".
List<int> plagePagination(int page, int totalPages) {
  const voisins = 1;
  final nbAffiches = voisins * 2 + 5;
  if (totalPages <= nbAffiches) return List.generate(totalPages, (i) => i);
  final gauche = (page - voisins).clamp(1, totalPages - 2);
  final droite = (page + voisins).clamp(1, totalPages - 2);
  return [
    0,
    if (gauche > 1) -1 else for (var i = 1; i < gauche; i++) i,
    for (var i = gauche; i <= droite; i++) i,
    if (droite < totalPages - 2) -1 else for (var i = droite + 1; i < totalPages - 1; i++) i,
    totalPages - 1,
  ];
}

/// Barre de pagination numérotée (1 2 3 4 … Suivant) pour un `DataTable` paginé manuellement
/// (voir [lignesParPage]/[plagePagination]) — partagée par tous les écrans admin en liste.
class PaginationBar extends StatelessWidget {
  const PaginationBar({super.key, required this.page, required this.totalPages, required this.onPageChange, required this.totalLignes});

  final int page;
  final int totalPages;
  final int totalLignes;
  final ValueChanged<int> onPageChange;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text('$totalLignes ligne(s) · Page ${page + 1} / $totalPages', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              IconButton(
                iconSize: 18,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Précédent',
                onPressed: page > 0 ? () => onPageChange(page - 1) : null,
              ),
              for (final p in plagePagination(page, totalPages))
                if (p == -1)
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('…'))
                else
                  InkWell(
                    onTap: () => onPageChange(p),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p == page ? scheme.primary : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${p + 1}',
                        style: TextStyle(
                          fontWeight: p == page ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                          color: p == page ? scheme.onPrimary : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
              TextButton(
                onPressed: page < totalPages - 1 ? () => onPageChange(page + 1) : null,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text('Suivant'), Icon(Icons.chevron_right, size: 18)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Enveloppe un `DataTable` pour qu'il s'étire sur toute la largeur disponible sur grand écran
/// tout en restant défilable horizontalement sur petit écran (même pattern que
/// `admin_administrative_screen.dart`) — évite de répéter le trio LayoutBuilder/
/// SingleChildScrollView/ConstrainedBox à chaque nouvel écran en DataTable.
class ResponsiveDataTable extends StatelessWidget {
  const ResponsiveDataTable({super.key, required this.table});

  final DataTable table;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: table,
          ),
        ),
      ),
    );
  }
}
