import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_model.dart';
import '../core/models/anime_list_item.dart';
import '../core/services/jikan_service.dart';
import '../core/services/hive_service.dart';
import '../core/localization/app_text.dart';
import '../widgets/anime_card.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/error_state.dart';
import '../widgets/category_picker.dart';
import '../widgets/api_status_banner.dart';
import 'manga_detail_page.dart';

class SearchPage extends StatefulWidget {
  final void Function(int animeId) onSelectAnime;
  final void Function(int mangaId)? onSelectManga;
  final String searchQuery;
  final bool hideSearchBar;
  final String? initialGenreId;
  final String? initialGenreName;

  const SearchPage({
    super.key, 
    required this.onSelectAnime,
    this.onSelectManga,
    this.searchQuery = '',
    this.hideSearchBar = false,
    this.initialGenreId,
    this.initialGenreName,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  String _status = '';
  String _rating = '';
  String _orderBy = 'score';
  
  // New Filters
  String _genreId = '';
  String _genreName = '';
  String _producerId = '';
  String _producerName = '';
  int? _year;
  String _season = '';

  List<AnimeModel> _results = [];
  bool _loading = false;
  String? _error;
  bool _hasSearched = false;

  List<Map<String, dynamic>> _allGenres = [];
  List<Map<String, dynamic>> _allProducers = [];

  @override
  void initState() {
    super.initState();
    _initGenres();
    if (widget.initialGenreId != null && widget.initialGenreId!.isNotEmpty) {
      _genreId = widget.initialGenreId!;
      _genreName = widget.initialGenreName ?? '';
      _performSearch();
    }
  }

  Future<void> _initGenres() async {
    var cached = HiveService.getCachedGenres();
    if (cached == null || cached.isEmpty) {
      cached = await JikanService.getAnimeGenres();
      if (cached.isNotEmpty) {
        await HiveService.cacheGenres(cached);
      }
    }
    List<Map<String, dynamic>> producers = [];
    try {
      producers = await JikanService.getProducers();
    } catch (_) {}

    if (mounted) setState(() { 
       _allGenres = cached ?? []; 
       _allProducers = producers;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (widget.hideSearchBar) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _performSearch();
    });
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldSearch = false;
    if (widget.hideSearchBar && widget.searchQuery != oldWidget.searchQuery) {
      shouldSearch = true;
    }
    if (widget.initialGenreId != oldWidget.initialGenreId && widget.initialGenreId != null) {
      _genreId = widget.initialGenreId!;
      _genreName = widget.initialGenreName ?? '';
      shouldSearch = true;
    }
    
    if (shouldSearch) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 600), () {
        _performSearch(queryOverride: widget.searchQuery);
      });
    }
  }

  Future<void> _performSearch({String? queryOverride}) async {
    final query = queryOverride ?? _searchController.text.trim();
    if (query.isEmpty && _status.isEmpty && _rating.isEmpty && _genreId.isEmpty && _year == null) {
      setState(() { _results = []; _hasSearched = false; });
      return;
    }

    setState(() { _loading = true; _error = null; _hasSearched = true; });
    try {
      List<AnimeModel> data = [];
      if (_year != null && _season.isNotEmpty) {
        // Season Archive mode
        data = await JikanService.getSeasonArchive(_year!, _season);
        
        // Local filtering since endpoint doesn't support query parameters directly
        if (_genreId.isNotEmpty) {
          data = data.where((a) => a.genres.contains(_genreName)).toList();
        }
        if (_producerName.isNotEmpty) {
          data = data.where((a) => a.studios.contains(_producerName)).toList();
        }
        if (query.isNotEmpty) {
          data = data.where((a) => a.title.toLowerCase().contains(query.toLowerCase())).toList();
        }
      } else {
        // Standard Search
        data = await JikanService.searchAnime(
          query: query,
          status: _status,
          rating: _rating,
          orderBy: _orderBy,
          genres: _genreId,
          producers: _producerId,
        );
      }
      if (mounted) setState(() { _results = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _handleAddToList(AnimeModel anime) async {
    final existing = HiveService.getListItem(anime.id);
    final result = await CategoryPickerSheet.show(context, current: existing?.category);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── Search Bar & Filters ──
        if (!widget.hideSearchBar)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor.withAlpha(40)),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Search input
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              Icon(
                                Icons.search,
                                color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: _onSearchChanged,
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: AppText.get('search_anime'),
                                    hintStyle: TextStyle(
                                      color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty) ...[
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _results = [];
                                      _hasSearched = false;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                                ),
                                const SizedBox(width: 12),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.accent.withAlpha(isDark ? 50 : 30),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.casino, color: AppColors.accent),
                          onPressed: () async {
                             setState(() { _loading = true; _error = null; });
                             final random = await JikanService.getRandomAnime();
                             if (random != null && mounted) {
                                _searchController.text = random.title;
                                setState(() {
                                   _results = [random];
                                   _loading = false;
                                   _hasSearched = true;
                                });
                             } else if (mounted) {
                                setState(() { _error = "Failed to load random anime"; _loading = false; });
                             }
                          },
                          tooltip: 'Random Anime',
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Filters row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: _year != null ? '$_season ${_year}' : AppText.get('current_season'),
                          isActive: _year != null,
                          onTap: () => _showSeasonYearPicker(),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: _genreName.isEmpty ? 'All Genres' : _genreName,
                          isActive: _genreId.isNotEmpty,
                          onTap: () => _showGenrePicker(),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: _producerName.isEmpty ? 'All Producers' : _producerName,
                          isActive: _producerId.isNotEmpty,
                          onTap: () => _showProducerPicker(),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: _status.isEmpty ? AppText.get('all_statuses') : _statusLabel(_status),
                          isActive: _status.isNotEmpty,
                          onTap: () => _showStatusPicker(),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: _rating.isEmpty ? AppText.get('all_ratings') : _ratingLabel(_rating),
                          isActive: _rating.isNotEmpty,
                          onTap: () => _showRatingPicker(),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: '${AppText.get('sort_by')}: ${_orderByLabel(_orderBy)}',
                          isActive: true,
                          onTap: () => _showSortPicker(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── API Status Banner ──
        ValueListenableBuilder<bool>(
          valueListenable: JikanService.usingCachedData,
          builder: (context, usingCached, _) {
            if (!usingCached) return const SizedBox.shrink();
            return ApiStatusBanner(
              onRetry: _performSearch,
            );
          },
        ),

        // ── Results ──
        Expanded(
          child: _loading
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: ShimmerLoading.cardGrid(count: 6, context: context),
                )
              : _error != null
                  ? ErrorStateWidget(message: _error, onRetry: _performSearch)
                  : _results.isNotEmpty
                      ? GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final anime = _results[index];
                            return AnimeCard(
                              anime: anime,
                              onTap: () => widget.onSelectAnime(anime.id),
                              onAdd: () => _handleAddToList(anime),
                              isInList: HiveService.isInList(anime.id),
                            );
                          },
                        )
                      : _hasSearched
                          ? Center(
                              child: Text(
                                AppText.get('no_results'),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          : _buildExploreHome(),
        ),
      ],
    );
  }

  Widget _buildFilterChip({required String label, required bool isActive, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withAlpha(30) : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.accent : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.accent : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'airing': return AppText.get('airing');
      case 'complete': return AppText.get('finished');
      case 'upcoming': return AppText.get('upcoming');
      default: return s;
    }
  }

  String _ratingLabel(String r) {
    switch (r) {
      case 'g': return 'G - All Ages';
      case 'pg13': return 'PG-13';
      case 'r17': return 'R - 17+';
      default: return r;
    }
  }

  String _orderByLabel(String o) {
    switch (o) {
      case 'score': return AppText.get('score');
      case 'title': return AppText.get('title');
      case 'popularity': return AppText.get('popularity');
      default: return o;
    }
  }

  void _showStatusPicker() {
    _showOptionPicker(
      options: [
        ('', AppText.get('all_statuses')),
        ('airing', AppText.get('airing')),
        ('complete', AppText.get('finished')),
        ('upcoming', AppText.get('upcoming')),
      ],
      current: _status,
      onSelected: (v) {
        setState(() => _status = v);
        _performSearch();
      },
    );
  }

  void _showRatingPicker() {
    _showOptionPicker(
      options: [
        ('', AppText.get('all_ratings')),
        ('g', 'G - All Ages'),
        ('pg13', 'PG-13'),
        ('r17', 'R - 17+'),
      ],
      current: _rating,
      onSelected: (v) {
        setState(() => _rating = v);
        _performSearch();
      },
    );
  }

  void _showSortPicker() {
    _showOptionPicker(
      options: [
        ('score', AppText.get('score')),
        ('title', AppText.get('title')),
        ('popularity', AppText.get('popularity')),
      ],
      current: _orderBy,
      onSelected: (v) {
        setState(() => _orderBy = v);
        _performSearch();
      },
    );
  }

  void _showOptionPicker({
    required List<(String, String)> options,
    required String current,
    required ValueChanged<String> onSelected,
    bool searchable = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String filterQuery = '';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
             final filteredOptions = filterQuery.isEmpty 
                  ? options 
                  : options.where((o) => o.$2.toLowerCase().contains(filterQuery.toLowerCase())).toList();
             
             return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (searchable) 
                       Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: TextField(
                             onChanged: (v) => setModalState(() => filterQuery = v),
                             textAlignVertical: TextAlignVertical.center,
                             decoration: InputDecoration(
                                hintText: "Search...",
                                prefixIcon: const Icon(Icons.search),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                             ),
                          )
                       ),
                    Expanded(
                      child: ListView(
                        children: filteredOptions.map((opt) => ListTile(
                          title: Text(opt.$2, style: TextStyle(
                            fontWeight: current == opt.$1 ? FontWeight.w700 : FontWeight.w400,
                            color: current == opt.$1 ? AppColors.accent : null,
                          )),
                          trailing: current == opt.$1 ? Icon(Icons.check_circle, color: AppColors.accent) : null,
                          onTap: () {
                            Navigator.of(context).pop();
                            onSelected(opt.$1);
                          },
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
             );
          }
        );
      },
    );
  }

  void _showGenrePicker() {
    List<(String, String)> options = [('', 'All Genres')];
    for (var g in _allGenres) {
      options.add((g['mal_id'].toString(), g['name'] as String));
    }

    _showOptionPicker(
      options: options,
      current: _genreId,
      onSelected: (v) {
        setState(() {
          _genreId = v;
          _genreName = v.isEmpty ? '' : _allGenres.firstWhere((e) => e['mal_id'].toString() == v)['name'];
        });
        _performSearch();
      },
      searchable: true,
    );
  }

  void _showProducerPicker() {
    List<(String, String)> options = [('', 'All Producers')];
    for (var p in _allProducers) {
      options.add((p['mal_id'].toString(), p['titles']?[0]?['title'] ?? p['url'] ?? 'Unknown'));
    }

    _showOptionPicker(
      options: options,
      current: _producerId,
      onSelected: (v) {
        setState(() {
          _producerId = v;
          _producerName = v.isEmpty ? '' : options.firstWhere((e) => e.$1 == v).$2;
        });
        _performSearch();
      },
      searchable: true,
    );
  }

  void _showSeasonYearPicker() {
    int tempYear = _year ?? DateTime.now().year;
    String tempSeason = _season.isEmpty ? 'winter' : _season;
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Select Season Layout"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         IconButton(onPressed: () => setDialogState(() => tempYear--), icon: const Icon(Icons.remove)),
                         Text("$tempYear", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                         IconButton(onPressed: () => setDialogState(() => tempYear++), icon: const Icon(Icons.add)),
                      ]
                   ),
                   const SizedBox(height: 16),
                   DropdownButton<String>(
                      value: tempSeason,
                      isExpanded: true,
                      items: const [
                         DropdownMenuItem(value: 'winter', child: Text("Winter")),
                         DropdownMenuItem(value: 'spring', child: Text("Spring")),
                         DropdownMenuItem(value: 'summer', child: Text("Summer")),
                         DropdownMenuItem(value: 'fall', child: Text("Fall")),
                      ],
                      onChanged: (v) {
                         if (v != null) setDialogState(() => tempSeason = v);
                      }
                   )
                ]
              ),
              actions: [
                 TextButton(onPressed: () {
                    setState(() { _year = null; _season = ''; });
                    Navigator.pop(ctx);
                    _performSearch();
                 }, child: const Text("Clear")),
                 ElevatedButton(onPressed: () {
                    setState(() { _year = tempYear; _season = tempSeason; });
                    Navigator.pop(ctx);
                    _performSearch();
                 }, child: const Text("Apply")),
              ]
            );
          }
        );
      }
    );
  }

  Widget _buildExploreHome() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cachedTopMaps = HiveService.getCachedTopAnime() ?? [];
    final cachedMangaMaps = HiveService.getCachedTopManga() ?? [];
    final cachedReviews = HiveService.getCachedTopReviews() ?? [];

    final topAnimeList = cachedTopMaps.map((m) => AnimeModel.fromJson(m)).toList();
    final topMangaList = cachedMangaMaps.map((m) => AnimeModel.fromJson(m)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section 1: Top Anime ──
          if (topAnimeList.isNotEmpty) ...[
            _buildExploreSectionHeader('Top Anime'),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: topAnimeList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final anime = topAnimeList[index];
                  return _buildExplorePosterCard(anime, isAnime: true);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Section 2: Top Manga ──
          if (topMangaList.isNotEmpty) ...[
            _buildExploreSectionHeader('Top Manga'),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: topMangaList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final manga = topMangaList[index];
                  return _buildExplorePosterCard(manga, isAnime: false);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Section 3: User Reviews & Top Reviews ──
          if (cachedReviews.isNotEmpty) ...[
            _buildExploreSectionHeader('Top Reviews'),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cachedReviews.length.clamp(0, 10),
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final review = cachedReviews[index];
                  return _buildExploreReviewCard(review);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildExploreSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorePosterCard(AnimeModel item, {required bool isAnime}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        if (isAnime) {
          widget.onSelectAnime(item.id);
        } else {
          if (widget.onSelectManga != null) {
            widget.onSelectManga!(item.id);
          } else {
            // Fallback: push MangaDetailPage directly
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MangaDetailPage(
                  mangaId: item.id,
                  onBack: () => Navigator.pop(context),
                ),
              ),
            );
          }
        }
      },
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: item.image,
                width: 110,
                height: 145,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: isDark ? AppColors.darkCardBorder : Colors.black12),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreReviewCard(Map<String, dynamic> review) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = review['user'] ?? {};
    final score = review['score'] ?? 0;
    final content = review['review'] ?? '';

    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
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
                radius: 14,
                backgroundImage: user['images']?['jpg']?['image_url'] != null ? NetworkImage(user['images']['jpg']['image_url']) : null,
                backgroundColor: AppColors.accent.withAlpha(50),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  user['username'] ?? 'User',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: AppColors.starYellow.withAlpha(30), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 10, color: AppColors.starYellow),
                    const SizedBox(width: 2),
                    Text("$score", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.starYellow)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              content,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
