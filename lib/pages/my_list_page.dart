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
  String _filterGenre = '';
  String _filterType = '';
  String _filterSeason = '';
  String _filterYear = '';
  String _quickFilter = 'all'; // 'all', 'airing', 'unrated', 'behind', 'mal_synced', or 'tag:xyz'

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    // Filter by genre
    if (_filterGenre.isNotEmpty) {
      items = items.where((i) => i.genres.contains(_filterGenre)).toList();
    }
    
    // Filter by type
    if (_filterType.isNotEmpty) {
      items = items.where((i) => (i.type ?? '').toLowerCase() == _filterType.toLowerCase()).toList();
    }

    // Filter by season
    if (_filterSeason.isNotEmpty) {
      items = items.where((i) => (i.season ?? '').toLowerCase() == _filterSeason.toLowerCase()).toList();
    }

    // Filter by year
    if (_filterYear.isNotEmpty) {
      items = items.where((i) => i.year == _filterYear).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      items = items.where((i) => i.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // Quick filter
    if (_quickFilter == 'airing') {
      items = items.where((i) {
        final info = AiringScheduleService.getCountdown(i.animeId, episodeProgress: i.episodeProgress);
        return info.isAiring;
      }).toList();
    } else if (_quickFilter == 'finished_airing') {
      items = items.where((i) {
        final info = AiringScheduleService.getCountdown(i.animeId, episodeProgress: i.episodeProgress);
        final totalEp = int.tryParse(i.episodes) ?? 0;
        return info.isFinished || i.category == AnimeCategory.completed || (totalEp > 0 && i.episodeProgress >= totalEp);
      }).toList();
    } else if (_quickFilter == 'unrated') {
      items = items.where((i) => i.userRating == null || !i.userRating!.hasRating).toList();
    } else if (_quickFilter == 'behind') {
      items = items.where((i) {
        final totalEp = int.tryParse(i.episodes) ?? 0;
        return totalEp > 0 && i.episodeProgress < totalEp;
      }).toList();
    } else if (_quickFilter == 'mal_synced') {
      items = items.where((i) => i.isMalSynced == true).toList();
    } else if (_quickFilter.startsWith('tag:')) {
      final tag = _quickFilter.substring(4);
      items = items.where((i) => i.tags != null && i.tags!.contains(tag)).toList();
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
      'Action', 'Adventure', 'Comedy', 'Drama', 'Fantasy', 'Horror',
      'Mahou Shoujo', 'Mecha', 'Music', 'Mystery', 'Psychological',
      'Romance', 'Sci-Fi', 'Slice of Life', 'Sports', 'Supernatural', 'Thriller'
    ]);
    return genres;
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
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppText.get('nav_my_list'),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
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
                        IconButton(
                          icon: const Icon(Icons.tune_rounded),
                          onPressed: _showSortFilterSheet,
                          tooltip: AppText.get('sort_filter'),
                        ),
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

            // Quick Filter Chips
            _buildQuickFilterBar(isDark),

            if (_sortBy != 'date' || _filterGenre.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                     if (_sortBy != 'date')
                      Chip(
                        avatar: Icon(Icons.sort_rounded, size: 14, color: AppColors.accent),
                        label: Text(
                          'Sort: ${_sortBy.substring(0, 1).toUpperCase()}${_sortBy.substring(1)}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 12),
                        onDeleted: () {
                          setState(() {
                            _sortBy = 'date';
                          });
                        },
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.accent.withAlpha(20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppColors.accent.withAlpha(50)),
                        ),
                      ),
                    if (_filterGenre.isNotEmpty)
                      Chip(
                        avatar: Icon(Icons.filter_list_rounded, size: 14, color: AppColors.accent),
                        label: Text(
                          'Genre: $_filterGenre',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 12),
                        onDeleted: () {
                          setState(() {
                            _filterGenre = '';
                          });
                        },
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.accent.withAlpha(20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppColors.accent.withAlpha(50)),
                        ),
                      ),
                  ],
                ),
              ),

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
                          final count = box.values.where((item) => item.category == cat).length;
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

  Widget _buildQuickFilterBar(bool isDark) {
    final allTags = HiveService.getAllTags();
    final filters = <Map<String, dynamic>>[
      {'id': 'all', 'label': 'All', 'icon': Icons.clear_all_rounded},
      {'id': 'airing', 'label': 'Airing Now', 'icon': Icons.sensors_rounded},
      {'id': 'finished_airing', 'label': 'Finished Airing', 'icon': Icons.check_circle_outline_rounded},
      {'id': 'unrated', 'label': 'Needs Rating', 'icon': Icons.star_outline_rounded},
      {'id': 'behind', 'label': 'Behind', 'icon': Icons.timelapse_rounded},
      {'id': 'mal_synced', 'label': 'MAL Synced', 'icon': Icons.sync_rounded},
      ...allTags.map((t) => {'id': 'tag:$t', 'label': '#$t', 'icon': Icons.label_rounded}),
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final id = f['id'] as String;
          final isSelected = _quickFilter == id;

          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _quickFilter = isSelected && id != 'all' ? 'all' : id;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.brandGradient : null,
                color: isSelected
                    ? null
                    : (isDark ? AppColors.darkCard : AppColors.lightCard),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  width: 1,
                ),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    f['icon'] as IconData,
                    size: 13,
                    color: isSelected
                        ? Colors.white
                        : (id == 'airing'
                            ? Colors.deepOrange
                            : (id == 'finished_airing'
                                ? Colors.teal
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    f['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
      deltaColor = baseColor;
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
        HiveService.removeFromList(item.animeId);
        setState(() {});
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
                            await HiveService.removeFromList(item.animeId);
                        }
                        setState(() {});
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
                        await HiveService.removeFromList(item.animeId);
                        setState(() {});
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
                      await HiveService.removeFromList(item.animeId);
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
    final allTypes = _getAllTypes();
    final allYears = _getAllYears();
    final seasons = ['Spring', 'Summer', 'Fall', 'Winter'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          final hasActiveFilters = _filterGenre.isNotEmpty ||
              _filterType.isNotEmpty ||
              _filterSeason.isNotEmpty ||
              _filterYear.isNotEmpty ||
              _sortBy != 'date';

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppText.get('sort_filter'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        if (hasActiveFilters)
                          TextButton.icon(
                            onPressed: () {
                              setSheetState(() {});
                              setState(() {
                                _sortBy = 'date';
                                _filterGenre = '';
                                _filterType = '';
                                _filterSeason = '';
                                _filterYear = '';
                              });
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reset All', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // ── Sort By ──
                    Text(AppText.get('sort_by'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _sortChip('date', AppText.get('sort_by_date_added'), setSheetState),
                        _sortChip('title', AppText.get('sort_by_title'), setSheetState),
                        _sortChip('score', AppText.get('sort_by_score'), setSheetState),
                        _sortChip('episodes', 'Episodes', setSheetState),
                        _sortChip('year_season', 'Season & Year', setSheetState),
                        _sortChip('type', 'Type', setSheetState),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Filter by Genre ──
                    Text('Genres', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _filterChip('', AppText.get('all_genres'), _filterGenre, (v) => setState(() => _filterGenre = v), setSheetState),
                          const SizedBox(width: 8),
                          ...allGenres.map((g) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _filterChip(g, g, _filterGenre, (v) => setState(() => _filterGenre = v), setSheetState),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Filter by Type ──
                    Text('Media Type', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _filterChip('', 'All Types', _filterType, (v) => setState(() => _filterType = v), setSheetState),
                        ...allTypes.map((t) => _filterChip(t, t, _filterType, (v) => setState(() => _filterType = v), setSheetState)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Filter by Season ──
                    Text('Season', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _filterChip('', 'All Seasons', _filterSeason, (v) => setState(() => _filterSeason = v), setSheetState),
                        ...seasons.map((s) => _filterChip(s, s, _filterSeason, (v) => setState(() => _filterSeason = v), setSheetState)),
                      ],
                    ),
                    
                    if (allYears.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      // ── Filter by Year ──
                      Text('Release Year', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _filterChip('', 'All Years', _filterYear, (v) => setState(() => _filterYear = v), setSheetState),
                            const SizedBox(width: 8),
                            ...allYears.map((y) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _filterChip(y, y, _filterYear, (v) => setState(() => _filterYear = v), setSheetState),
                            )),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _sortChip(String value, String label, StateSetter setSheetState) {
    final isActive = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) {
        setSheetState(() {});
        setState(() => _sortBy = value);
      },
      selectedColor: AppColors.accent.withAlpha(40),
      checkmarkColor: AppColors.accent,
    );
  }

  Widget _filterChip(String value, String label, String currentVal, Function(String) onSelect, StateSetter setSheetState) {
    final isActive = currentVal == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isActive,
      onSelected: (_) {
        setSheetState(() {});
        onSelect(value);
      },
      selectedColor: AppColors.accent.withAlpha(40),
      checkmarkColor: AppColors.accent,
    );
  }

  Widget _genreChip(String value, String label, StateSetter setSheetState) {
    final isActive = _filterGenre == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isActive,
      onSelected: (_) {
        setSheetState(() {});
        setState(() => _filterGenre = value);
      },
      selectedColor: AppColors.accent.withAlpha(40),
      checkmarkColor: AppColors.accent,
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
