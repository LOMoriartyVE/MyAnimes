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
  final double? titleFontSize;

  const DnaRadarChart({
    super.key,
    this.completeness,
    this.variety,
    this.activity,
    this.uniqueness,
    this.engagement,
    this.customValues,
    this.customLabels,
    this.titleFontSize,
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
      height: 240,
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
                return RadarChartTitle(text: customLabels![index], angle: 0);
              }
              return const RadarChartTitle(text: '', angle: 0);
            }
            switch (index) {
              case 0:
                return RadarChartTitle(text: 'Completeness (${finalValues[0]})', angle: 0);
              case 1:
                return RadarChartTitle(text: 'Variety (${finalValues[1]})', angle: 0);
              case 2:
                return RadarChartTitle(text: 'Activity (${finalValues[2]})', angle: 0);
              case 3:
                return RadarChartTitle(text: 'Uniqueness (${finalValues[3]})', angle: 0);
              case 4:
                return RadarChartTitle(text: 'Engagement (${finalValues[4]})', angle: 0);
              default:
                return const RadarChartTitle(text: '', angle: 0);
            }
          },
          titleTextStyle: TextStyle(color: titleColor, fontSize: titleFontSize ?? 11, fontWeight: FontWeight.bold),
          titlePositionPercentageOffset: 0.18,
          tickCount: 5,
          ticksTextStyle: const TextStyle(color: Colors.transparent),
          gridBorderData: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1.5),
          tickBorderData: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1.5),
        ),
      ),
    );
  }
}
