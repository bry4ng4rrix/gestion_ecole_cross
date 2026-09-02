import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Miroir de `DistributionClasseRadarChart` (frontend/src/components/statistiques/DistributionClasseRadarChart.jsx) :
/// effectif par classe de l'année active, en radar.
class DistributionClasseRadarChart extends StatelessWidget {
  final List<Map<String, dynamic>> classes;
  const DistributionClasseRadarChart({super.key, required this.classes});

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("Aucune classe pour l'année scolaire active."));
    }
    final scheme = Theme.of(context).colorScheme;
    final couleur = scheme.primary;

    return AspectRatio(
      aspectRatio: 1,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          ticksTextStyle: const TextStyle(fontSize: 0, color: Colors.transparent),
          radarBorderData: BorderSide(color: scheme.outlineVariant),
          gridBorderData: BorderSide(color: scheme.outlineVariant, width: 1),
          titlePositionPercentageOffset: 0.12,
          titleTextStyle: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          getTitle: (index, angle) => RadarChartTitle(text: index < classes.length ? (classes[index]['nom']?.toString() ?? '') : ''),
          dataSets: [
            RadarDataSet(
              fillColor: couleur.withValues(alpha: 0.25),
              borderColor: couleur,
              borderWidth: 2,
              entryRadius: 3,
              dataEntries: classes.map((c) => RadarEntry(value: (c['effectif'] as num?)?.toDouble() ?? 0)).toList(),
            ),
          ],
          radarBackgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
