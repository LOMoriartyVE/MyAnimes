import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_list_item.dart';
import '../core/models/anime_model.dart';
import '../core/services/hive_service.dart';
import '../core/services/mal_auth_service.dart';
import '../widgets/wrapped_share_dialog.dart';

class StudioWrappedStat {
  final String name;
  final int titlesInYearCount;
  final int totalTitlesCount;
  final int episodesWatched;

  StudioWrappedStat({
    required this.name,
    required this.titlesInYearCount,
    required this.totalTitlesCount,
    required this.episodesWatched,
  });
}

class AnimeWrappedPage extends StatefulWidget {
  final int? targetYear;

  const AnimeWrappedPage({super.key, this.targetYear});

  @override
  State<AnimeWrappedPage> createState() => _AnimeWrappedPageState();
}

class _AnimeWrappedPageState extends State<AnimeWrappedPage> {
  final PageController _pageController = PageController();
  final FocusNode _focusNode = FocusNode();
  int _currentPage = 0;
  final int _totalPages = 5;

  late List<AnimeListItem> _allItems;
  int _totalEpisodes = 0;
  int _totalHours = 0;
  double _totalDays = 0.0;
  int _completedCount = 0;
  int _watchingCount = 0;
  double _completionRate = 0.0;

  List<MapEntry<String, int>> _topGenres = [];
  List<StudioWrappedStat> _topStudios = [];
  List<AnimeListItem> _topRated = [];
  String _personaTitle = "Anime Connoisseur";
  String _personaDescription = "A well-rounded fan with a versatile taste across genres.";
  IconData _personaIcon = Icons.auto_awesome;

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int? _resolveYearForItem(AnimeListItem item) {
    if (item.year != null && item.year != 'Unknown' && item.year!.isNotEmpty) {
      final y = int.tryParse(item.year!.replaceAll(RegExp(r'[^0-9]'), ''));
      if (y != null && y > 1950 && y < 2100) return y;
    }
    if (item.season != null && item.season!.isNotEmpty) {
      final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(item.season!);
      if (match != null) {
        final y = int.tryParse(match.group(1)!);
        if (y != null) return y;
      }
    }
    final cached = HiveService.getCachedAnimeDetail(item.animeId);
    if (cached != null) {
      try {
        final airedYear = cached['aired']?['prop']?['from']?['year'];
        if (airedYear != null && airedYear is int) return airedYear;
        final rawY = cached['year'];
        if (rawY != null && rawY is int) return rawY;
      } catch (_) {}
    }
    if (item.addedAt.year > 2000) {
      return item.addedAt.year;
    }
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

  void _calculateStats() {
    _allItems = HiveService.getAllListItems();
    final year = widget.targetYear ?? DateTime.now().year;

    _totalEpisodes = 0;
    _completedCount = 0;
    _watchingCount = 0;

    final genreMap = <String, int>{};
    final studioYearTitles = <String, Set<int>>{};
    final studioTotalTitles = <String, Set<int>>{};
    final studioEpisodeCounts = <String, int>{};

    for (final item in _allItems) {
      _totalEpisodes += item.episodeProgress;
      if (item.category == AnimeCategory.completed) _completedCount++;
      if (item.category == AnimeCategory.watching) _watchingCount++;

      for (final g in item.genres) {
        genreMap[g] = (genreMap[g] ?? 0) + 1;
      }

      int itemEpisodesWatched = item.episodeProgress;
      if (item.category == AnimeCategory.completed && itemEpisodesWatched == 0) {
        final parsed = int.tryParse(item.episodes) ??
            int.tryParse(item.episodes.replaceAll(RegExp(r'[^0-9]'), '')) ??
            12;
        itemEpisodesWatched = parsed > 0 ? parsed : 12;
      }

      final itemYear = _resolveYearForItem(item);
      final isInYear = (itemYear == year);

      final studios = _resolveStudiosForItem(item);
      for (final s in studios) {
        final clean = s.trim();
        studioTotalTitles.putIfAbsent(clean, () => <int>{}).add(item.animeId);
        if (isInYear) {
          studioYearTitles.putIfAbsent(clean, () => <int>{}).add(item.animeId);
        }
        studioEpisodeCounts[clean] = (studioEpisodeCounts[clean] ?? 0) + itemEpisodesWatched;
      }
    }

    // 24 minutes average episode length
    _totalHours = (_totalEpisodes * 24) ~/ 60;
    _totalDays = (_totalHours / 24.0);
    _completionRate = _allItems.isNotEmpty ? (_completedCount / _allItems.length) * 100 : 0.0;

    _topGenres = genreMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    final studioList = studioTotalTitles.keys.map((name) {
      return StudioWrappedStat(
        name: name,
        titlesInYearCount: studioYearTitles[name]?.length ?? 0,
        totalTitlesCount: studioTotalTitles[name]?.length ?? 0,
        episodesWatched: studioEpisodeCounts[name] ?? 0,
      );
    }).toList();

    // Ranked by number of distinct anime titles in user collection for this year (tie-break by total collection titles, then eps)
    studioList.sort((a, b) {
      final cmpYear = b.titlesInYearCount.compareTo(a.titlesInYearCount);
      if (cmpYear != 0) return cmpYear;
      final cmpTotal = b.totalTitlesCount.compareTo(a.totalTitlesCount);
      if (cmpTotal != 0) return cmpTotal;
      return b.episodesWatched.compareTo(a.episodesWatched);
    });
    _topStudios = studioList;

    // Top rated items
    final rated = _allItems.where((i) => i.userRating != null && i.userRating!.overall > 0).toList();
    rated.sort((a, b) => b.userRating!.overall.compareTo(a.userRating!.overall));
    _topRated = rated.take(5).toList();

    // Determine Anime Persona
    if (_totalEpisodes > 500) {
      _personaTitle = "Marathon Binger";
      _personaDescription = "You devour seasons in single sittings. Anime is basically your second life!";
      _personaIcon = Icons.bolt_rounded;
    } else if (_topGenres.isNotEmpty) {
      final topG = _topGenres.first.key.toLowerCase();
      if (topG.contains('action') || topG.contains('shounen') || topG.contains('shonen')) {
        _personaTitle = "Shonen Titan";
        _personaDescription = "Fueled by hype battles, power systems, and unforgettable training arcs.";
        _personaIcon = Icons.local_fire_department_rounded;
      } else if (topG.contains('romance') || topG.contains('drama')) {
        _personaTitle = "Hopeless Romantic";
        _personaDescription = "You feel every confession, heartbreak, and emotional rollercoaster deeply.";
        _personaIcon = Icons.favorite_rounded;
      } else if (topG.contains('slice of life') || topG.contains('comedy')) {
        _personaTitle = "Comfort Seeker";
        _personaDescription = "Wholesome moments, laughs, and cozy vibes are your ultimate therapy.";
        _personaIcon = Icons.wb_sunny_rounded;
      } else if (topG.contains('fantasy') || topG.contains('adventure') || topG.contains('isekai')) {
        _personaTitle = "Otherworld Explorer";
        _personaDescription = "Always searching for another world to discover and magical realms to conquer.";
        _personaIcon = Icons.explore_rounded;
      } else if (topG.contains('sci-fi') || topG.contains('psychological') || topG.contains('mystery')) {
        _personaTitle = "Mind Bender";
        _personaDescription = "Complex plots, deep philosophical questions, and twists keep you hooked.";
        _personaIcon = Icons.psychology_rounded;
      }
    }
  }

  void _shareWrapped() {
    HapticFeedback.mediumImpact();
    final year = widget.targetYear ?? DateTime.now().year;
    WrappedShareDialog.show(
      context,
      year: year,
      totalEpisodes: _totalEpisodes,
      totalHours: _totalHours,
      totalDays: _totalDays,
      completedCount: _completedCount,
      completionRate: _completionRate,
      personaTitle: _personaTitle,
      personaDescription: _personaDescription,
      personaIcon: _personaIcon,
      topGenres: _topGenres,
      topStudios: _topStudios,
      topRated: _topRated,
    );
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      HapticFeedback.selectionClick();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      HapticFeedback.selectionClick();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = widget.targetYear ?? DateTime.now().year;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 720 || Platform.isWindows;

    return Scaffold(
      backgroundColor: const Color(0xFF090A10),
      body: Stack(
        children: [
          // Background ambient gradient glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.mauve.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Story Swiper & Desktop Frame
          Center(
            child: KeyboardListener(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: (KeyEvent event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                      event.logicalKey == LogicalKeyboardKey.space) {
                    _nextPage();
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _prevPage();
                  } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Desktop Previous Arrow
                  if (isDesktop)
                    Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 28),
                        color: _currentPage > 0 ? Colors.white70 : Colors.white12,
                        onPressed: _currentPage > 0 ? _prevPage : null,
                        tooltip: 'Previous [←]',
                      ),
                    ),

                  // Center Story Canvas
                  Container(
                    width: isDesktop ? 540 : double.infinity,
                    height: isDesktop ? (size.height > 860 ? 800 : size.height * 0.94) : double.infinity,
                    margin: isDesktop ? const EdgeInsets.symmetric(vertical: 20) : EdgeInsets.zero,
                    decoration: isDesktop
                        ? BoxDecoration(
                            color: const Color(0xFF10121D).withOpacity(0.92),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                              BoxShadow(
                                color: AppColors.accent.withOpacity(0.18),
                                blurRadius: 50,
                              ),
                            ],
                          )
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isDesktop ? 24 : 0),
                      child: SafeArea(
                        child: Column(
                          children: [
                            // Top Navigation Bar
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  // Story Page Indicators
                                  Expanded(
                                    child: Row(
                                      children: List.generate(_totalPages, (index) {
                                        final isActive = index == _currentPage;
                                        return Expanded(
                                          child: Container(
                                            height: 3.5,
                                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? Colors.white
                                                  : (index < _currentPage ? Colors.white70 : Colors.white24),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
                                    onPressed: () => Navigator.of(context).pop(),
                                    tooltip: 'Close [Esc]',
                                  ),
                                ],
                              ),
                            ),

                            // Story Content View
                            Expanded(
                              child: PageView(
                                controller: _pageController,
                                onPageChanged: (page) => setState(() => _currentPage = page),
                                children: [
                                  _buildOverviewSlide(year),
                                  _buildGenresSlide(),
                                  _buildStudiosSlide(year),
                                  _buildHallOfFameSlide(),
                                  _buildPersonaSlide(year),
                                ],
                              ),
                            ),

                            // Bottom Action Bar
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (_currentPage > 0)
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 20),
                                      onPressed: _prevPage,
                                    )
                                  else
                                    const SizedBox(width: 48),

                                  if (isDesktop)
                                    Text(
                                      '${_currentPage + 1} / $_totalPages',
                                      style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),

                                  if (_currentPage == _totalPages - 1)
                                    ElevatedButton.icon(
                                      onPressed: _shareWrapped,
                                      icon: const Icon(Icons.share_rounded, size: 18),
                                      label: const Text(
                                        'Share Story Card',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                    )
                                  else
                                    TextButton(
                                      onPressed: _nextPage,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Next', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                          SizedBox(width: 6),
                                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Desktop Next Arrow
                  if (isDesktop)
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 28),
                        color: _currentPage < _totalPages - 1 ? Colors.white70 : Colors.white12,
                        onPressed: _currentPage < _totalPages - 1 ? _nextPage : null,
                        tooltip: 'Next [→]',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Slide 1: Journey Overview ──
  Widget _buildOverviewSlide(int year) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withOpacity(0.5)),
              ),
              child: Text(
                'YEAR IN REVIEW $year',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Anime\nJourney',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 20),

            // Big Stat 1: Episodes
            _buildStatCard(
              icon: Icons.tv_rounded,
              color: AppColors.watching,
              value: '$_totalEpisodes',
              label: 'Total Episodes Watched',
              subtitle: 'Across all titles in your personal log',
            ),
            const SizedBox(height: 12),

            // Big Stat 2: Hours / Days
            _buildStatCard(
              icon: Icons.access_time_filled_rounded,
              color: AppColors.accent,
              value: '${_totalHours}h',
              label: '${_totalDays.toStringAsFixed(1)} Days Spent Watching',
              subtitle: 'Over 24 minutes average per episode',
            ),
            const SizedBox(height: 12),

            // Big Stat 3: Completed
            _buildStatCard(
              icon: Icons.check_circle_rounded,
              color: AppColors.completed,
              value: '$_completedCount',
              label: 'Completed Anime (${_completionRate.toStringAsFixed(0)}% finish rate)',
              subtitle: '$_watchingCount currently in progress',
            ),
          ],
        ),
      ),
    );
  }

  // ── Slide 2: Top Genres ──
  Widget _buildGenresSlide() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GENRE VIBES',
              style: TextStyle(
                color: AppColors.mauve,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'What Kept You\nHooked',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 24),

            if (_topGenres.isEmpty)
              const Text('No genres logged yet.', style: TextStyle(color: Colors.white60))
            else
              ..._topGenres.take(5).toList().asMap().entries.map((entry) {
                final idx = entry.key;
                final g = entry.value;
                final maxCount = _topGenres.first.value;
                final ratio = maxCount > 0 ? (g.value / maxCount) : 0.0;
                final colors = [
                  AppColors.accent,
                  AppColors.watching,
                  AppColors.mauve,
                  AppColors.completed,
                  AppColors.starYellow,
                ];
                final barColor = colors[idx % colors.length];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '#${idx + 1}  ${g.key}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${g.value} shows',
                            style: TextStyle(
                              color: barColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ── Slide 3: Top Studios ──
  Widget _buildStudiosSlide(int year) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ANIMATION HOUSE',
              style: TextStyle(
                color: AppColors.watching,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Favorite\nStudios',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 24),

            if (_topStudios.isEmpty)
              const Text('No studio data recorded yet.', style: TextStyle(color: Colors.white60))
            else
              ..._topStudios.take(4).toList().asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final s = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: rank == 1 ? AppColors.starYellow.withOpacity(0.2) : Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            color: rank == 1 ? AppColors.starYellow : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              s.titlesInYearCount > 0
                                  ? '${s.titlesInYearCount} anime in $year (${s.totalTitlesCount} in collection)'
                                  : '${s.totalTitlesCount} in collection (${s.episodesWatched} eps watched)',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        rank == 1 ? Icons.emoji_events_rounded : Icons.movie_filter_rounded,
                        color: rank == 1 ? AppColors.starYellow : Colors.white38,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ── Slide 4: Hall of Fame (Top Rated) ──
  Widget _buildHallOfFameSlide() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HALL OF FAME',
              style: TextStyle(
                color: AppColors.starYellow,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your Highest\nRated Masterpieces',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 20),

            if (_topRated.isEmpty)
              const Text(
                'No user ratings found yet. Rate anime in My List to see your Hall of Fame!',
                style: TextStyle(color: Colors.white60),
              )
            else
              ..._topRated.take(3).map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: item.image,
                          width: 50,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.genres.take(2).join(' • '),
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            if (item.personalNotes != null && item.personalNotes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '"${item.personalNotes!}"',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.starYellow.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: AppColors.starYellow),
                            const SizedBox(width: 3),
                            Text(
                              item.userRating!.overall.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppColors.starYellow,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ── Slide 5: Anime Persona ──
  Widget _buildPersonaSlide(int year) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'YOUR ANIME PERSONA',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 18),

            // Glowing Persona / Profile Image Emblem
            Builder(builder: (context) {
              final pic = HiveService.malUserPicture;
              final user = HiveService.malUsername;
              final hasPic = (pic != null && pic.trim().isNotEmpty);

              return Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.accent, width: 3),
                          gradient: AppColors.brandGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.5),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: hasPic
                              ? CachedNetworkImage(
                                  imageUrl: pic!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: Colors.white10),
                                  errorWidget: (_, __, ___) => Icon(_personaIcon, color: Colors.white, size: 48),
                                )
                              : Icon(_personaIcon, color: Colors.white, size: 48),
                        ),
                      ),
                      if (hasPic)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.brandGradient,
                              border: Border.all(color: AppColors.darkBg, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(_personaIcon, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (user != null && user.trim().isNotEmpty) ...[
                    Text(
                      user,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              );
            }),

            Text(
              _personaTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _personaDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Mini recap pill stats
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPersonaPillStat('Episodes', '$_totalEpisodes'),
                  Container(width: 1, height: 28, color: Colors.white24),
                  _buildPersonaPillStat('Completed', '$_completedCount'),
                  Container(width: 1, height: 28, color: Colors.white24),
                  _buildPersonaPillStat('Top Genre', _topGenres.isNotEmpty ? _topGenres.first.key : 'Anime'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaPillStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  // ── High-Res Minimal Long Share Card (Captured by RepaintBoundary) ──
  Widget _buildMinimalLongShareCard(int year) {
    return Container(
      width: 400,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF141724),
            Color(0xFF0C0E14),
            Color(0xFF10131E),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.35),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/MA_logo.png', fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'MY ANIMES',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                ),
                child: Text(
                  'WRAPPED $year',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // Profile Image & Persona Emblem
          Builder(builder: (context) {
            final malPic = HiveService.malUserPicture;
            final malUsername = HiveService.malUsername;
            final hasPic = (malPic != null && malPic.trim().isNotEmpty);

            return Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accent.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                        border: Border.all(color: AppColors.accent, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.35),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: hasPic
                            ? CachedNetworkImage(
                                imageUrl: malPic!,
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.white10),
                                errorWidget: (_, __, ___) => Icon(_personaIcon, size: 42, color: Colors.white),
                              )
                            : Icon(_personaIcon, size: 42, color: Colors.white),
                      ),
                    ),
                    if (hasPic)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.brandGradient,
                            border: Border.all(color: const Color(0xFF0C0E14), width: 2),
                          ),
                          child: Icon(_personaIcon, size: 14, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (malUsername != null && malUsername.trim().isNotEmpty) ...[
                  Text(
                    malUsername,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  _personaTitle.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '"$_personaDescription"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                height: 1.3,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Stats 2x2 Grid
          Row(
            children: [
              Expanded(
                child: _buildShareStatTile(
                  icon: Icons.play_circle_filled_rounded,
                  color: AppColors.watching,
                  title: '$_totalEpisodes eps',
                  subtitle: '${_totalHours}h / ${_totalDays.toStringAsFixed(0)}d watched',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildShareStatTile(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.completed,
                  title: '$_completedCount shows',
                  subtitle: '${_completionRate.toStringAsFixed(0)}% finish rate',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildShareStatTile(
                  icon: Icons.category_rounded,
                  color: AppColors.planned,
                  title: _topGenres.isNotEmpty ? _topGenres.first.key : 'Anime',
                  subtitle: 'Top Genre',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildShareStatTile(
                  icon: Icons.home_work_rounded,
                  color: AppColors.starYellow,
                  title: _topStudios.isNotEmpty ? _topStudios.first.name : 'Top Studio',
                  subtitle: _topStudios.isNotEmpty
                      ? (_topStudios.first.titlesInYearCount > 0
                          ? '${_topStudios.first.titlesInYearCount} in $year'
                          : '${_topStudios.first.totalTitlesCount} in collection')
                      : 'Favorite Studio',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Top 5 Genres Bars
          if (_topGenres.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOP 5 GENRES',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._topGenres.take(5).toList().asMap().entries.map((entry) {
                    final idx = entry.key;
                    final g = entry.value;
                    final maxCount = _topGenres.first.value;
                    final ratio = maxCount > 0 ? (g.value / maxCount).clamp(0.08, 1.0) : 0.0;
                    final colors = [
                      AppColors.accent,
                      AppColors.watching,
                      AppColors.mauve,
                      AppColors.completed,
                      AppColors.starYellow,
                    ];
                    final barColor = colors[idx % colors.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '#${idx + 1}  ${g.key}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${g.value} shows',
                                style: TextStyle(
                                  color: barColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 5,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(barColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Favorite / Top Rated Anime if available
          if (_topRated.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HIGHEST RATED THIS YEAR',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._topRated.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.starYellow),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.userRating?.overall.toStringAsFixed(1) ?? '',
                          style: const TextStyle(
                            color: AppColors.starYellow,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],



          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.accent.withOpacity(0.8)),
              const SizedBox(width: 6),
              Text(
                'Tracked with MyAnimes Vault',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareStatTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
