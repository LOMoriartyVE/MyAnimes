import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/models/anime_list_item.dart';
import '../core/models/anime_model.dart';
import '../widgets/dna_radar_chart.dart';
import '../core/services/jikan_service.dart';
import 'anime_wrapped_page.dart';

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
  String _topStudio = "Unknown Studio";
  
  // DNA Ratings state
  double _dnaCompleteness = 0.0;
  double _dnaVariety = 0.0;
  double _dnaActivity = 0.0;
  double _dnaUniqueness = 0.0;
  double _dnaEngagement = 0.0;
  
  Map<String, int> _genreCounts = {};
  Map<String, int> _allGenreCounts = {};
  Map<int, int> _ratingDist = {};
  String _activityPeriod = '7d';
  String _statusDistFilter = 'all'; // 'all', 'watching', 'completed'
  Map<int, int> _cachedYears = {};

  @override
  void initState() {
    super.initState();
    _items = HiveService.getAllListItems();
    _cachedYears = HiveService.getAllCachedAnimeYears();
    _calculateStats();
    _checkMissingCompletedStudios();
  }

  int? _extractYear(String? yearStr) {
    if (yearStr == null || yearStr.isEmpty || yearStr.toLowerCase() == 'unknown') return null;
    final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(yearStr);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  int? _resolveYearForItem(AnimeListItem item) {
    int? year = _extractYear(item.year);
    if (year != null) return year;

    year = _extractYear(item.season);
    if (year != null) return year;

    if (_cachedYears.containsKey(item.animeId)) {
      return _cachedYears[item.animeId];
    }

    final cached = HiveService.getCachedAnimeDetail(item.animeId);
    if (cached != null) {
      try {
        year = _extractYear(cached['year']?.toString()) ??
               _extractYear(cached['aired']?['prop']?['from']?['year']?.toString()) ??
               _extractYear(cached['aired']?['from']?.toString()) ??
               _extractYear(cached['aired']?['string']?.toString()) ??
               _extractYear(cached['season']?.toString());
        if (year != null) {
          _cachedYears[item.animeId] = year;
          return year;
        }
      } catch (_) {}
    }

    final mangaCached = HiveService.getCachedMangaDetail(item.animeId);
    if (mangaCached != null) {
      try {
        year = _extractYear(mangaCached['published']?['prop']?['from']?['year']?.toString()) ??
               _extractYear(mangaCached['published']?['from']?.toString()) ??
               _extractYear(mangaCached['published']?['string']?.toString());
        if (year != null) {
          _cachedYears[item.animeId] = year;
          return year;
        }
      } catch (_) {}
    }

    year = _extractYear(item.title);
    if (year != null) return year;

    return null;
  }

  List<String> _resolveStudiosForItem(AnimeListItem item) {
    if (item.studios != null && item.studios!.isNotEmpty) {
      final valid = item.studios!.where((s) {
        final t = s.trim().toLowerCase();
        return t.isNotEmpty && t != 'unknown' && t != 'unknown studio' && t != 'none' && t != 'n/a';
      }).toList();
      if (valid.isNotEmpty) return valid;
    }

    final cached = HiveService.getCachedAnimeDetail(item.animeId);
    if (cached != null) {
      try {
        final anime = AnimeModel.fromJson(cached);
        final valid = anime.studios.where((s) {
          final t = s.trim().toLowerCase();
          return t.isNotEmpty && t != 'unknown' && t != 'unknown studio' && t != 'none' && t != 'n/a';
        }).toList();
        if (valid.isNotEmpty) return valid;
      } catch (_) {}
    }

    return [];
  }

  Future<void> _checkMissingCompletedStudios() async {
    await HiveService.healListItemsMetadata();
    _items = HiveService.getAllListItems();
    _cachedYears = HiveService.getAllCachedAnimeYears();
    
    // Auto-resolve years for all items that can be resolved from title/season/cache and save to Hive
    bool anySaved = false;
    for (final item in _items) {
      if (item.year == null || item.year == 'Unknown' || item.year!.isEmpty) {
        final y = _resolveYearForItem(item);
        if (y != null) {
          final updatedItem = AnimeListItem(
            animeId: item.animeId,
            title: item.title,
            image: item.image,
            score: item.score,
            genres: item.genres,
            category: item.category,
            addedAt: item.addedAt,
            userRating: item.userRating,
            episodes: item.episodes,
            episodeProgress: item.episodeProgress,
            type: item.type,
            studios: item.studios,
            year: y.toString(),
            rank: item.rank,
            popularity: item.popularity,
            season: item.season,
            isMalSynced: item.isMalSynced,
          );
          await HiveService.saveListItemDirectly(updatedItem);
          anySaved = true;
        }
      }
    }
    if (anySaved) {
      _items = HiveService.getAllListItems();
    }

    final missing = _items.where((i) => _resolveStudiosForItem(i).isEmpty || _resolveYearForItem(i) == null).toList();
    if (missing.isEmpty) {
      if (mounted) {
        setState(() {
          _calculateStats();
        });
      }
      return;
    }

    bool anyUpdated = false;
    for (final item in missing) {
      try {
        var cached = HiveService.getCachedAnimeDetail(item.animeId);
        List<String> studios = [];
        String? year;
        if (cached != null) {
          final anime = AnimeModel.fromJson(cached);
          studios = anime.studios;
          year = anime.year;
        } else {
          final details = await JikanService.getAnimeById(item.animeId);
          studios = details.studios;
          year = details.year;
          await Future.delayed(const Duration(milliseconds: 300));
        }

        final validStudios = studios.where((s) {
          final t = s.trim().toLowerCase();
          return t.isNotEmpty && t != 'unknown' && t != 'unknown studio' && t != 'none' && t != 'n/a';
        }).toList();

        final resolvedY = (year != null && year != 'Unknown') ? year : (_resolveYearForItem(item)?.toString());

        if (validStudios.isNotEmpty || (resolvedY != null && resolvedY != 'Unknown')) {
          final updatedItem = AnimeListItem(
            animeId: item.animeId,
            title: item.title,
            image: item.image,
            score: item.score,
            genres: item.genres.isNotEmpty ? item.genres : (cached != null ? AnimeModel.fromJson(cached).genres : item.genres),
            category: item.category,
            addedAt: item.addedAt,
            userRating: item.userRating,
            episodes: item.episodes,
            episodeProgress: item.episodeProgress,
            type: item.type,
            studios: validStudios.isNotEmpty ? validStudios : item.studios,
            year: (resolvedY != null && resolvedY != 'Unknown') ? resolvedY : item.year,
            rank: item.rank,
            popularity: item.popularity,
            season: item.season,
            isMalSynced: item.isMalSynced,
          );
          await HiveService.saveListItemDirectly(updatedItem);
          anyUpdated = true;
        }
      } catch (_) {}
    }

    if (mounted) {
      _cachedYears = HiveService.getAllCachedAnimeYears();
      setState(() {
        _items = HiveService.getAllListItems();
        _calculateStats();
      });
    }
  }

  void _calculateStats() {
    int totalMinutes = 0;
    double sumRating = 0.0;
    int ratedCount = 0;
    Map<String, Set<int>> studioDistinctTitles = {};
    Map<String, int> studioEpisodeCounts = {};
    _genreCounts.clear();
    _allGenreCounts.clear();
    _ratingDist.clear();
    _totalEpisodes = 0;
    _watching = 0;
    _totalCompleted = 0;
    
    for (final item in _items) {
      int itemEpisodesWatched = 0;
      if (item.episodeProgress > 0) {
        totalMinutes += item.episodeProgress * 23;
        _totalEpisodes += item.episodeProgress;
        itemEpisodesWatched = item.episodeProgress;
      }
      if (item.category == AnimeCategory.watching) _watching++;
      if (item.category == AnimeCategory.completed) {
        _totalCompleted++;
        if (itemEpisodesWatched == 0) {
          final parsed = int.tryParse(item.episodes) ??
              int.tryParse(item.episodes.replaceAll(RegExp(r'[^0-9]'), '')) ??
              12;
          itemEpisodesWatched = parsed > 0 ? parsed : 12;
        }
      }

      // Studio tracking: distinct titles in collection + episodes watched
      final studios = _resolveStudiosForItem(item);
      for (final studio in studios) {
        final s = studio.trim();
        final lower = s.toLowerCase();
        if (lower.isNotEmpty && lower != 'unknown' && lower != 'unknown studio' && lower != 'none' && lower != 'n/a') {
          studioDistinctTitles.putIfAbsent(s, () => <int>{}).add(item.animeId);
          if (itemEpisodesWatched > 0) {
            studioEpisodeCounts[s] = (studioEpisodeCounts[s] ?? 0) + itemEpisodesWatched;
          }
        }
      }

      // Average User Ratings
      if (item.userRating != null && item.userRating!.hasRating) {
        sumRating += item.userRating!.overall;
        ratedCount++;
        
        int r = item.userRating!.overall.round();
        if (r > 0) {
           _ratingDist[r] = (_ratingDist[r] ?? 0) + 1;
        }
      }

      // Genres
      for (final g in item.genres) {
        _allGenreCounts[g] = (_allGenreCounts[g] ?? 0) + 1;
      }
    }

    _totalHours = totalMinutes ~/ 60;
    _timeSpentDays = totalMinutes / (60 * 24);
    _averageRating = ratedCount > 0 ? (sumRating / ratedCount) : 0.0;
    _completionRate = _items.isNotEmpty ? (_totalCompleted / _items.length * 100) : 0.0;

    // Determine Top Studio by distinct anime titles in collection (tie-break by episodes watched)
    String bestStudio = "Unknown Studio";
    int maxTitles = 0;
    int maxEpisodes = 0;
    studioDistinctTitles.forEach((studio, titlesSet) {
      final titles = titlesSet.length;
      final eps = studioEpisodeCounts[studio] ?? 0;
      if (titles > maxTitles || (titles == maxTitles && eps > maxEpisodes)) {
        maxTitles = titles;
        maxEpisodes = eps;
        bestStudio = studio;
      }
    });
    _topStudio = bestStudio;

    // Sort to keep top 6 genres (without mentioning others in chart)
    var sortedGenres = _allGenreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    _genreCounts = {};
    for (int i = 0; i < sortedGenres.length && i < 6; i++) {
      _genreCounts[sortedGenres[i].key] = sortedGenres[i].value;
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
        actions: [
          IconButton(
            icon: Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
            tooltip: 'Anime Wrapped',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnimeWrappedPage()),
              );
            },
          ),
        ],
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
    List<FlSpot> spots = [];
    List<String> xLabels = [];
    int totalPeriodEpisodes = 0;
    int maxActivity = 0;

    final episodeLogs = HiveService.getEpisodeActivityLogs();

    if (_activityPeriod == '7d') {
      final List<DateTime> last7Days = List.generate(7, (i) {
        return DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
      });

      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (int i = 0; i < 7; i++) {
        final date = last7Days[i];
        final key = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        int count = episodeLogs[key] ?? 0;

        totalPeriodEpisodes += count;
        if (count > maxActivity) maxActivity = count;
        spots.add(FlSpot(i.toDouble(), count.toDouble()));
        xLabels.add(weekdays[date.weekday - 1]);
      }
    } else if (_activityPeriod == '30d') {
      final List<DateTime> periodDates = List.generate(6, (i) {
        return DateTime(now.year, now.month, now.day).subtract(Duration(days: (5 - i) * 5));
      });

      final List<int> bucketCounts = List.filled(6, 0);
      final thirtyDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));

      episodeLogs.forEach((dateStr, count) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2]);
          if (y != null && m != null && d != null) {
            final date = DateTime(y, m, d);
            if (date.isAfter(thirtyDaysAgo) || date.isAtSameMomentAs(thirtyDaysAgo)) {
              final diffDays = now.difference(date).inDays;
              if (diffDays >= 0 && diffDays <= 30) {
                totalPeriodEpisodes += count;
                int bucket = 5 - (diffDays ~/ 5);
                if (bucket < 0) bucket = 0;
                if (bucket > 5) bucket = 5;
                bucketCounts[bucket] += count;
              }
            }
          }
        }
      });

      for (int i = 0; i < 6; i++) {
        final count = bucketCounts[i];
        if (count > maxActivity) maxActivity = count;
        spots.add(FlSpot(i.toDouble(), count.toDouble()));
        final date = periodDates[i];
        xLabels.add("${date.month}/${date.day}");
      }
    } else if (_activityPeriod == '12m') {
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final List<DateTime> months = List.generate(12, (i) {
        return DateTime(now.year, now.month - (11 - i), 1);
      });

      final List<int> monthCounts = List.filled(12, 0);

      episodeLogs.forEach((dateStr, count) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (y != null && m != null) {
            for (int i = 0; i < 12; i++) {
              final mon = months[i];
              if (y == mon.year && m == mon.month) {
                monthCounts[i] += count;
                totalPeriodEpisodes += count;
                break;
              }
            }
          }
        }
      });

      for (int i = 0; i < 12; i++) {
        final count = monthCounts[i];
        if (count > maxActivity) maxActivity = count;
        spots.add(FlSpot(i.toDouble(), count.toDouble()));
        xLabels.add(monthNames[months[i].month - 1]);
      }
    } else {
      // 5 years
      final startYear = now.year - 4;
      final List<int> yearCounts = List.filled(5, 0);

      episodeLogs.forEach((dateStr, count) {
        final parts = dateStr.split('-');
        if (parts.isNotEmpty) {
          final y = int.tryParse(parts[0]);
          if (y != null) {
            final idx = y - startYear;
            if (idx >= 0 && idx < 5) {
              yearCounts[idx] += count;
              totalPeriodEpisodes += count;
            }
          }
        }
      });

      for (int i = 0; i < 5; i++) {
        final count = yearCounts[i];
        if (count > maxActivity) maxActivity = count;
        spots.add(FlSpot(i.toDouble(), count.toDouble()));
        xLabels.add('${startYear + i}');
      }
    }

    // Fallback only if user has literally 0 items in their library
    if (_items.isEmpty && spots.every((s) => s.y == 0.0)) {
      spots = [
        const FlSpot(0, 0),
        const FlSpot(1, 1),
        const FlSpot(2, 0),
        const FlSpot(3, 2),
        const FlSpot(4, 1),
        const FlSpot(5, 3),
        const FlSpot(6, 0),
      ];
      maxActivity = 3;
      xLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    }

    final double maxX = (spots.length - 1).toDouble();
    final double maxY = maxActivity > 0 ? (maxActivity + 1).toDouble() : 4.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalPeriodEpisodes episodes watched',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPeriodChip('7d', '7D', isDark),
                      _buildPeriodChip('30d', '30D', isDark),
                      _buildPeriodChip('12m', '12M', isDark),
                      _buildPeriodChip('5y', '5Y', isDark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                          if (idx >= 0 && idx < xLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                xLabels[idx],
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
                  maxX: maxX,
                  minY: 0,
                  maxY: maxY,
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

  Widget _buildPeriodChip(String periodKey, String label, bool isDark) {
    final isSelected = _activityPeriod == periodKey;
    return InkWell(
      onTap: () {
        if (_activityPeriod != periodKey) {
          setState(() {
            _activityPeriod = periodKey;
          });
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minWidth: 42, minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.brandGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
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

    final hasMoreGenres = _allGenreCounts.length > _genreCounts.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Genre Distribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (hasMoreGenres)
                  TextButton.icon(
                    onPressed: () => _showAllGenresModal(context, isDark),
                    icon: const Icon(Icons.grid_view_rounded, size: 14),
                    label: const Text('Show All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
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
            ),
            if (hasMoreGenres) ...[
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => _showAllGenresModal(context, isDark),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text('Show All ${_allGenreCounts.length} Genres', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ]
          ]
        )
      )
    );
  }

  void _showAllGenresModal(BuildContext context, bool isDark) {
    final allSorted = _allGenreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'All Genres Breakdown (${allSorted.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: allSorted.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = allSorted[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('#${idx + 1} ${item.key}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${item.value} animes',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    final filtered = _items.where((item) {
      if (_statusDistFilter == 'watching') {
        return item.category == AnimeCategory.watching;
      } else if (_statusDistFilter == 'completed') {
        return item.category == AnimeCategory.completed;
      }
      return true;
    }).toList();

    int count80s = 0;
    int count90s = 0;
    int count2000s = 0;
    int count2010s = 0;
    int count2020s = 0;
    int resolvedTotal = 0;

    for (final item in filtered) {
      final year = _resolveYearForItem(item);
      if (year != null) {
        resolvedTotal++;
        if (year < 1990) {
          count80s++;
        } else if (year <= 1999) {
          count90s++;
        } else if (year <= 2009) {
          count2000s++;
        } else if (year <= 2019) {
          count2010s++;
        } else {
          count2020s++;
        }
      }
    }

    final allCounts = [count80s, count90s, count2000s, count2010s, count2020s];
    int maxCount = allCounts.fold(0, (max, val) => val > max ? val : max);
    if (maxCount == 0) maxCount = 1;

    double val80s = (count80s / maxCount) * 10.0;
    double val90s = (count90s / maxCount) * 10.0;
    double val2000s = (count2000s / maxCount) * 10.0;
    double val2010s = (count2010s / maxCount) * 10.0;
    double val2020s = (count2020s / maxCount) * 10.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Distribution',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${filtered.length} anime ($resolvedTotal with year)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDistFilterChip('All', 'all', isDark),
                      _buildDistFilterChip('Watching', 'watching', isDark),
                      _buildDistFilterChip('Completed', 'completed', isDark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DnaRadarChart(
              titleFontSize: 11,
              customValues: [val80s, val90s, val2000s, val2010s, val2020s],
              customLabels: [
                '80s & Earlier ($count80s)',
                '90s ($count90s)',
                '2000s ($count2000s)',
                '2010s ($count2010s)',
                '2020s ($count2020s)',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistFilterChip(String label, String value, bool isDark) {
    final isSelected = _statusDistFilter == value;
    return InkWell(
      onTap: () {
        if (_statusDistFilter != value) {
          setState(() {
            _statusDistFilter = value;
          });
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.brandGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}
