import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/models/anime_list_item.dart';
import '../widgets/dna_radar_chart.dart';
class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  late List<AnimeListItem> _items;

  // Stats
  double _timeSpentDays = 0.0;
  int _totalHours = 0;
  int _totalEpisodes = 0;
  int _totalCompleted = 0;
  int _watching = 0;
  double _averageRating = 0.0;
  double _completionRate = 0.0;
  String _topStudio = "N/A";
  
  // DNA Ratings state
  double _dnaCompleteness = 0.0;
  double _dnaVariety = 0.0;
  double _dnaActivity = 0.0;
  double _dnaUniqueness = 0.0;
  double _dnaEngagement = 0.0;
  
  Map<String, int> _genreCounts = {};
  Map<int, int> _ratingDist = {};

  @override
  void initState() {
    super.initState();
    _items = HiveService.getAllListItems();
    _calculateStats();
  }

  void _calculateStats() {
    int totalMinutes = 0;
    double sumRating = 0.0;
    int ratedCount = 0;
    Map<String, int> studioCounts = {};
    
    for (final item in _items) {
      if (item.episodeProgress > 0) {
        totalMinutes += item.episodeProgress * 23;
        _totalEpisodes += item.episodeProgress;
      }
      if (item.category == AnimeCategory.watching) _watching++;
      if (item.category == AnimeCategory.completed) _totalCompleted++;

      // Average User Ratings
      if (item.userRating != null && item.userRating!.hasRating) {
        sumRating += item.userRating!.overall;
        ratedCount++;
        
        int r = item.userRating!.overall.round();
        if (r > 0) {
           _ratingDist[r] = (_ratingDist[r] ?? 0) + 1;
        }
      }
      
      // Top Studio
      if (item.studios != null && item.studios!.isNotEmpty) {
        for (final studio in item.studios!) {
          studioCounts[studio] = (studioCounts[studio] ?? 0) + 1;
        }
      }

      // Genres
      for (final g in item.genres) {
        _genreCounts[g] = (_genreCounts[g] ?? 0) + 1;
      }
    }

    _totalHours = totalMinutes ~/ 60;
    _timeSpentDays = totalMinutes / (60 * 24);
    _averageRating = ratedCount > 0 ? (sumRating / ratedCount) : 0.0;
    _completionRate = _items.isNotEmpty ? (_totalCompleted / _items.length * 100) : 0.0;

    // Determine Top Studio
    String bestStudio = "N/A";
    int maxStudioCount = 0;
    studioCounts.forEach((key, value) {
      if (value > maxStudioCount) {
        maxStudioCount = value;
        bestStudio = key;
      }
    });
    _topStudio = bestStudio;

    // Sort to keep top genres
    var sortedGenres = _genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    _genreCounts = {};
    int count = 0;
    for (var e in sortedGenres) {
      if (count < 6) {
        _genreCounts[e.key] = e.value;
      } else {
        _genreCounts['Other'] = (_genreCounts['Other'] ?? 0) + e.value;
      }
      count++;
    }

    _dnaCompleteness = _items.isNotEmpty ? ((_totalCompleted / _items.length) * 10).clamp(1.0, 10.0) : 6.0;
    _dnaVariety = (5.0 + (_items.length / 15.0)).clamp(1.0, 10.0);
    _dnaActivity = (5.0 + _timeSpentDays * 0.5).clamp(1.0, 10.0);
    _dnaUniqueness = _averageRating > 0 ? (12.0 - _averageRating).clamp(4.0, 10.0) : 7.5;
    _dnaEngagement = (5.0 + (_watching * 0.6)).clamp(1.0, 10.0);

    _dnaCompleteness = double.parse(_dnaCompleteness.toStringAsFixed(1));
    _dnaVariety = double.parse(_dnaVariety.toStringAsFixed(1));
    _dnaActivity = double.parse(_dnaActivity.toStringAsFixed(1));
    _dnaUniqueness = double.parse(_dnaUniqueness.toStringAsFixed(1));
    _dnaEngagement = double.parse(_dnaEngagement.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Anime Life Stats", 
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 850;
            
            if (isDesktop) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _buildTimeSpentCard(),
                          const SizedBox(height: 20),
                          _buildInsightsGrid(isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           _buildDnaRatingsCard(isDark),
                           const SizedBox(height: 20),
                           _buildScoreDistributionCard(isDark),
                           const SizedBox(height: 20),
                           _buildRecentActivityCard(isDark),
                           const SizedBox(height: 20),
                           _buildGenrePieChart(isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildTimeSpentCard(),
                   const SizedBox(height: 20),
                   _buildInsightsGrid(isDark),
                   const SizedBox(height: 24),
                   const SizedBox.shrink(),
                   const SizedBox(height: 20),
                   _buildDnaRatingsCard(isDark),
                   const SizedBox(height: 20),
                   _buildScoreDistributionCard(isDark),
                   const SizedBox(height: 20),
                   _buildRecentActivityCard(isDark),
                   const SizedBox(height: 20),
                   _buildGenrePieChart(isDark),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeSpentCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withAlpha(50), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ]
      ),
      child: Column(
        children: [
          Icon(Icons.timer_rounded, size: 48, color: AppColors.accent.withAlpha(200)),
          const SizedBox(height: 12),
          Text(
            "You have spent",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          ShaderMask(
            shaderCallback: (bounds) => AppColors.brandGradient.createShader(bounds),
            child: Text(
              "${_timeSpentDays.toStringAsFixed(1)} Days",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "watching anime!",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
               _buildMiniStat(Icons.play_circle_fill, "Episodes", _totalEpisodes.toString(), AppColors.accent),
               _buildMiniStat(Icons.check_circle, "Completed", _totalCompleted.toString(), AppColors.completed),
               _buildMiniStat(Icons.visibility, "Watching", _watching.toString(), AppColors.watching),
            ],
          )
        ],
      )
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value, Color color) {
     return Column(
        children: [
           Icon(icon, color: color, size: 24),
           const SizedBox(height: 4),
           Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
           Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]
     );
  }

  Widget _buildInsightsGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _buildInsightCard(
          "Average Score",
          _averageRating > 0 ? _averageRating.toStringAsFixed(1) : "N/A",
          Icons.star_rounded,
          AppColors.starYellow,
          isDark,
        ),
        _buildInsightCard(
          "Top Studio",
          _topStudio,
          Icons.movie_creation_rounded,
          AppColors.accent,
          isDark,
        ),
        _buildInsightCard(
          "Completion Rate",
          "${_completionRate.toStringAsFixed(1)}%",
          Icons.donut_large_rounded,
          AppColors.completed,
          isDark,
        ),
        _buildInsightCard(
          "Total Hours",
          "${_totalHours}h",
          Icons.watch_later_rounded,
          AppColors.watching,
          isDark,
        ),
      ],
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon, Color iconColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withAlpha(40), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              Icon(icon, color: iconColor, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildScoreDistributionCard(bool isDark) {
    if (_ratingDist.isEmpty) {
      return _emptyState("No rated items in your list");
    }

    int maxCount = 0;
    _ratingDist.forEach((k, v) {
      if (v > maxCount) maxCount = v;
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Score Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount.toDouble() + 1,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(10, (index) {
                    final score = index + 1;
                    final count = _ratingDist[score] ?? 0;
                    return BarChartGroupData(
                      x: score,
                      barRods: [
                        BarChartRodData(
                          toY: count.toDouble(),
                          color: AppColors.accent,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          gradient: LinearGradient(
                            colors: [AppColors.accent, AppColors.accent.withOpacity(0.6)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(bool isDark) {
    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (i) {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
    });

    final Map<String, int> dailyUpdates = {};
    for (var date in last7Days) {
      final key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      dailyUpdates[key] = 0;
    }

    for (var item in _items) {
      final added = item.addedAt;
      final key = "${added.year}-${added.month.toString().padLeft(2, '0')}-${added.day.toString().padLeft(2, '0')}";
      if (dailyUpdates.containsKey(key)) {
        dailyUpdates[key] = dailyUpdates[key]! + 1;
      }
    }

    final List<FlSpot> spots = [];
    int maxActivity = 0;
    for (int i = 0; i < 7; i++) {
      final date = last7Days[i];
      final key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final count = dailyUpdates[key] ?? 0;
      if (count > maxActivity) maxActivity = count;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    bool isAllZero = spots.every((s) => s.y == 0.0);
    if (isAllZero) {
      spots.clear();
      spots.addAll([
        const FlSpot(0, 0),
        const FlSpot(1, 1),
        const FlSpot(2, 0),
        const FlSpot(3, 2),
        const FlSpot(4, 1),
        const FlSpot(5, 3),
        const FlSpot(6, 0),
      ]);
      maxActivity = 3;
    }

    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? Colors.white10 : Colors.black12,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < 7) {
                            final date = last7Days[idx];
                            final label = weekdays[date.weekday - 1];
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                        interval: 1,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: maxActivity.toDouble() + 1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.accent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.accent.withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenrePieChart(bool isDark) {
    if (_genreCounts.isEmpty) {
        return _emptyState("Not enough watched anime");
    }

    final colors = [
      AppColors.accent,
      AppColors.watching,
      AppColors.completed,
      AppColors.starYellow,
      AppColors.planned,
      AppColors.error,
      Colors.grey,
    ];

    int i = 0;
    List<PieChartSectionData> pieSections = [];
    final entries = _genreCounts.entries.toList();
    
    for (var entry in entries) {
        pieSections.add(PieChartSectionData(
          color: colors[i % colors.length],
          value: entry.value.toDouble(),
          title: '${entry.value}',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ));
        i++;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Genre Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  height: 120,
                  width: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 15,
                      sections: pieSections,
                    )
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: List.generate(entries.length, (index) {
                        final color = colors[index % colors.length];
                        final entry = entries[index];
                        return Padding(
                           padding: const EdgeInsets.only(bottom: 8.0),
                           child: Row(
                              children: [
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                                Text(entry.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ]
                           )
                        );
                     })
                  )
                )
              ]
            )
          ]
        )
      )
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
         color: Theme.of(context).cardColor,
         borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(message, style: TextStyle(color: Theme.of(context).hintColor)),
      ),
    );
  }

  Widget _buildDnaRatingsCard(bool isDark) {
    int planned = _items.where((i) => i.category == AnimeCategory.planned).length;
    int ignored = _items.where((i) => i.category == AnimeCategory.ignored).length;
    int totalAll = _watching + _totalCompleted + planned + ignored;

    double watchingVal = totalAll > 0 ? (_watching / totalAll) * 10 : 0.0;
    double completedVal = totalAll > 0 ? (_totalCompleted / totalAll) * 10 : 0.0;
    double plannedVal = totalAll > 0 ? (planned / totalAll) * 10 : 0.0;
    double ignoredVal = totalAll > 0 ? (ignored / totalAll) * 10 : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DnaRadarChart(
              customValues: [watchingVal, completedVal, plannedVal, ignoredVal],
              customLabels: [
                'Watching ($_watching)',
                'Completed ($_totalCompleted)',
                'Planned ($planned)',
                'Ignored ($ignored)',
              ],
            ),
          ],
        ),
      ),
    );
  }
}
