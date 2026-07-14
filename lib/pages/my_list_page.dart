import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_list_item.dart';
import '../core/services/hive_service.dart';
import '../core/localization/app_text.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/category_picker.dart';
import '../widgets/user_rating_sheet.dart';
import 'status_page.dart';
import 'share_layered_list_page.dart';

class MyListPage extends StatefulWidget {
  final void Function(int animeId) onSelectAnime;

  const MyListPage({super.key, required this.onSelectAnime});

  @override
  State<MyListPage> createState() => _MyListPageState();
}

class _MyListPageState extends State<MyListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _sortBy = 'date'; // date, title, score
  String _filterGenre = '';

  final List<AnimeCategory> _categories = [
    AnimeCategory.watching,
    AnimeCategory.completed,
    AnimeCategory.planned,
    AnimeCategory.ignored,
  ];
  
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
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
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      items = items.where((i) => i.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'title':
        items.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'score':
        items.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
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
    return genres;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<Box<AnimeListItem>>(
      valueListenable: HiveService.listBoxListenable,
      builder: (context, box, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: SafeArea(
                bottom: false,
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
                          icon: const Icon(Icons.analytics_outlined),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                               builder: (context) => const StatusPage()
                            ));
                          },
                          tooltip: 'Stats',
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
                border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ),
              padding: const EdgeInsets.all(6),
              child: Row(
                children: _categories.map((cat) {
                  final count = box.values.where((item) => item.category == cat).length;
                  final isSelected = _tabController.index == _categories.indexOf(cat);
                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        _tabController.animateTo(_categories.indexOf(cat));
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${_categoryLabel(cat)} ($count)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white60 : Colors.black54),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
        );
      },
    );
  }

  Widget _buildCategoryList(AnimeCategory category) {
    final items = _getSortedFiltered(category);
    final color = _categoryColor(category);

    if (items.isEmpty) {
      return Center(
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
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final delay = Duration(milliseconds: (index * 40).clamp(0, 400));
        return SpringyFadeIn(
          key: ValueKey('anim_item_${item.animeId}'),
          delay: delay,
          child: _buildListTile(item, color),
        );
      },
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
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: CachedNetworkImage(
                  imageUrl: item.image,
                  width: 80,
                  height: 110,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 80, height: 110,
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  ),
                  errorListener: (_) {},
                  errorWidget: (_, __, ___) => Container(
                    width: 80, height: 110,
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
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
                          if (item.isMalSynced == true) ...[
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
                      const SizedBox(height: 4),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildEpisodeCounter(item),
                          const Spacer(),
                          const Icon(Icons.star_rounded, size: 14, color: AppColors.starYellow),
                          const SizedBox(width: 3),
                          Text(item.scoreDisplay, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      if (item.userRating != null && item.userRating!.hasRating) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.rate_review_outlined, size: 14, color: categoryColor),
                            const SizedBox(width: 4),
                            Text(
                              '${AppText.get('your_rating')}: ${item.userRating!.overall.toStringAsFixed(1)}',
                              style: TextStyle(fontSize: 12, color: categoryColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Actions
              Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.swap_horiz, size: 20, color: categoryColor),
                    onPressed: () async {
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
                    tooltip: AppText.get('select_category'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.star_outline, size: 20),
                    onPressed: () async {
                      final rating = await UserRatingSheet.show(context, existing: item.userRating);
                      if (rating != null && mounted) {
                        await HiveService.updateUserRating(item.animeId, rating);
                        setState(() {});
                      }
                    },
                    tooltip: AppText.get('your_rating'),
                  ),
                ],
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

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                  const SizedBox(height: 20),
                  Text(AppText.get('sort_filter'), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  Text(AppText.get('sort_by'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _sortChip('date', AppText.get('sort_by_date_added'), setSheetState),
                      _sortChip('title', AppText.get('sort_by_title'), setSheetState),
                      _sortChip('score', AppText.get('sort_by_score'), setSheetState),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(AppText.get('filter_by_genre'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _genreChip('', AppText.get('all_genres'), setSheetState),
                        const SizedBox(width: 8),
                        ...allGenres.map((g) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _genreChip(g, g, setSheetState),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              if (item.episodeProgress > 0) {
                HiveService.updateEpisodeProgress(item.animeId, item.episodeProgress - 1);
                setState(() {});
              }
            },
            child: Icon(Icons.remove, size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Text(
            '${item.episodeProgress} / ${totalEp > 0 ? totalEp.toString() : '?'}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () async {
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
            child: Icon(Icons.add, size: 20, color: AppColors.accent),
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

class SpringyFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const SpringyFadeIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<SpringyFadeIn> createState() => _SpringyFadeInState();
}

class _SpringyFadeInState extends State<SpringyFadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const ElasticOutCurve(0.9),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
