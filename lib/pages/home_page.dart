import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_model.dart';
import '../core/services/jikan_service.dart';
import '../core/services/hive_service.dart';
import '../core/localization/app_text.dart';
import '../widgets/horizontal_anime_list.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/error_state.dart';
import '../widgets/category_picker.dart';
import '../core/models/anime_list_item.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/quick_tracker_card.dart';
import 'see_all_page.dart';
import 'manga_detail_page.dart';
import 'detail_page.dart';
import '../widgets/daily_timeline.dart';
import '../widgets/api_status_banner.dart';
import '../core/services/mal_auth_service.dart';

class HomePage extends StatefulWidget {
  final void Function(int animeId) onSelectAnime;
  // Optional: for manga navigation when mounted in MainLayout
  final void Function(int mangaId)? onSelectManga;
  final bool isDesktop;
  final VoidCallback? onSeeAllSchedule;

  const HomePage({
    super.key, 
    required this.onSelectAnime, 
    this.onSelectManga,
    this.isDesktop = false,
    this.onSeeAllSchedule,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<AnimeModel> _seasonal   = [];
  List<AnimeModel> _top        = [];
  List<AnimeModel> _topManga   = [];
  List<Map<String, dynamic>> _topReviews = [];
  List<AnimeModel> _upcoming   = [];
  List<AnimeModel> _recommended = [];
  List<AnimeModel> _userSuggestions = [];
  bool _loading    = true;
  bool _suggestionsLoading = false;
  String? _error;
  bool _apiIsDown  = false;
  
  // Carousel controllers & timer
  final PageController _pageController = PageController();
  int _carouselIndex = 0;
  Timer? _carouselTimer;
  
  // Schedule variables for desktop
  Map<int, List<AnimeModel>> _groupedSchedule = {};
  List<Map<String, dynamic>> _upcomingAnimes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; _apiIsDown = false; });
    try {
      // ── Genres (for recommended) ──
      var genresCache = HiveService.getCachedGenres();
      if (genresCache == null || genresCache.isEmpty) {
        try {
          genresCache = await JikanService.getAnimeGenres();
          if (genresCache.isNotEmpty) await HiveService.cacheGenres(genresCache);
          await Future.delayed(const Duration(milliseconds: 350)); // Rate limit buffer
        } catch (e) {
          genresCache = [];
        }
      }

      String matchGenreIds = '';
      if (genresCache.isNotEmpty) {
        final items = HiveService.getAllListItems();
        Map<String, int> counts = {};
        for (var i in items) {
          for (var g in i.genres) { counts[g] = (counts[g] ?? 0) + 1; }
        }
        var sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        List<int> topIds = [];
        for (var s in sorted.take(3)) {
          final match = genresCache.where((element) => element['name'] == s.key).firstOrNull;
          if (match != null) topIds.add(match['mal_id'] as int);
        }
        if (topIds.isNotEmpty) matchGenreIds = topIds.join(',');
      }

      // ── 1. Seasonal Anime (Handled safely to avoid duplicate API calls) ──
      final cachedSeason = HiveService.getCachedSeasonAllPages();
      if (HiveService.isSeasonAllPagesCacheValid()) {
        if (cachedSeason != null && cachedSeason.isNotEmpty) {
          _seasonal = cachedSeason.map((m) => AnimeModel.fromJson(m)).toList();
        }
      } else {
        // Fallback to expired cache first if available
        if (cachedSeason != null && cachedSeason.isNotEmpty) {
          _seasonal = cachedSeason.map((m) => AnimeModel.fromJson(m)).toList();
        }
        // Then trigger background fetch. It will update UI via setState automatically.
        _fetchAllSeasonPages();
      }

      // Show UI immediately if we have something
      if (mounted && _seasonal.isNotEmpty) {
        if (widget.isDesktop) _computeSchedule();
        setState(() { _loading = false; });
        _startCarouselTimer();
      }

      // ── 2. Top Anime ──
      List<AnimeModel> top = [];
      final cachedTop = HiveService.getCachedTopAnime();
      if (HiveService.isTopAnimeCacheValid()) {
        if (cachedTop != null) top = cachedTop.map((m) => AnimeModel.fromJson(m)).toList();
      }
      if (top.isEmpty) {
        try {
          top = await JikanService.getTopAnime(limit: 15);
          unawaited(HiveService.cacheTopAnime(top.map(_animeToMap).toList()));
          await Future.delayed(const Duration(milliseconds: 350)); // Rate limit buffer
        } catch (e) {
          if (cachedTop != null && cachedTop.isNotEmpty) {
            top = cachedTop.map((m) => AnimeModel.fromJson(m)).toList();
            _apiIsDown = true;
          }
        }
      }
      if (mounted) setState(() { _top = top; _loading = false; });

      // ── 3. Top Manga ──
      List<AnimeModel> topManga = [];
      final cachedTopManga = HiveService.getCachedTopManga();
      if (HiveService.isTopMangaCacheValid()) {
        if (cachedTopManga != null) topManga = cachedTopManga.map((m) => AnimeModel.fromJson(m)).toList();
      }
      if (topManga.isEmpty) {
        try {
          topManga = await JikanService.getTopManga(limit: 15);
          unawaited(HiveService.cacheTopManga(topManga.map(_animeToMap).toList()));
          await Future.delayed(const Duration(milliseconds: 350)); // Rate limit buffer
        } catch (e) {
          if (cachedTopManga != null && cachedTopManga.isNotEmpty) {
            topManga = cachedTopManga.map((m) => AnimeModel.fromJson(m)).toList();
          }
        }
      }
      if (mounted) setState(() => _topManga = topManga);

      // ── 4. Top Reviews ──
      List<Map<String, dynamic>> reviews = [];
      final cachedReviews = HiveService.getCachedTopReviews();
      if (HiveService.isTopReviewsCacheValid()) {
        reviews = cachedReviews ?? [];
      }
      if (reviews.isEmpty) {
        try {
          reviews = await JikanService.getTopReviews(limit: 10);
          unawaited(HiveService.cacheTopReviews(reviews));
          await Future.delayed(const Duration(milliseconds: 350)); // Rate limit buffer
        } catch (e) {
          reviews = cachedReviews ?? [];
        }
      }
      if (mounted) setState(() => _topReviews = reviews);

      // ── 5. Upcoming ──
      List<AnimeModel> upcoming = [];
      final cachedUpcoming = HiveService.getCachedUpcoming();
      if (HiveService.isUpcomingCacheValid()) {
        if (cachedUpcoming != null) upcoming = cachedUpcoming.map((m) => AnimeModel.fromJson(m)).toList();
      }
      if (upcoming.isEmpty) {
        try {
          upcoming = await JikanService.getUpcomingAnime(limit: 15);
          unawaited(HiveService.cacheUpcoming(upcoming.map(_animeToMap).toList()));
          await Future.delayed(const Duration(milliseconds: 350)); // Rate limit buffer
        } catch (e) {
          if (cachedUpcoming != null && cachedUpcoming.isNotEmpty) {
            upcoming = cachedUpcoming.map((m) => AnimeModel.fromJson(m)).toList();
          }
        }
      }
      if (mounted) setState(() => _upcoming = upcoming);

      // ── 6. Recommended (genre-based) ──
      List<AnimeModel> recommended = [];
      if (matchGenreIds.isNotEmpty) {
        try {
          recommended = await JikanService.searchAnime(genres: matchGenreIds, orderBy: 'popularity', limit: 15);
        } catch (e) {
          // Ignore
        }
      }

      List<AnimeModel> suggestions = [];
      if (MalAuthService.instance.isLoggedIn) {
        setState(() => _suggestionsLoading = true);
        try {
          suggestions = await JikanService.getUserSuggestions(limit: 15);
        } catch (e) {
          debugPrint("Failed to fetch user suggestions: $e");
        }
      }

      if (mounted) {
        if (_apiIsDown && (_seasonal.isNotEmpty || _top.isNotEmpty)) {
          JikanService.markUsingCachedData();
        }
        setState(() {
          _recommended = recommended;
          _userSuggestions = suggestions;
          _suggestionsLoading = false;
          _loading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        if (_seasonal.isNotEmpty || _top.isNotEmpty) {
          setState(() { _loading = false; });
        } else {
          setState(() { _error = e.toString(); _loading = false; });
        }
      }
    }
  }

  /// Runs in the background — fetches every season page safely and caches the complete list.
  void _fetchAllSeasonPages({bool silent = false}) {
    JikanService.getSeasonNowAllPages(
      onProgress: (soFar) {
        // Only update UI progressively if we don't already have cached data
        if (mounted && !silent && soFar.length > _seasonal.length) {
          setState(() => _seasonal = soFar);
        }
      },
    ).then((all) async {
      if (all.isNotEmpty) {
        await HiveService.cacheSeasonAllPages(all.map(_animeToMap).toList());
        if (mounted && !silent) {
          if (widget.isDesktop) _computeSchedule();
          setState(() => _seasonal = all);
          _startCarouselTimer();
        }
      }
    }).catchError((e) {
      debugPrint("Background Season Fetch Failed (Likely Rate Limit): $e");
    });
  }
  Map<String, dynamic> _animeToMap(AnimeModel a) => {
    'mal_id': a.id,
    'title': a.title,
    'title_japanese': a.japaneseTitle,
    'images': {'jpg': {'large_image_url': a.image}},
    'score': a.score,
    'synopsis': a.synopsis,
    'genres': a.genres.map((g) => {'name': g}).toList(),
    'status': a.status,
    'rating': a.rating,
    'studios': a.studios.map((s) => {'name': s}).toList(),
    'type': a.type,
    'source': a.source,
    'duration': a.duration,
    'episodes': a.episodes,
    'year': a.year,
    'members': a.members,
    'rank': a.rank,
    'popularity': a.popularity,
    // ✅ ADD THIS SO THE SCHEDULE PAGE CAN SEE THE TIMES!
    'broadcast': {
      'day': a.broadcastDay,
      'time': a.broadcastTime,
    },
  };

  Future<void> _handleAddToList(AnimeModel anime) async {
    final existing = HiveService.getListItem(anime.id);
    final result   = await CategoryPickerSheet.show(context, current: existing?.category);
    if (result == null || !mounted) return;
    switch (result) {
      case CategorySelected(:final category):
        if (existing != null) {
          await HiveService.updateCategory(anime.id, category);
        } else {
          await HiveService.addToList(AnimeListItem.fromAnime(anime, category));
        }
      case DeleteFromList():
        await HiveService.removeFromList(anime.id);
    }
    setState(() {});
  }

  void _openMangaDetail(int mangaId) {
    if (widget.onSelectManga != null) {
      widget.onSelectManga!(mangaId);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MangaDetailPage(
            mangaId: mangaId,
            onBack: () => Navigator.pop(context),
          ),
        ),
      );
    }
  }

  void _openAnimeDetail(int animeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailPage(
          animeId: animeId,
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _computeSchedule() {
      final now = DateTime.now();
      final Map<int, List<AnimeModel>> grouped = {};
      List<Map<String, dynamic>> upcoming = [];
      
      for (final anime in _seasonal) {
        int? weekday; 
        DateTime? localTime;
        
        if (anime.broadcastDay != null && anime.broadcastTime != null) {
          localTime = _parseJstNextBroadcast(anime.broadcastDay!, anime.broadcastTime!);
          
          if (localTime != null) {
             weekday = localTime.weekday;
             if (localTime.year == now.year && localTime.month == now.month && localTime.day == now.day) {
               if (localTime.isAfter(now)) {
                   upcoming.add({'anime': anime, 'time': localTime});
               }
             }
          }
        }
        if (weekday != null) {
          grouped.putIfAbsent(weekday, () => []).add(anime);
        }
      }
      
      for (final list in grouped.values) {
         list.sort((a, b) {
            if (a.broadcastTime == null || b.broadcastTime == null) return 0;
            return a.broadcastTime!.compareTo(b.broadcastTime!);
         });
      }
      upcoming.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));
      _groupedSchedule = grouped;
      _upcomingAnimes = upcoming;
  }

  DateTime? _parseJstNextBroadcast(String day, String time) {
     try {
       final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(time);
       if (timeMatch == null) return null; 
       
       int hour = int.parse(timeMatch.group(1)!);
       int minute = int.parse(timeMatch.group(2)!);
       
       int extraDays = 0;
       if (hour >= 24) {
         hour -= 24;
         extraDays = 1;
       }
       
       int targetWeekday;
       final lowerDay = day.toLowerCase();
       if (lowerDay.contains('monday')) targetWeekday = DateTime.monday;
       else if (lowerDay.contains('tuesday')) targetWeekday = DateTime.tuesday;
       else if (lowerDay.contains('wednesday')) targetWeekday = DateTime.wednesday;
       else if (lowerDay.contains('thursday')) targetWeekday = DateTime.thursday;
       else if (lowerDay.contains('friday')) targetWeekday = DateTime.friday;
       else if (lowerDay.contains('saturday')) targetWeekday = DateTime.saturday;
       else if (lowerDay.contains('sunday')) targetWeekday = DateTime.sunday;
       else return null; 
       
       final nowUtc = DateTime.now().toUtc();
       final nowJst = nowUtc.add(const Duration(hours: 9)); 
       
       DateTime nextJst = DateTime.utc(nowJst.year, nowJst.month, nowJst.day, hour, minute);
       nextJst = nextJst.add(Duration(days: extraDays));
       
       while (nextJst.weekday != targetWeekday) {
         nextJst = nextJst.add(const Duration(days: 1));
       }
       if (nextJst.isBefore(nowJst)) {
         nextJst = nextJst.add(const Duration(days: 7));
       }
       return nextJst.subtract(const Duration(hours: 9)).toLocal();
     } catch (e) {
       return null;
     }
  }

  Widget _buildNextAnimeSection() {
     if (_upcomingAnimes.isEmpty) return const SizedBox.shrink();
     final isDark = Theme.of(context).brightness == Brightness.dark;
       
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(Icons.flash_on, color: AppColors.accent, size: 16),
                const SizedBox(width: 4),
                Text(AppText.get('airing_next_today'), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _upcomingAnimes.length,
              itemBuilder: (context, index) {
                 final item = _upcomingAnimes[index];
                 final AnimeModel anime = item['anime'];
                 final DateTime time = item['time'];
                 final timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                 return GestureDetector(
                   onTap: () => widget.onSelectAnime(anime.id),
                   child: Container(
                      width: 250,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent.withAlpha(index == 0 ? 100 : 30), width: index == 0 ? 1.5 : 1.0),
                      ),
                      child: Row(
                        children: [
                           ClipRRect(
                             borderRadius: BorderRadius.circular(8),
                             child: Image.network(anime.image, width: 70, height: 100, fit: BoxFit.cover),
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                              child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                    Text(anime.title, style: Theme.of(context).textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 6),
                                    Row(
                                       children: [
                                          Icon(Icons.schedule, size: 12, color: isDark ? Colors.white70 : Colors.black54),
                                          const SizedBox(width: 4),
                                          Text(timeStr, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                                       ]
                                    )
                                 ]
                              )
                           )
                        ]
                      ),
                   ),
                 );
              }
            )
          ),
          const SizedBox(height: 16),
       ],
     );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SingleChildScrollView(
        child: Column(
          children: [
            ShimmerLoading.heroBanner(context: context),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ShimmerLoading.horizontalList(context: context),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return ErrorStateWidget(message: _error, onRetry: _loadData);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Carousel ──
            if (_seasonal.isNotEmpty) _buildHeroCarousel(),

            const SizedBox(height: 24),

            // ── API Status Banner ──
            ValueListenableBuilder<bool>(
              valueListenable: JikanService.usingCachedData,
              builder: (context, usingCached, _) {
                if (!usingCached) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ApiStatusBanner(
                    onRetry: _loadData,
                  ),
                );
              },
            ),

            _buildQuickTracker(context),

            // ── Current Season ──
            HorizontalAnimeList(
              title: AppText.get('current_season'),
              data: _seasonal,
              onSelect: widget.onSelectAnime,
              onAdd: _handleAddToList,
              isInList: (id) => HiveService.isInList(id),
              onSeeAll: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SeeAllPage(
                    title: AppText.get('current_season'),
                    animeList: _seasonal,
                    onSelectAnime: _openAnimeDetail,
                    onLoadMore: (page) => JikanService.getSeasonNow(limit: 25, page: page),
                  )),
                );
              },
            ),

            if (MalAuthService.instance.isLoggedIn && (_suggestionsLoading || _userSuggestions.isNotEmpty)) ...[
              const SizedBox(height: 24),
              HorizontalAnimeList(
                title: '✨ Suggestions For You',
                data: _userSuggestions,
                onSelect: widget.onSelectAnime,
                onAdd: _handleAddToList,
                isInList: (id) => HiveService.isInList(id),
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SeeAllPage(
                      title: 'Suggestions For You',
                      animeList: _userSuggestions,
                      onSelectAnime: _openAnimeDetail,
                      onLoadMore: (page) => JikanService.getUserSuggestions(limit: 15, page: page),
                    )),
                  );
                },
              ),
            ],

            const SizedBox(height: 24),

            if (widget.isDesktop) ...[
              DailyTimeline(
                scheduleMap: _groupedSchedule,
                onSelectAnime: widget.onSelectAnime,
                onSeeAll: widget.onSeeAllSchedule,
              ),
              const SizedBox(height: 16),
              _buildNextAnimeSection(),
              const SizedBox(height: 8),
            ],

            // ── Upcoming Anime ──
            if (_upcoming.isNotEmpty) ...[
              HorizontalAnimeList(
                title: '🗓 ${AppText.getPlural('upcoming_anime', _upcoming.length)}',
                data: _upcoming,
                onSelect: widget.onSelectAnime,
                onAdd: _handleAddToList,
                isInList: (id) => HiveService.isInList(id),
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SeeAllPage(
                      title: AppText.getPlural('upcoming_anime', _upcoming.length),
                      animeList: _upcoming,
                      onSelectAnime: _openAnimeDetail,
                      onLoadMore: (page) => JikanService.getUpcomingAnime(limit: 25, page: page),
                    )),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],

            // ── Top Rated ──
            HorizontalAnimeList(
              title: AppText.get('top_rated'),
              data: _top,
              onSelect: widget.onSelectAnime,
              onAdd: _handleAddToList,
              isInList: (id) => HiveService.isInList(id),
              onSeeAll: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SeeAllPage(
                    title: AppText.get('top_rated'),
                    animeList: _top,
                    onSelectAnime: _openAnimeDetail,
                    onLoadMore: (page) => JikanService.getTopAnime(limit: 15, page: page),
                  )),
                );
              },
            ),

            const SizedBox(height: 8),

            // ── Top Manga ──
            HorizontalAnimeList(
              title: AppText.getPlural('top_manga', _topManga.length),
              data: _topManga,
              onSelect: _openMangaDetail,
              onAdd: _handleAddToList,
              isInList: (id) => HiveService.isInList(id),
              onSeeAll: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SeeAllPage(
                    title: AppText.getPlural('top_manga', _topManga.length),
                    animeList: _topManga,
                    onSelectAnime: (mangaId) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MangaDetailPage(
                            mangaId: mangaId,
                            onBack: () => Navigator.pop(context),
                          ),
                        ),
                      );
                    },
                    onLoadMore: (page) => JikanService.getTopManga(limit: 15, page: page),
                  )),
                );
              },
            ),

            // ── Top Reviews (horizontal scrolling) ──
            if (_topReviews.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppText.getPlural('top_reviews', _topReviews.length),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SeeAllPage(
                            title: AppText.getPlural('top_reviews', _topReviews.length),
                            animeList: const [],
                            onSelectAnime: (_) {},
                            reviewMode: true,
                            reviewList: _topReviews,
                          )),
                        );
                      },
                      child: Text(
                        AppText.get('see_all'),
                        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _topReviews.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    return _buildReviewCard(_topReviews[index], context);
                  },
                ),
              ),
            ],

            // ── Recommended For You ──
            if (_recommended.isNotEmpty) ...[
              const SizedBox(height: 8),
              HorizontalAnimeList(
                title: AppText.getPlural('for_you', _recommended.length),
                data: _recommended,
                onSelect: widget.onSelectAnime,
                onAdd: _handleAddToList,
                isInList: (id) => HiveService.isInList(id),
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SeeAllPage(
                      title: AppText.getPlural('recommended_for_you', _recommended.length),
                      animeList: _recommended,
                      onSelectAnime: _openAnimeDetail,
                    )),
                  );
                },
              ),
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTracker(BuildContext context) {
    return ValueListenableBuilder<Box<AnimeListItem>>(
      valueListenable: HiveService.listBoxListenable,
      builder: (context, box, _) {
        final watchingItems = box.values
            .where((item) => item.category == AnimeCategory.watching)
            .toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt)); // most recent first

        if (watchingItems.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '⚡ Continue Watching',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: watchingItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final item = watchingItems[index];
                  return QuickTrackerCard(
                    item: item,
                    onSelectAnime: widget.onSelectAnime,
                    onStateChanged: () {
                      if (mounted) setState(() {});
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_pageController.hasClients && _seasonal.isNotEmpty) {
        final totalPages = _seasonal.take(5).length;
        final next = (_carouselIndex + 1) % totalPages;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildHeroCarousel() {
    if (_seasonal.isEmpty) return const SizedBox.shrink();
    
    final carouselItems = _seasonal.take(5).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppText.getPlural('featured_trending_anime', carouselItems.length),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 380,
            child: Stack(
              children: [
                // PageView
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: carouselItems.length,
                    onPageChanged: (index) {
                      setState(() {
                        _carouselIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final anime = carouselItems[index];
                      return GestureDetector(
                        onTap: () => widget.onSelectAnime(anime.id),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: anime.image,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.2),
                            ),
                            // Gradient Overlay (darkening from bottom up)
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.3),
                                    Colors.black.withOpacity(0.85),
                                  ],
                                  stops: const [0.3, 0.6, 1.0],
                                ),
                              ),
                            ),
                            // Content overlay
                            Positioned(
                              bottom: 24,
                              left: 24,
                              right: 24,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    anime.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        'Rating : ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          anime.scoreDisplay,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.accentLight,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.star_rounded, size: 14, color: AppColors.starYellow),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    anime.synopsis,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.75),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Navigation Chevrons
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _buildChevronButton(
                        icon: Icons.chevron_left_rounded,
                        onPressed: () {
                          if (_carouselIndex > 0) {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _pageController.animateToPage(
                              carouselItems.length - 1,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildChevronButton(
                        icon: Icons.chevron_right_rounded,
                        onPressed: () {
                          if (_carouselIndex < carouselItems.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _pageController.animateToPage(
                              0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),

                // Dots indicator
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      carouselItems.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: _carouselIndex == index ? 24 : 8,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: _carouselIndex == index
                              ? AppColors.accent
                              : Colors.white.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChevronButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: Colors.white),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final user     = review['user'] ?? {};
    final anime    = review['entry'] ?? {};
    final score    = review['score'] ?? 0;
    final content  = review['review'] ?? '';

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: user['images']?['jpg']?['image_url'] != null
                    ? NetworkImage(user['images']['jpg']['image_url'])
                    : null,
                backgroundColor: AppColors.accent.withAlpha(50),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['username'] ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('on ${anime['title'] ?? 'Anime'}',
                        style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.starYellow.withAlpha(30),
                    borderRadius: BorderRadius.circular(4)),
                child: Row(children: [
                  const Icon(Icons.star, size: 12, color: AppColors.starYellow),
                  const SizedBox(width: 2),
                  Text('$score', style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.starYellow)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              content,
              style: TextStyle(fontSize: 12, height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black87),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
