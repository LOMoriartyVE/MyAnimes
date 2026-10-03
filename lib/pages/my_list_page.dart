import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_list_item.dart';
import '../core/services/hive_service.dart';
import '../core/localization/app_text.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/category_picker.dart';
import '../widgets/user_rating_sheet.dart';
import '../widgets/personal_notes_tags_sheet.dart';
import '../core/services/airing_schedule_service.dart';
import '../core/services/notification_service.dart';
import 'anime_wrapped_page.dart';
import 'status_page.dart';
import 'share_layered_list_page.dart';
import '../core/services/mal_auth_service.dart';

class MyListPage extends StatefulWidget {
  final void Function(int animeId) onSelectAnime;

  const MyListPage({super.key, required this.onSelectAnime});

  @override
  State<MyListPage> createState() => _MyListPageState();
}

class _MyListPageState extends State<MyListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _sortBy = 'date'; // date, title, score, episodes, year_season, type
  final Set<String> _filterStatuses = {}; // 'airing', 'finished_airing', 'unrated', 'behind', 'mal_synced', or 'tag:xyz'
  final Set<String> _filterGenres = {};
  final Set<String> _filterProducers = {};
  final Set<String> _filterTypes = {};
  final Set<String> _filterSeasons = {};
  final Set<String> _filterYears = {};

  bool _genresExpanded = false;
  bool _producersExpanded = false;
  bool _yearsExpanded = false;

  int get _activeFilterCount =>
      (_sortBy != 'date' ? 1 : 0) +
      _filterStatuses.length +
      _filterGenres.length +
      _filterProducers.length +
      _filterTypes.length +
      _filterSeasons.length +
      _filterYears.length;

  final List<AnimeCategory> _categories = [
    AnimeCategory.watching,
    AnimeCategory.completed,
    AnimeCategory.planned,
    AnimeCategory.ignored,
  ];
  
  String _searchQuery = '';
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _isGridView = HiveService.isMyListGridView;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
      }
      if (mounted) setState(() {});
    });

    // Check release day notifications and heal unknown episodes in background
    NotificationService.checkAndNotifyReleaseDays();
    HiveService.healListItemsMetadata().then((_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final allItems = HiveService.getAllListItems();
      AiringScheduleService.autoCheckAiringEpisodesForList(
        allItems,
        onUpdate: () {
          if (mounted) setState(() {});
        },
      );
    });
    HiveService.exclusionsRevision.addListener(_onExclusionsChanged);
  }

  @override
  void dispose() {
    HiveService.exclusionsRevision.removeListener(_onExclusionsChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onExclusionsChanged() {
    if (mounted) setState(() {});
  }

  String _categoryLabel(AnimeCategory cat) {
    switch (cat) {
      case AnimeCategory.watching: return AppText.get('watching');
      case AnimeCategory.completed: return AppText.get('completed');
      case AnimeCategory.planned: return AppText.get('planned');
      case AnimeCategory.ignored: return AppText.get('ignored');
    }
  }

  Color _categoryColor(AnimeCategory cat) {
    switch (cat) {
      case AnimeCategory.watching: return AppColors.watching;
      case AnimeCategory.completed: return AppColors.completed;
      case AnimeCategory.planned: return AppColors.planned;
      case AnimeCategory.ignored: return AppColors.ignored;
    }
  }

  IconData _categoryIcon(AnimeCategory cat) {
    switch (cat) {
      case AnimeCategory.watching: return Icons.play_circle_outline;
      case AnimeCategory.completed: return Icons.check_circle_outline;
      case AnimeCategory.planned: return Icons.bookmark_outline;
      case AnimeCategory.ignored: return Icons.visibility_off_outlined;
    }
  }

  List<AnimeListItem> _getSortedFiltered(AnimeCategory category) {
    var items = HiveService.getByCategory(category);
    items = HiveService.filterExcludedListItems(items);

    // Filter by genres (multi-select: anime has any selected genre)
    if (_filterGenres.isNotEmpty) {
      items = items.where((i) => i.genres.any((g) => _filterGenres.contains(g))).toList();
    }

    // Filter by producers / studios (multi-select)
    if (_filterProducers.isNotEmpty) {
      items = items.where((i) => i.studios != null && i.studios!.any((s) => _filterProducers.contains(s))).toList();
    }
    
    // Filter by type (multi-select)
    if (_filterTypes.isNotEmpty) {
      items = items.where((i) => _filterTypes.any((t) => (i.type ?? '').toLowerCase() == t.toLowerCase())).toList();
    }

    // Filter by season (multi-select)
    if (_filterSeasons.isNotEmpty) {
      items = items.where((i) => _filterSeasons.any((s) => (i.season ?? '').toLowerCase() == s.toLowerCase())).toList();
    }

    // Filter by year (multi-select)
    if (_filterYears.isNotEmpty) {
      items = items.where((i) => _filterYears.contains(i.year)).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      items = items.where((i) => i.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // Filter by status / airing / state (multi-select)
    if (_filterStatuses.isNotEmpty) {
      items = items.where((i) {
        return _filterStatuses.any((st) {
          if (st == 'airing') {
            final info = AiringScheduleService.getCountdown(i.animeId, episodeProgress: i.episodeProgress);
            return info.isAiring;
          } else if (st == 'finished_airing') {
            final info = AiringScheduleService.getCountdown(i.animeId, episodeProgress: i.episodeProgress);
            final totalEp = int.tryParse(i.episodes) ?? 0;
            return info.isFinished || i.category == AnimeCategory.completed || (totalEp > 0 && i.episodeProgress >= totalEp);
          } else if (st == 'unrated') {
            return i.userRating == null || !i.userRating!.hasRating;
          } else if (st == 'behind') {
            final totalEp = int.tryParse(i.episodes) ?? 0;
            return totalEp > 0 && i.episodeProgress < totalEp;
          } else if (st == 'mal_synced') {
            return i.isMalSynced == true;
          } else if (st.startsWith('tag:')) {
            final tag = st.substring(4);
            return i.tags != null && i.tags!.contains(tag);
          }
          return false;
        });
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'title':
        items.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'score':
        items.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
        break;
      case 'episodes':
        items.sort((a, b) {
          final epA = int.tryParse(a.episodes) ?? a.episodeProgress;
          final epB = int.tryParse(b.episodes) ?? b.episodeProgress;
          return epB.compareTo(epA);
        });
        break;
      case 'year_season':
        items.sort((a, b) {
          final yearA = int.tryParse(a.year ?? '0') ?? 0;
          final yearB = int.tryParse(b.year ?? '0') ?? 0;
          if (yearA != yearB) return yearB.compareTo(yearA);
          return (b.season ?? '').compareTo(a.season ?? '');
        });
        break;
      case 'type':
        items.sort((a, b) => (a.type ?? '').compareTo(b.type ?? ''));
        break;
      case 'date':
      default:
        items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
    }
    return items;
  }

  Set<String> _getAllGenres() {
    final allItems = HiveService.getAllListItems();
    final genres = <String>{};
    for (final item in allItems) {
      genres.addAll(item.genres);
    }
    // Include standard genres as fallbacks
    genres.addAll([
      'Action', 'Adventure', 'Avant Garde', 'Award Winning', 'Boys Love',
      'Comedy', 'Drama', 'Fantasy', 'Girls Love', 'Gourmet', 'Horror',
      'Mahou Shoujo', 'Mecha', 'Music', 'Mystery', 'Psychological',
      'Romance', 'Sci-Fi', 'Slice of Life', 'Sports', 'Supernatural',
      'Suspense', 'Thriller'
    ]);
    return genres;
  }

  Set<String> _getAllProducers() {
    final allItems = HiveService.getAllListItems();
    final studios = <String>{};
    for (final item in allItems) {
      if (item.studios != null) {
        for (final s in item.studios!) {
          if (s.trim().isNotEmpty) {
            studios.add(s.trim());
          }
        }
      }
    }
    // Include top well-known anime studios as fallbacks
    studios.addAll([
      'MAPPA', 'ufotable', 'Bones', 'Madhouse', 'Wit Studio',
      'Kyoto Animation', 'A-1 Pictures', 'CloverWorks', 'Toei Animation',
      'Trigger', 'CoMix Wave Films', 'Studio Ghibli', 'Shaft', 'J.C.Staff',
      'Production I.G', 'TMS Entertainment', 'Pierrot', 'Sunrise'
    ]);
    return studios;
  }

  List<String> _getAllTypes() {
    final allItems = HiveService.getAllListItems();
    final types = <String>{'TV', 'Movie', 'OVA', 'ONA', 'Special', 'Music'};
    for (final item in allItems) {
      if (item.type != null && item.type!.isNotEmpty) {
        types.add(item.type!);
      }
    }
    return types.toList()..sort();
  }

  List<String> _getAllYears() {
    final allItems = HiveService.getAllListItems();
    final years = <String>{};
    for (final item in allItems) {
      if (item.year != null && item.year!.isNotEmpty) {
        years.add(item.year!);
      }
    }
    // Include current and recent years if list is young
    final currentYear = DateTime.now().year;
    for (int y = currentYear + 1; y >= currentYear - 10; y--) {
      years.add(y.toString());
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<Box<AnimeListItem>>(
      valueListenable: HiveService.listBoxListenable,
      builder: (context, box, _) {
        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              AppText.get('nav_my_list'),
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
                          onPressed: () {
                            setState(() {
                              _isGridView = !_isGridView;
                            });
                            HiveService.setMyListGridView(_isGridView);
                          },
                          tooltip: _isGridView ? 'Tile View' : 'Grid View',
                        ),
                        IconButton(
                          icon: const Icon(Icons.analytics_outlined),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                               builder: (context) => const StatusPage()
                            ));
                          },
                          tooltip: 'Stats',
                        ),
                        IconButton(
                          icon: Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => const AnimeWrappedPage(),
                            ));
                          },
                          tooltip: 'Anime Wrapped',
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_outlined),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => const ShareLayeredListPage(),
                            ));
                          },
                          tooltip: 'Share layered list image',
                        ),
                        Builder(builder: (context) {
                          return IconButton(
                            icon: Badge.count(
                              count: _activeFilterCount,
                              isLabelVisible: _activeFilterCount > 0,
                              backgroundColor: AppColors.accent,
                              textColor: Colors.white,
                              child: const Icon(Icons.tune_rounded),
                            ),
                            onPressed: _showSortFilterSheet,
                            tooltip: AppText.get('sort_filter'),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search my list...',
                    hintStyle: TextStyle(color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                    prefixIcon: Icon(Icons.search, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            // Active Filter Chips Bar (Shown when any filter or custom sort is active)
            _buildActiveFiltersBar(isDark),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(5),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _categories.map((cat) {
                          final count = _getSortedFiltered(cat).length;
                          final isSelected = _tabController.index == _categories.indexOf(cat);
                          return InkWell(
                            onTap: () {
                              _tabController.index = _categories.indexOf(cat);
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              constraints: const BoxConstraints(minHeight: 40),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                              decoration: BoxDecoration(
                                gradient: isSelected ? AppColors.brandGradient : null,
                                color: isSelected ? null : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.accent.withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${_categoryLabel(cat)} ($count)',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _categories.map((cat) => _buildCategoryList(cat)).toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
  }

  Widget _buildActiveFiltersBar(bool isDark) {
    if (_activeFilterCount == 0) return const SizedBox.shrink();

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Clear All Button
          _buildClearAllButton(isDark),
          const SizedBox(width: 8),

          // Active Sort
          if (_sortBy != 'date') ...[
            _buildActiveBadge(
              label: 'Sort: ${_sortLabel(_sortBy)}',
              icon: Icons.sort_rounded,
              color: AppColors.accent,
              onDelete: () => setState(() => _sortBy = 'date'),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
          ],

          // Active Status Filters (Airing Now, Finished Airing, Needs Rating, etc.)
          ..._filterStatuses.map((st) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActiveBadge(
              label: _statusLabel(st),
              icon: _statusIcon(st),
              color: _statusColor(st),
              onDelete: () => setState(() => _filterStatuses.remove(st)),
              isDark: isDark,
            ),
          )),

          // Active Genres
          ..._filterGenres.map((g) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActiveBadge(
              label: g,
              icon: Icons.tag_rounded,
              color: _genreColor(g),
              onDelete: () => setState(() => _filterGenres.remove(g)),
              isDark: isDark,
            ),
          )),

          // Active Producers
          ..._filterProducers.map((p) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActiveBadge(
              label: p,
              icon: Icons.movie_filter_rounded,
              color: _producerColor(p),
              onDelete: () => setState(() => _filterProducers.remove(p)),
              isDark: isDark,
            ),
          )),

          // Active Media Types
          ..._filterTypes.map((t) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActiveBadge(
              label: t,
              icon: Icons.category_rounded,
              color: const Color(0xFF3B82F6),
              onDelete: () => setState(() => _filterTypes.remove(t)),
              isDark: isDark,
            ),
          )),

          // Active Seasons
          ..._filterSeasons.map((s) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActiveBadge(
              label: s,
              icon: _seasonIcon(s),
              color: _seasonColor(s),
              onDelete: () => setState(() => _filterSeasons.remove(s)),
              isDark: isDark,
            ),
          )),

          // Active Years
          ..._filterYears.map((y) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActiveBadge(
              label: y,
              icon: Icons.calendar_today_rounded,
              color: const Color(0xFF14B8A6),
              onDelete: () => setState(() => _filterYears.remove(y)),
              isDark: isDark,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildClearAllButton(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() {
            _sortBy = 'date';
            _filterStatuses.clear();
            _filterGenres.clear();
            _filterProducers.clear();
            _filterTypes.clear();
            _filterSeasons.clear();
            _filterYears.clear();
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.redAccent.withValues(alpha: isDark ? 0.6 : 0.4),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
              const SizedBox(width: 4),
              Text(
                'Clear All ($_activeFilterCount)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveBadge({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onDelete,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.65 : 0.45),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onDelete();
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'title': return AppText.get('sort_by_title');
      case 'score': return AppText.get('sort_by_score');
      case 'episodes': return 'Episodes';
      case 'year_season': return 'Season & Year';
      case 'type': return 'Type';
      case 'date':
      default: return AppText.get('sort_by_date_added');
    }
  }

  String _statusLabel(String st) {
    switch (st) {
      case 'airing': return 'Airing Now';
      case 'finished_airing': return 'Finished Airing';
      case 'unrated': return 'Needs Rating';
      case 'behind': return 'Behind';
      case 'mal_synced': return 'MAL Synced';
      default:
        if (st.startsWith('tag:')) return '#${st.substring(4)}';
        return st;
    }
  }

  IconData _statusIcon(String st) {
    switch (st) {
      case 'airing': return Icons.sensors_rounded;
      case 'finished_airing': return Icons.check_circle_outline_rounded;
      case 'unrated': return Icons.star_outline_rounded;
      case 'behind': return Icons.timelapse_rounded;
      case 'mal_synced': return Icons.sync_rounded;
      default:
        if (st.startsWith('tag:')) return Icons.label_rounded;
        return Icons.filter_alt_rounded;
    }
  }

  Color _statusColor(String st) {
    switch (st) {
      case 'airing': return const Color(0xFF10B981);
      case 'finished_airing': return const Color(0xFF06B6D4);
      case 'unrated': return const Color(0xFFF59E0B);
      case 'behind': return const Color(0xFFFF5722);
      case 'mal_synced': return const Color(0xFF2E51A2);
      default: return const Color(0xFF8B5CF6);
    }
  }

  Color _seasonColor(String s) {
    switch (s.toLowerCase()) {
      case 'spring': return const Color(0xFF10B981);
      case 'summer': return const Color(0xFFF59E0B);
      case 'fall': return const Color(0xFFEA580C);
      case 'winter': return const Color(0xFF0EA5E9);
      default: return AppColors.accent;
    }
  }

  IconData _seasonIcon(String s) {
    switch (s.toLowerCase()) {
      case 'spring': return Icons.local_florist_rounded;
      case 'summer': return Icons.wb_sunny_rounded;
      case 'fall': return Icons.park_rounded;
      case 'winter': return Icons.ac_unit_rounded;
      default: return Icons.wb_cloudy_rounded;
    }
  }

  Color _genreColor(String genre) {
    switch (genre.toLowerCase()) {
      case 'action': return const Color(0xFFEF4444); // Red
      case 'adventure': return const Color(0xFFF97316); // Orange
      case 'avant garde': return const Color(0xFF8B5CF6); // Violet
      case 'award winning': return const Color(0xFFF59E0B); // Amber
      case 'boys love': return const Color(0xFFEC4899); // Pink
      case 'comedy': return const Color(0xFF10B981); // Emerald
      case 'drama': return const Color(0xFF6366F1); // Indigo
      case 'fantasy': return const Color(0xFF3B82F6); // Blue
      case 'girls love': return const Color(0xFFF43F5E); // Rose
      case 'gourmet': return const Color(0xFFEAB308); // Yellow
      case 'horror': return const Color(0xFFDC2626); // Dark Red
      case 'mahou shoujo': return const Color(0xFFD946EF); // Fuchsia
      case 'mecha': return const Color(0xFF06B6D4); // Cyan
      case 'music': return const Color(0xFFA855F7); // Purple
      case 'mystery': return const Color(0xFF14B8A6); // Teal
      case 'psychological': return const Color(0xFF64748B); // Slate
      case 'romance': return const Color(0xFFFB7185); // Light Pink
      case 'sci-fi': return const Color(0xFF0EA5E9); // Sky Blue
      case 'slice of life': return const Color(0xFF84CC16); // Lime
      case 'sports': return const Color(0xFFFF6B00); // Vivid Orange
      case 'supernatural': return const Color(0xFF9333EA); // Dark Violet
      case 'suspense': return const Color(0xFFBE123C); // Crimson
      case 'thriller': return const Color(0xFFB91C1C); // Crimson Red
      case 'adult cast': return const Color(0xFF475569); // Slate Grey
      default:
        final hash = genre.runes.fold<int>(0, (prev, elem) => prev + elem);
        final hue = (hash * 37) % 360;
        return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.72, 0.52).toColor();
    }
  }

  Color _producerColor(String producer) {
    switch (producer.toLowerCase()) {
      case 'mappa': return const Color(0xFFFF6B00); // Vivid Orange
      case 'ufotable': return const Color(0xFF7C3AED); // Deep Violet
      case 'bones': return const Color(0xFFE11D48); // Rose Red
      case 'cloverworks': return const Color(0xFF0D9488); // Teal
      case 'a-1 pictures': return const Color(0xFF0284C7); // Sky Blue
      case 'kyoto animation': return const Color(0xFFD97706); // Warm Amber
      case 'madhouse': return const Color(0xFFDC2626); // Red
      case 'wit studio': return const Color(0xFF059669); // Green
      case 'production i.g': return const Color(0xFF4F46E5); // Indigo
      case 'toei animation': return const Color(0xFF2563EB); // Royal Blue
      case 'studio ghibli': return const Color(0xFF16A34A); // Forest Green
      case 'shaft': return const Color(0xFFC026D3); // Magenta
      case 'j.c.staff': return const Color(0xFFDB2777); // Pink
      case 'trigger': return const Color(0xFFFF3366); // Neon Pink-Red
      case 'comix wave films': return const Color(0xFF06B6D4); // Cyan
      case 'tms entertainment': return const Color(0xFFEA580C); // Warm Orange
      case 'pierrot': return const Color(0xFFF59E0B); // Amber
      case 'sunrise': return const Color(0xFFE11D48); // Red
      default:
        final hash = producer.runes.fold<int>(0, (prev, elem) => prev + elem);
        final hue = (hash * 53) % 360;
        return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.75, 0.50).toColor();
    }
  }

  Widget _buildDeltaText(String prefix, AiringCountdownInfo info, Color baseColor, double fontSize) {
    if (info.watchDelta == null) {
      return Text(
        prefix,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: baseColor,
          letterSpacing: -0.2,
        ),
      );
    }

    final delta = info.watchDelta!;
    final Color deltaColor;
    if (delta < 0) {
      deltaColor = const Color(0xFFFF4D4D); // Red for -
    } else if (delta > 0) {
      deltaColor = const Color(0xFFFFD54F); // Yellow for +
    } else {
      deltaColor = const Color(0xFF10B981); // Emerald green for 0
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: baseColor,
          letterSpacing: -0.2,
        ),
        children: [
          TextSpan(text: '$prefix · '),
          TextSpan(
            text: info.deltaDisplay ?? '$delta',
            style: TextStyle(
              color: deltaColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownPill(AiringCountdownInfo info, {bool isCompact = false}) {
    if (info.isFinished) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: isCompact ? 2 : 4),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.teal.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: isCompact ? 10 : 12,
              color: Colors.teal,
            ),
            const SizedBox(width: 4),
            _buildDeltaText('Finished Airing', info, Colors.teal, isCompact ? 9 : 10.5),
          ],
        ),
      );
    }

    if (!info.isAiring || info.countdownText == null) return const SizedBox.shrink();
    final isToday = info.isAiringToday;
    final pillColor = isToday ? Colors.deepOrange : AppColors.accent;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: isCompact ? 2 : 4),
      decoration: BoxDecoration(
        color: pillColor.withOpacity(isToday ? 0.22 : 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pillColor.withOpacity(isToday ? 0.7 : 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isToday ? Icons.sensors_rounded : Icons.schedule_rounded,
            size: isCompact ? 10 : 12,
            color: pillColor,
          ),
          const SizedBox(width: 4),
          _buildDeltaText(info.countdownText!, info, pillColor, isCompact ? 9 : 10.5),
        ],
      ),
    );
  }

  Widget _buildCategoryList(AnimeCategory category) {
    final items = _getSortedFiltered(category);
    final color = _categoryColor(category);

    Widget content;
    if (items.isEmpty) {
      content = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _categoryIcon(category),
                    size: 64,
                    color: color.withAlpha(60),
                  ),
                  const SizedBox(height: 16),
                  Text(AppText.get('empty_list'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(AppText.get('empty_list_hint'), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (_isGridView) {
      content = GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.60,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildGridCard(item, color);
        },
      );
    } else {
      content = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildListTile(item, color);
        },
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : Colors.white,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await HiveService.healListItemsMetadata(forceNetwork: true);
        AiringScheduleService.warmUpCache(force: true);
        if (mounted) setState(() {});
      },
      child: content,
    );
  }

  void _showDeleteUndoToast(AnimeListItem deletedItem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${deletedItem.title} - ${AppText.get('item_removed')}'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: AppText.get('undo'),
          textColor: AppColors.accent,
          onPressed: () async {
            await HiveService.addToList(deletedItem);
            if (mounted) {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${deletedItem.title} - ${AppText.get('item_restored')}'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildListTile(AnimeListItem item, Color categoryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: Key('list_${item.animeId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) {
        final deletedItem = item;
        HiveService.removeFromList(item.animeId);
        setState(() {});
        _showDeleteUndoToast(deletedItem);
      },
      child: GestureDetector(
        onTap: () => widget.onSelectAnime(item.animeId),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Poster
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: SizedBox(
                    width: 96,
                    child: CachedNetworkImage(
                      imageUrl: item.image,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      ),
                      errorListener: (_) {},
                      errorWidget: (_, __, ___) => Container(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                // Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            if (item.isMalSynced == true || (MalAuthService.instance.isLoggedIn && item.isMalSynced != false)) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.withOpacity(0.5), width: 0.8),
                                ),
                                child: const Text(
                                  'MAL',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Countdown Pill for Airing Shows or Finished Airing
                        Builder(builder: (context) {
                          final countdown = AiringScheduleService.getCountdown(item.animeId, episodeProgress: item.episodeProgress);
                          if ((countdown.isAiring || countdown.isFinished) && countdown.countdownText != null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _buildCountdownPill(countdown),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                        const SizedBox(height: 8),
                        Builder(builder: (context) {
                          final int totalEp = int.tryParse(item.episodes) ?? 0;
                          if (totalEp > 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: (item.episodeProgress / totalEp).clamp(0.0, 1.0),
                                    backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                                    valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                                    minHeight: 3.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            );
                          }
                          return const SizedBox(height: 4);
                        }),
                        Row(
                          children: [
                            _buildEpisodeCounter(item),
                            const Spacer(),
                            // Replace MAL score with User's personal rating if present, or quick Rate prompt
                            if (item.userRating != null && item.userRating!.hasRating) ...[
                              InkWell(
                                onTap: () async {
                                  HapticFeedback.selectionClick();
                                  final rating = await UserRatingSheet.show(context, existing: item.userRating);
                                  if (rating != null && mounted) {
                                    await HiveService.updateUserRating(item.animeId, rating);
                                    setState(() {});
                                  }
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, size: 16, color: AppColors.starYellow),
                                      const SizedBox(width: 3),
                                      Text(
                                        item.userRating!.overall.toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.starYellow),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              InkWell(
                                onTap: () async {
                                  HapticFeedback.selectionClick();
                                  final rating = await UserRatingSheet.show(context, existing: item.userRating);
                                  if (rating != null && mounted) {
                                    await HiveService.updateUserRating(item.animeId, rating);
                                    setState(() {});
                                  }
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_outline_rounded, size: 14, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Rate',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if ((item.tags != null && item.tags!.isNotEmpty) || (item.personalNotes != null && item.personalNotes!.isNotEmpty)) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (item.personalNotes != null && item.personalNotes!.isNotEmpty) ...[
                                Icon(Icons.notes_rounded, size: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                const SizedBox(width: 4),
                              ],
                              if (item.tags != null && item.tags!.isNotEmpty)
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: item.tags!.take(3).map((t) => Container(
                                        margin: const EdgeInsets.only(right: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withAlpha(25),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '#$t',
                                          style: TextStyle(fontSize: 9.5, color: AppColors.accent, fontWeight: FontWeight.bold),
                                        ),
                                      )).toList(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // 3-Dots Dropdown Menu
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 2),
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      size: 20,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    onSelected: (action) async {
                      HapticFeedback.selectionClick();
                      if (action == 'category') {
                        final result = await CategoryPickerSheet.show(context, current: item.category);
                        if (result == null || !mounted) return;
                        switch (result) {
                          case CategorySelected(:final category):
                            await HiveService.updateCategory(item.animeId, category);
                          case DeleteFromList():
                            final deletedItem = item;
                            await HiveService.removeFromList(item.animeId);
                            setState(() {});
                            _showDeleteUndoToast(deletedItem);
                        }
                        if (mounted) setState(() {});
                      } else if (action == 'rate') {
                        final rating = await UserRatingSheet.show(context, existing: item.userRating);
                        if (rating != null && mounted) {
                          await HiveService.updateUserRating(item.animeId, rating);
                          setState(() {});
                        }
                      } else if (action == 'notes') {
                        PersonalNotesTagsSheet.show(
                          context,
                          item: item,
                          onSaved: () => setState(() {}),
                        );
                      } else if (action == 'remove') {
                        final deletedItem = item;
                        await HiveService.removeFromList(item.animeId);
                        setState(() {});
                        _showDeleteUndoToast(deletedItem);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'category',
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 18, color: categoryColor),
                            const SizedBox(width: 10),
                            Text(AppText.get('select_category')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rate',
                        child: Row(
                          children: [
                            Icon(
                              item.userRating != null && item.userRating!.hasRating ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 18,
                              color: AppColors.starYellow,
                            ),
                            const SizedBox(width: 10),
                            Text(AppText.get('your_rating')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'notes',
                        child: Row(
                          children: [
                            Icon(
                              (item.personalNotes != null && item.personalNotes!.isNotEmpty) || (item.tags != null && item.tags!.isNotEmpty)
                                  ? Icons.bookmark_added_rounded
                                  : Icons.bookmark_add_outlined,
                              size: 18,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 10),
                            const Text('Notes & Tags'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'remove',
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                            SizedBox(width: 10),
                            Text('Remove from List', style: TextStyle(color: AppColors.error)),
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
    );
  }

  Widget _buildGridCard(AnimeListItem item, Color categoryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int totalEp = int.tryParse(item.episodes) ?? 0;
    final progressRatio = totalEp > 0 ? (item.episodeProgress / totalEp).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onSelectAnime(item.animeId),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showGridItemOptions(item);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster with badges & bottom gradient
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.image,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.75),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Badges row
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (item.isMalSynced == true || (MalAuthService.instance.isLoggedIn && item.isMalSynced != false))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'MAL',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else
                            const SizedBox(),
                          if (item.userRating != null && item.userRating!.hasRating)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.starYellow.withOpacity(0.5), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 12, color: AppColors.starYellow),
                                  const SizedBox(width: 2),
                                  Text(
                                    item.userRating!.overall.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.starYellow,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (item.score != null && item.score! > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 12, color: AppColors.starYellow),
                                  const SizedBox(width: 2),
                                  Text(
                                    item.score!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Countdown badge
                    Builder(builder: (context) {
                      final countdown = AiringScheduleService.getCountdown(item.animeId, episodeProgress: item.episodeProgress);
                      if ((countdown.isAiring || countdown.isFinished) && countdown.countdownText != null) {
                        return Positioned(
                          bottom: 6,
                          left: 6,
                          child: _buildCountdownPill(countdown, isCompact: true),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    // Progress bar at bottom of poster
                    if (totalEp > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: progressRatio,
                          minHeight: 3.5,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                        ),
                      ),
                  ],
                ),
              ),
              // Card Details
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.episodeProgress} / ${totalEp > 0 ? totalEp.toString() : '?'} ep',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        // Quick +1 button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              int newProgress = item.episodeProgress + 1;
                              if (totalEp > 0 && newProgress > totalEp) return;
                              if (totalEp > 0 && newProgress == totalEp && item.category != AnimeCategory.completed) {
                                await HiveService.updateEpisodeProgress(item.animeId, newProgress);
                                setState(() {});
                                _checkCompleteDialog(item);
                                return;
                              }
                              HiveService.updateEpisodeProgress(item.animeId, newProgress);
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.add, size: 14, color: AppColors.accent),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((item.tags != null && item.tags!.isNotEmpty) || (item.personalNotes != null && item.personalNotes!.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (item.personalNotes != null && item.personalNotes!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 3),
                                child: Icon(Icons.notes_rounded, size: 10, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              ),
                            if (item.tags != null && item.tags!.isNotEmpty)
                              Expanded(
                                child: Text(
                                  item.tags!.map((t) => '#$t').join(' '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 9, color: AppColors.accent, fontWeight: FontWeight.bold),
                                ),
                              ),
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
    );
  }

  void _showGridItemOptions(AnimeListItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.swap_horiz_rounded, color: AppColors.accent),
                title: Text(AppText.get('select_category')),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await CategoryPickerSheet.show(context, current: item.category);
                  if (result == null || !mounted) return;
                  switch (result) {
                    case CategorySelected(:final category):
                      await HiveService.updateCategory(item.animeId, category);
                    case DeleteFromList():
                      final deletedItem = item;
                      await HiveService.removeFromList(item.animeId);
                      setState(() {});
                      _showDeleteUndoToast(deletedItem);
                  }
                  setState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_outline_rounded, color: AppColors.starYellow),
                title: Text(AppText.get('your_rating')),
                onTap: () async {
                  Navigator.pop(ctx);
                  final rating = await UserRatingSheet.show(context, existing: item.userRating);
                  if (rating != null && mounted) {
                    await HiveService.updateUserRating(item.animeId, rating);
                    setState(() {});
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_added_rounded, color: AppColors.completed),
                title: const Text('Personal Notes & Tags'),
                onTap: () {
                  Navigator.pop(ctx);
                  PersonalNotesTagsSheet.show(
                    context,
                    item: item,
                    onSaved: () => setState(() {}),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortFilterSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allGenres = _getAllGenres().toList()..sort();
    final allProducers = _getAllProducers().toList()..sort();
    final allTypes = _getAllTypes();
    final allYears = _getAllYears();
    final seasons = ['Spring', 'Summer', 'Fall', 'Winter'];
    final allTags = HiveService.getAllTags();

    final statusFilters = <Map<String, dynamic>>[
      {'id': 'airing', 'label': 'Airing Now', 'icon': Icons.sensors_rounded, 'color': const Color(0xFF10B981)},
      {'id': 'finished_airing', 'label': 'Finished Airing', 'icon': Icons.check_circle_outline_rounded, 'color': const Color(0xFF06B6D4)},
      {'id': 'unrated', 'label': 'Needs Rating', 'icon': Icons.star_outline_rounded, 'color': const Color(0xFFF59E0B)},
      {'id': 'behind', 'label': 'Behind', 'icon': Icons.timelapse_rounded, 'color': const Color(0xFFFF5722)},
      {'id': 'mal_synced', 'label': 'MAL Synced', 'icon': Icons.sync_rounded, 'color': const Color(0xFF2E51A2)},
      ...allTags.map((t) => {'id': 'tag:$t', 'label': '#$t', 'icon': Icons.label_rounded, 'color': const Color(0xFF8B5CF6)}),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          final hasActiveFilters = _activeFilterCount > 0;
          final currentCategory = _categories[_tabController.index];
          final matchingCount = _getSortedFiltered(currentCategory).length;

          return SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.88,
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header Row with fixed height to prevent vertical layout jump
                  SizedBox(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 22, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text(
                              AppText.get('sort_filter'),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (_activeFilterCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_activeFilterCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (hasActiveFilters)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _sortBy = 'date';
                                _filterStatuses.clear();
                                _filterGenres.clear();
                                _filterProducers.clear();
                                _filterTypes.clear();
                                _filterSeasons.clear();
                                _filterYears.clear();
                              });
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 15),
                            label: const Text('Reset All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Scrollable Filter Sections
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── 1. Sort By ──
                          _buildSectionHeader(
                            title: AppText.get('sort_by'),
                            icon: Icons.sort_rounded,
                            activeColor: AppColors.accent,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildColoredButton(
                                label: AppText.get('sort_by_date_added'),
                                icon: Icons.calendar_today_rounded,
                                isSelected: _sortBy == 'date',
                                activeColor: AppColors.accent,
                                onTap: () {
                                  setState(() => _sortBy = 'date');
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                              ),
                              _buildColoredButton(
                                label: AppText.get('sort_by_title'),
                                icon: Icons.sort_by_alpha_rounded,
                                isSelected: _sortBy == 'title',
                                activeColor: AppColors.accent,
                                onTap: () {
                                  setState(() => _sortBy = 'title');
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                              ),
                              _buildColoredButton(
                                label: AppText.get('sort_by_score'),
                                icon: Icons.star_rounded,
                                isSelected: _sortBy == 'score',
                                activeColor: AppColors.accent,
                                onTap: () {
                                  setState(() => _sortBy = 'score');
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                              ),
                              _buildColoredButton(
                                label: 'Episodes',
                                icon: Icons.video_library_rounded,
                                isSelected: _sortBy == 'episodes',
                                activeColor: AppColors.accent,
                                onTap: () {
                                  setState(() => _sortBy = 'episodes');
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                              ),
                              _buildColoredButton(
                                label: 'Season & Year',
                                icon: Icons.schedule_rounded,
                                isSelected: _sortBy == 'year_season',
                                activeColor: AppColors.accent,
                                onTap: () {
                                  setState(() => _sortBy = 'year_season');
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                              ),
                              _buildColoredButton(
                                label: 'Type',
                                icon: Icons.category_rounded,
                                isSelected: _sortBy == 'type',
                                activeColor: AppColors.accent,
                                onTap: () {
                                  setState(() => _sortBy = 'type');
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          // ── 2. Status & Airing (Moved to Sort & Filter, Multi-select!) ──
                          _buildSectionHeader(
                            title: 'Status & Airing',
                            icon: Icons.sensors_rounded,
                            activeColor: const Color(0xFF10B981),
                            activeCount: _filterStatuses.length,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: statusFilters.map((st) {
                              final id = st['id'] as String;
                              final isSelected = _filterStatuses.contains(id);
                              final color = st['color'] as Color;
                              return _buildColoredButton(
                                label: st['label'] as String,
                                icon: st['icon'] as IconData,
                                isSelected: isSelected,
                                activeColor: color,
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _filterStatuses.remove(id);
                                    } else {
                                      _filterStatuses.add(id);
                                    }
                                  });
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 22),

                          // ── 3. Media Type (Multi-select) ──
                          _buildSectionHeader(
                            title: 'Media Type',
                            icon: Icons.category_rounded,
                            activeColor: const Color(0xFF3B82F6),
                            activeCount: _filterTypes.length,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allTypes.map((t) {
                              final isSelected = _filterTypes.contains(t);
                              return _buildColoredButton(
                                label: t,
                                isSelected: isSelected,
                                activeColor: const Color(0xFF3B82F6),
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _filterTypes.remove(t);
                                    } else {
                                      _filterTypes.add(t);
                                    }
                                  });
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 22),

                          // ── 4. Season (Multi-select) ──
                          _buildSectionHeader(
                            title: 'Season',
                            icon: Icons.wb_sunny_rounded,
                            activeColor: const Color(0xFFF59E0B),
                            activeCount: _filterSeasons.length,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: seasons.map((s) {
                              final isSelected = _filterSeasons.contains(s);
                              final color = _seasonColor(s);
                              return _buildColoredButton(
                                label: s,
                                icon: _seasonIcon(s),
                                isSelected: isSelected,
                                activeColor: color,
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _filterSeasons.remove(s);
                                    } else {
                                      _filterSeasons.add(s);
                                    }
                                  });
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 22),

                          // ── 5. Genres (Expandable! First row space + extend/collapse button) ──
                          _buildExpandableSection(
                            title: 'Genres',
                            icon: Icons.tag_rounded,
                            items: allGenres,
                            selectedItems: _filterGenres,
                            activeColor: const Color(0xFF6366F1),
                            itemColor: _genreColor,
                            isExpanded: _genresExpanded,
                            onToggle: () {
                              setState(() => _genresExpanded = !_genresExpanded);
                              setSheetState(() {});
                            },
                            onSelect: (g) {
                              setState(() {
                                if (_filterGenres.contains(g)) {
                                  _filterGenres.remove(g);
                                } else {
                                  _filterGenres.add(g);
                                }
                              });
                              setSheetState(() {});
                            },
                            isDark: isDark,
                          ),
                          const SizedBox(height: 22),

                          // ── 6. Producers & Studios (Expandable! First row space + extend/collapse button) ──
                          _buildExpandableSection(
                            title: 'Producers & Studios',
                            icon: Icons.movie_filter_rounded,
                            items: allProducers,
                            selectedItems: _filterProducers,
                            activeColor: const Color(0xFFEC4899),
                            itemColor: _producerColor,
                            isExpanded: _producersExpanded,
                            onToggle: () {
                              setState(() => _producersExpanded = !_producersExpanded);
                              setSheetState(() {});
                            },
                            onSelect: (p) {
                              setState(() {
                                if (_filterProducers.contains(p)) {
                                  _filterProducers.remove(p);
                                } else {
                                  _filterProducers.add(p);
                                }
                              });
                              setSheetState(() {});
                            },
                            isDark: isDark,
                          ),
                          const SizedBox(height: 22),

                          // ── 7. Release Year (Expandable! First row space + extend/collapse button) ──
                          if (allYears.isNotEmpty) ...[
                            _buildExpandableSection(
                              title: 'Release Year',
                              icon: Icons.calendar_today_rounded,
                              items: allYears,
                              selectedItems: _filterYears,
                              activeColor: const Color(0xFF14B8A6),
                              isExpanded: _yearsExpanded,
                              onToggle: () {
                                setState(() => _yearsExpanded = !_yearsExpanded);
                                setSheetState(() {});
                              },
                              onSelect: (y) {
                                setState(() {
                                  if (_filterYears.contains(y)) {
                                    _filterYears.remove(y);
                                  } else {
                                    _filterYears.add(y);
                                  }
                                });
                                setSheetState(() {});
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Bottom Apply Button
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Show Results ($matchingCount ${_categoryLabel(currentCategory)})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color activeColor,
    int activeCount = 0,
    required bool isDark,
  }) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: activeCount > 0
                ? activeColor
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          if (activeCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: activeColor.withValues(alpha: 0.6), width: 1),
              ),
              child: Text(
                '$activeCount',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: activeColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColoredButton({
    required String label,
    IconData? icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? const Color(0xFF2E344A) : const Color(0xFFE2E8F0)),
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required List<String> items,
    required Set<String> selectedItems,
    required Color activeColor,
    Color Function(String item)? itemColor,
    required bool isExpanded,
    required VoidCallback onToggle,
    required void Function(String item) onSelect,
    required bool isDark,
    IconData? itemIcon,
  }) {
    final activeCount = items.where((it) => selectedItems.contains(it)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 28,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: activeCount > 0
                        ? activeColor
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: activeColor.withValues(alpha: 0.6), width: 1),
                      ),
                      child: Text(
                        '$activeCount',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: activeColor),
                      ),
                    ),
                  ],
                ],
              ),
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isExpanded ? 'Collapse' : 'Show All (${items.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isExpanded
                              ? activeColor
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: isExpanded
                            ? activeColor
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (isExpanded)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((it) {
              final isSelected = selectedItems.contains(it);
              final btnColor = itemColor != null ? itemColor(it) : activeColor;
              return _buildColoredButton(
                label: it,
                icon: itemIcon,
                isSelected: isSelected,
                activeColor: btnColor,
                onTap: () => onSelect(it),
                isDark: isDark,
              );
            }).toList(),
          )
        else
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final it = items[idx];
                final isSelected = selectedItems.contains(it);
                final btnColor = itemColor != null ? itemColor(it) : activeColor;
                return _buildColoredButton(
                  label: it,
                  icon: itemIcon,
                  isSelected: isSelected,
                  activeColor: btnColor,
                  onTap: () => onSelect(it),
                  isDark: isDark,
                );
              },
            ),
          ),
      ],
    );
  }
  Widget _buildEpisodeCounter(AnimeListItem item) {
    final int totalEp = int.tryParse(item.episodes) ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (item.episodeProgress > 0) {
                  HiveService.updateEpisodeProgress(item.animeId, item.episodeProgress - 1);
                  setState(() {});
                }
              },
              borderRadius: BorderRadius.circular(8),
              splashColor: AppColors.accent.withAlpha(40),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.remove, size: 16, color: AppColors.accent),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '${item.episodeProgress} / ${totalEp > 0 ? totalEp.toString() : '?'}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                HapticFeedback.lightImpact();
                int newProgress = item.episodeProgress + 1;
                if (totalEp > 0 && newProgress > totalEp) {
                  return; // Clamp at max episode
                }
                if (totalEp > 0 && newProgress == totalEp && item.category != AnimeCategory.completed) {
                  await HiveService.updateEpisodeProgress(item.animeId, newProgress);
                  setState(() {});
                  _checkCompleteDialog(item);
                  return;
                }
                HiveService.updateEpisodeProgress(item.animeId, newProgress);
                setState(() {});
              },
              borderRadius: BorderRadius.circular(8),
              splashColor: AppColors.accent.withAlpha(40),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add, size: 16, color: AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkCompleteDialog(AnimeListItem item) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppText.get('completed')),
        content: const Text("You've reached the final episode! Do you want to move this anime to your Completed list?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Keep")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Move")),
        ],
      ),
    );
    if (res == true && mounted) {
      await HiveService.updateCategory(item.animeId, AnimeCategory.completed);
      setState(() {});
    }
  }
}

class SpringyFadeIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  const SpringyFadeIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
