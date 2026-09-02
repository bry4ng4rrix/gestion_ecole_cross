import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin_providers.dart';

const _couleurReussite = Color(0xFF0CA30C);
const _couleurRetard = Color(0xFFFAB219);
const _couleurAbsence = Color(0xFFD03B3B);

/// Données agrégées : une entrée par trimestre de l'année active, avec les 3 taux.
final tauxParTrimestreProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int?>((ref, anneeScolaireId) async {
  if (anneeScolaireId == null) return [];
  final trimestres = await ref.watch(adminTrimestresProvider.future);
  final delAnnee = trimestres.where((t) => t['annee_scolaire'] == anneeScolaireId).toList()
    ..sort((a, b) => (a['numero'] as int).compareTo(b['numero'] as int));

  final resultats = <Map<String, dynamic>>[];
  for (final t in delAnnee) {
    final stats = await ref.watch(statistiquesFiltreesProvider((anneeScolaireId: anneeScolaireId, trimestreId: t['id'] as int)).future);
    resultats.add({
      'trimestre': 'T${t['numero']}',
      'reussite': (stats?['taux_reussite'] as num?)?.toDouble() ?? 0,
      'retard': (stats?['taux_retard'] as num?)?.toDouble() ?? 0,
      'absence': (stats?['taux_absence'] as num?)?.toDouble() ?? 0,
    });
  }
  return resultats;
});

/// Miroir de `TauxParTrimestreChart` (frontend/src/components/statistiques/TauxParTrimestreChart.jsx) :
/// évolution des taux de réussite/retard/absence par trimestre de l'année active.
class TauxParTrimestreChart extends ConsumerWidget {
  final int? anneeScolaireId;
  const TauxParTrimestreChart({super.key, required this.anneeScolaireId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(tauxParTrimestreProvider(anneeScolaireId));
    final scheme = Theme.of(context).colorScheme;

    return dataAsync.when(
      loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => const SizedBox(height: 80, child: Center(child: Text('Statistiques indisponibles.'))),
      data: (data) {
        if (data.isEmpty) return const SizedBox(height: 80, child: Center(child: Text("Aucun trimestre pour l'année active.")));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25, getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant, strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: 25, getTitlesWidget: (v, meta) => Text('${v.toInt()}%', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)))),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final i = v.round();
                          if ((v - i).abs() > 0.01 || i < 0 || i >= data.length) return const SizedBox.shrink();
                          return Padding(padding: const EdgeInsets.only(top: 6), child: Text(data[i]['trimestre'] as String, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)));
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => scheme.inverseSurface),
                  ),
                  lineBarsData: [
                    _serie(data, 'reussite', _couleurReussite),
                    _serie(data, 'retard', _couleurRetard),
                    _serie(data, 'absence', _couleurAbsence),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              children: const [
                _Legende(couleur: _couleurReussite, label: 'Taux de réussite'),
                _Legende(couleur: _couleurRetard, label: 'Taux de retard'),
                _Legende(couleur: _couleurAbsence, label: "Taux d'absence"),
              ],
            ),
          ],
        );
      },
    );
  }

  LineChartBarData _serie(List<Map<String, dynamic>> data, String cle, Color couleur) {
    return LineChartBarData(
      spots: [for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), (data[i][cle] as num).toDouble())],
      isCurved: true,
      color: couleur,
      barWidth: 2.5,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: true, color: couleur.withValues(alpha: 0.12)),
    );
  }
}

class _Legende extends StatelessWidget {
  final Color couleur;
  final String label;
  const _Legende({required this.couleur, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
