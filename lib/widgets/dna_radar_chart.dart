import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme/app_colors.dart';

class DnaRadarChart extends StatelessWidget {
  final double? completeness;
  final double? variety;
  final double? activity;
  final double? uniqueness;
  final double? engagement;

  final List<double>? customValues;
  final List<String>? customLabels;

  const DnaRadarChart({
    super.key,
    this.completeness,
    this.variety,
    this.activity,
    this.uniqueness,
    this.engagement,
    this.customValues,
    this.customLabels,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accent;
    final titleColor = isDark ? Colors.white70 : Colors.black87;

    final List<double> finalValues = customValues ?? [
      completeness ?? 0.0,
      variety ?? 0.0,
      activity ?? 0.0,
      uniqueness ?? 0.0,
      engagement ?? 0.0,
    ];

    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          dataSets: [
            RadarDataSet(
              fillColor: accentColor.withOpacity(0.2),
              borderColor: accentColor,
              entryRadius: 4,
              borderWidth: 2,
              dataEntries: finalValues.map((val) => RadarEntry(value: val)).toList(),
            ),
          ],
          getTitle: (index, angle) {
            if (customLabels != null) {
              if (index >= 0 && index < customLabels!.length) {
                return RadarChartTitle(text: customLabels![index], angle: angle);
              }
              return const RadarChartTitle(text: '');
            }
            switch (index) {
              case 0:
                return RadarChartTitle(text: 'Completeness (${finalValues[0]})', angle: angle);
              case 1:
                return RadarChartTitle(text: 'Variety (${finalValues[1]})', angle: angle);
              case 2:
                return RadarChartTitle(text: 'Activity (${finalValues[2]})', angle: angle);
              case 3:
                return RadarChartTitle(text: 'Uniqueness (${finalValues[3]})', angle: angle);
              case 4:
                return RadarChartTitle(text: 'Engagement (${finalValues[4]})', angle: angle);
              default:
                return const RadarChartTitle(text: '');
            }
          },
          titleTextStyle: TextStyle(color: titleColor, fontSize: 9, fontWeight: FontWeight.bold),
          titlePositionPercentageOffset: 0.15,
          tickCount: 5,
          ticksTextStyle: const TextStyle(color: Colors.transparent),
          gridBorderData: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1.5),
          tickBorderData: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1.5),
        ),
      ),
    );
  }
}
