import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/app_text.dart';
import '../core/services/hive_service.dart';
import 'detail_page.dart';
import '../widgets/random_selector_sheet.dart';

class DataPage extends StatefulWidget {
  final void Function(int animeId)? onSelectAnime;

  const DataPage({super.key, this.onSelectAnime});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  String _searchQuery = '';
  final Set<String> _filterSeasons = {};
  final Set<String> _filterYears = {};
  final Set<String> _filterGenres = {};
  final Set<String> _filterTypes = {};
  final Set<String> _filterStatuses = {};
  final Set<String> _filterStudios = {};
  String _sortBy = 'title'; // title, score, year, episodes
  bool _isGridView = false;
  final Set<int> _reFetchingIds = {};

  int get _activeFilterCount =>
      (_sortBy != 'title' ? 1 : 0) +
      _filterSeasons.length +
      _filterYears.length +
      _filterGenres.length +
      _filterTypes.length +
      _filterStatuses.length +
      _filterStudios.length;

  bool _hasActiveFilters() => _activeFilterCount > 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              AppText.get('nav_data_page'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.casino_rounded),
            onPressed: () {
              HapticFeedback.selectionClick();
              RandomSelectorSheet.show(context);
            },
            tooltip: 'Random Anime / Manga',
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
            tooltip: _isGridView ? 'List View' : 'Grid View',
          ),
          IconButton(
            icon: Badge.count(
              count: _activeFilterCount,
              isLabelVisible: _activeFilterCount > 0,
              backgroundColor: AppColors.accent,
              textColor: Colors.white,
              child: const Icon(Icons.tune_rounded),
            ),
            onPressed: _showFilterSheet,
            tooltip: AppText.get('sort_filter'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: HiveService.appDataBoxListenable,
        builder: (context, box, _) {
          final allRaw = HiveService.getAllAppDataItems();
          final filtered = _filterAndSort(allRaw);

          return Column(
            children: [
              // Search Input matching MyListPage
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    decoration: InputDecoration(
                      hintText: '${AppText.get('search_anime')} (${allRaw.length} saved)',
                      hintStyle: TextStyle(color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                      prefixIcon: Icon(Icons.search, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // Active Filters Bar matching MyListPage
              _buildActiveFiltersBar(isDark),

              // Items Content
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.accent.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(
                              AppText.get('all_data_empty'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : _isGridView
                        ? GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.62,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) => _buildGridCard(filtered[i], isDark),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            itemCount: filtered.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 12),
                            itemBuilder: (context, i) => _buildListCard(filtered[i], isDark),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveFiltersBar(bool isDark) {
    if (_activeFilterCount == 0) return const SizedBox.shrink();

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Clear All Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _sortBy = 'title';
                  _filterSeasons.clear();
                  _filterYears.clear();
                  _filterGenres.clear();
                  _filterTypes.clear();
                  _filterStatuses.clear();
                  _filterStudios.clear();
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded, size: 13, color: AppColors.error),
                    SizedBox(width: 4),
                    Text(
                      'Clear All',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          if (_sortBy != 'title') ...[
            _buildActiveBadge(
              label: 'Sort: ${_sortLabel(_sortBy)}',
              icon: Icons.sort_rounded,
              color: AppColors.accent,
              onDelete: () => setState(() => _sortBy = 'title'),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
          ],
          ..._filterSeasons.map((s) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActiveBadge(
              label: s,
              icon: Icons.wb_sunny_outlined,
              color: const Color(0xFF3B82F6),
              onDelete: () => setState(() => _filterSeasons.remove(s)),
              isDark: isDark,
            ),
          )),
          ..._filterYears.map((y) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActiveBadge(
              label: y,
              icon: Icons.calendar_today_rounded,
              color: const Color(0xFFF59E0B),
              onDelete: () => setState(() => _filterYears.remove(y)),
              isDark: isDark,
            ),
          )),
          ..._filterGenres.map((g) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActiveBadge(
              label: g,
              icon: Icons.tag_rounded,
              color: const Color(0xFF8B5CF6),
              onDelete: () => setState(() => _filterGenres.remove(g)),
              isDark: isDark,
            ),
          )),
          ..._filterTypes.map((t) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActiveBadge(
              label: t,
              icon: Icons.category_rounded,
              color: const Color(0xFF06B6D4),
              onDelete: () => setState(() => _filterTypes.remove(t)),
              isDark: isDark,
            ),
          )),
          ..._filterStatuses.map((st) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActiveBadge(
              label: st,
              icon: Icons.sensors_rounded,
              color: const Color(0xFF10B981),
              onDelete: () => setState(() => _filterStatuses.remove(st)),
              isDark: isDark,
            ),
          )),
          ..._filterStudios.map((st) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActiveBadge(
              label: st,
              icon: Icons.movie_filter_rounded,
              color: const Color(0xFFEC4899),
              onDelete: () => setState(() => _filterStudios.remove(st)),
              isDark: isDark,
            ),
          )),
        ],
      ),
    );
  }

  String _sortLabel(String s) {
    switch (s) {
      case 'score': return AppText.get('sort_by_score');
      case 'year': return 'Year';
      case 'episodes': return 'Episodes';
      case 'title':
      default: return AppText.get('sort_by_title');
    }
  }


  Widget _buildActiveBadge({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onDelete,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : color,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onDelete();
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 13, color: isDark ? Colors.white70 : color),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterAndSort(List<Map<String, dynamic>> items) {
    var result = HiveService.filterExcludedMaps(List<Map<String, dynamic>>.from(items));

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((m) {
        final title = (m['title'] ?? '').toString().toLowerCase();
        final titleJp = (m['title_japanese'] ?? '').toString().toLowerCase();
        return title.contains(q) || titleJp.contains(q);
      }).toList();
    }

    if (_filterSeasons.isNotEmpty) {
      result = result.where((m) {
        final season = (m['season'] ?? '').toString().toLowerCase();
        return _filterSeasons.any((s) => s.toLowerCase() == season);
      }).toList();
    }

    if (_filterYears.isNotEmpty) {
      result = result.where((m) {
        final year = (m['year'] ?? '').toString();
        return _filterYears.contains(year);
      }).toList();
    }

    if (_filterGenres.isNotEmpty) {
      result = result.where((m) {
        final genres = m['genres'];
        if (genres is List) {
          final itemGenres = genres.map((g) => (g is Map ? g['name'] : g).toString().toLowerCase()).toSet();
          return _filterGenres.any((fg) => itemGenres.contains(fg.toLowerCase()));
        }
        return false;
      }).toList();
    }

    if (_filterTypes.isNotEmpty) {
      result = result.where((m) {
        final type = (m['type'] ?? '').toString().toLowerCase();
        return _filterTypes.any((t) => t.toLowerCase() == type);
      }).toList();
    }

    if (_filterStatuses.isNotEmpty) {
      result = result.where((m) {
        final status = (m['status'] ?? '').toString().toLowerCase();
        return _filterStatuses.any((st) => status.contains(st.toLowerCase()));
      }).toList();
    }

    if (_filterStudios.isNotEmpty) {
      result = result.where((m) {
        final studios = m['studios'];
        if (studios is List) {
          final itemStudios = studios.map((s) => (s is Map ? s['name'] : s).toString().toLowerCase()).toSet();
          return _filterStudios.any((fs) => itemStudios.contains(fs.toLowerCase()));
        }
        return false;
      }).toList();
    }

    // Sort
    result.sort((a, b) {
      if (_sortBy == 'score') {
        final sa = (a['score'] as num?)?.toDouble() ?? 0.0;
        final sb = (b['score'] as num?)?.toDouble() ?? 0.0;
        return sb.compareTo(sa);
      } else if (_sortBy == 'year') {
        final ya = int.tryParse(a['year']?.toString() ?? '') ?? 0;
        final yb = int.tryParse(b['year']?.toString() ?? '') ?? 0;
        return yb.compareTo(ya);
      } else if (_sortBy == 'episodes') {
        final ea = int.tryParse(a['episodes']?.toString() ?? '') ?? 0;
        final eb = int.tryParse(b['episodes']?.toString() ?? '') ?? 0;
        return eb.compareTo(ea);
      } else {
        final ta = (a['title'] ?? '').toString().toLowerCase();
        final tb = (b['title'] ?? '').toString().toLowerCase();
        return ta.compareTo(tb);
      }
    });

    return result;
  }

  void _openDetail(int animeId) {
    if (widget.onSelectAnime != null) {
      widget.onSelectAnime!(animeId);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => DetailPage(
          key: ValueKey('anime_$animeId'),
          animeId: animeId,
          onBack: () => Navigator.of(ctx).pop(),
        ),
      ));
    }
  }

  Future<void> _refetch(int animeId) async {
    setState(() => _reFetchingIds.add(animeId));
    try {
      final updated = await HiveService.refetchAppDataItem(animeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updated?.title ?? "Anime"} - ${AppText.get("item_re_fetched")}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reFetchingIds.remove(animeId));
    }
  }

  void _delete(Map<String, dynamic> item) {
    final animeId = (item['mal_id'] ?? item['id']) as int;
    final deletedBackup = Map<String, dynamic>.from(item);
    HiveService.deleteFromAppData(animeId);
    setState(() {});

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item['title']} - ${AppText.get('item_removed')}'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: AppText.get('undo'),
          textColor: AppColors.accent,
          onPressed: () async {
            await HiveService.saveAppDataMapDirectly(animeId, deletedBackup);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildListCard(Map<String, dynamic> item, bool isDark) {
    final animeId = (item['mal_id'] ?? item['id']) as int? ?? 0;
    final title = item['title']?.toString() ?? 'Unknown';
    final imageUrl = item['images']?['jpg']?['large_image_url'] ??
        item['images']?['jpg']?['image_url'] ??
        item['image']?.toString() ??
        '';
    final score = (item['score'] as num?)?.toDouble();
    final year = item['year']?.toString();
    final season = item['season']?.toString();
    final episodes = item['episodes']?.toString() ?? '?';
    final isReFetching = _reFetchingIds.contains(animeId);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(animeId),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Full Height Left Poster matching MyListPage
                SizedBox(
                  width: 96,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                        ),
                      ),
                      if (score != null && score > 0)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 12, color: AppColors.starYellow),
                                const SizedBox(width: 2.5),
                                Text(
                                  score.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Info Section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            height: 1.25,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Metadata Badges (Season, Year, Ep count)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (season != null && season.isNotEmpty && season != 'Unknown')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.25), width: 0.7),
                                ),
                                child: Text(
                                  season.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            if (year != null && year.isNotEmpty && year != 'Unknown')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  year,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ),
                            Text(
                              '$episodes Ep',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const SizedBox(height: 6),
                        // Actions row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: isReFetching ? null : () => _refetch(animeId),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isReFetching)
                                      const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.8))
                                    else
                                      Icon(Icons.sync_rounded, size: 14, color: isDark ? Colors.white70 : Colors.black87),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Sync',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _delete(item),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.error),
                                    SizedBox(width: 4),
                                    Text(
                                      'Delete',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(Map<String, dynamic> item, bool isDark) {
    final animeId = (item['mal_id'] ?? item['id']) as int? ?? 0;
    final title = item['title']?.toString() ?? 'Unknown';
    final imageUrl = item['images']?['jpg']?['large_image_url'] ??
        item['images']?['jpg']?['image_url'] ??
        item['image']?.toString() ??
        '';
    final score = (item['score'] as num?)?.toDouble();
    final year = item['year']?.toString();
    final season = item['season']?.toString();
    final episodes = item['episodes']?.toString() ?? '?';
    final isReFetching = _reFetchingIds.contains(animeId);

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
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(animeId),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster with badges & bottom gradient matching MyListPage
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Action controls floating top right
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              icon: isReFetching
                                  ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white))
                                  : const Icon(Icons.sync_rounded, size: 14, color: Colors.white),
                              onPressed: isReFetching ? null : () => _refetch(animeId),
                              tooltip: AppText.get('refetch_item'),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.error),
                              onPressed: () => _delete(item),
                              tooltip: AppText.get('delete_item'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (score != null && score > 0)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 11, color: AppColors.starYellow),
                              const SizedBox(width: 2.5),
                              Text(
                                score.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (season != null && season.isNotEmpty && season != 'Unknown')
                          Text(
                            '${season.toUpperCase()} ',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent),
                          ),
                        if (year != null && year.isNotEmpty && year != 'Unknown')
                          Text(
                            '$year · ',
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        Text(
                          '$episodes Ep',
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
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

  void _showFilterSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allItems = HiveService.getAllAppDataItems();
    final seasons = ['Winter', 'Spring', 'Summer', 'Fall'];
    final years = allItems
        .map((m) => m['year']?.toString())
        .where((y) => y != null && y.isNotEmpty && y != 'Unknown')
        .cast<String>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final genres = <String>{};
    for (final m in allItems) {
      final gList = m['genres'];
      if (gList is List) {
        for (final g in gList) {
          final name = (g is Map ? g['name'] : g)?.toString();
          if (name != null && name.isNotEmpty) genres.add(name);
        }
      }
    }
    final sortedGenres = genres.toList()..sort();

    final types = allItems
        .map((m) => m['type']?.toString())
        .where((t) => t != null && t.isNotEmpty && t != 'Unknown')
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    final statuses = allItems
        .map((m) => m['status']?.toString())
        .where((s) => s != null && s.isNotEmpty && s != 'Unknown')
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    final studios = <String>{};
    for (final m in allItems) {
      final sList = m['studios'];
      if (sList is List) {
        for (final s in sList) {
          final name = (s is Map ? s['name'] : s)?.toString();
          if (name != null && name.isNotEmpty) studios.add(name);
        }
      }
    }
    final sortedStudios = studios.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final hasFilters = _hasActiveFilters();
          final matchingCount = _filterAndSort(allItems).length;

          return SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.88,
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle pill matching MyListPage
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
                        if (hasFilters)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _sortBy = 'title';
                                _filterSeasons.clear();
                                _filterYears.clear();
                                _filterGenres.clear();
                                _filterTypes.clear();
                                _filterStatuses.clear();
                                _filterStudios.clear();
                              });
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 15),
                            label: const Text('Reset All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Scrollable sections
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Sort By
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
                                label: 'Year',
                                icon: Icons.calendar_today_rounded,
                                isSelected: _sortBy == 'year',
                                activeColor: AppColors.accent,
                                onTap: () {
                                  setState(() => _sortBy = 'year');
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
                            ],
                          ),
                          const SizedBox(height: 22),

                          // 2. Season (Multi-select)
                          _buildSectionHeader(
                            title: 'Season',
                            icon: Icons.wb_sunny_outlined,
                            activeColor: const Color(0xFF3B82F6),
                            activeCount: _filterSeasons.length,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildColoredButton(
                                label: 'All',
                                isSelected: _filterSeasons.isEmpty,
                                activeColor: const Color(0xFF3B82F6),
                                onTap: () {
                                  setState(() => _filterSeasons.clear());
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                              ),
                              ...seasons.map((s) => _buildColoredButton(
                                label: s,
                                isSelected: _filterSeasons.contains(s),
                                activeColor: const Color(0xFF3B82F6),
                                onTap: () {
                                  setState(() {
                                    if (_filterSeasons.contains(s)) {
                                      _filterSeasons.remove(s);
                                    } else {
                                      _filterSeasons.add(s);
                                    }
                                  });
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                              )),
                            ],
                          ),
                          const SizedBox(height: 22),

                          // 3. Year (Multi-select, horizontal scroll)
                          if (years.isNotEmpty) ...[
                            _buildSectionHeader(
                              title: 'Year',
                              icon: Icons.calendar_today_rounded,
                              activeColor: const Color(0xFFF59E0B),
                              activeCount: _filterYears.length,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 38,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildColoredButton(
                                    label: 'All',
                                    isSelected: _filterYears.isEmpty,
                                    activeColor: const Color(0xFFF59E0B),
                                    onTap: () {
                                      setState(() => _filterYears.clear());
                                      setSheetState(() {});
                                    },
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 8),
                                  ...years.map((y) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _buildColoredButton(
                                      label: y,
                                      isSelected: _filterYears.contains(y),
                                      activeColor: const Color(0xFFF59E0B),
                                      onTap: () {
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
                                  )),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                          ],

                          // 4. Genres (Multi-select)
                          if (sortedGenres.isNotEmpty) ...[
                            _buildSectionHeader(
                              title: 'Genres',
                              icon: Icons.tag_rounded,
                              activeColor: const Color(0xFF8B5CF6),
                              activeCount: _filterGenres.length,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildColoredButton(
                                  label: 'All',
                                  isSelected: _filterGenres.isEmpty,
                                  activeColor: const Color(0xFF8B5CF6),
                                  onTap: () {
                                    setState(() => _filterGenres.clear());
                                    setSheetState(() {});
                                  },
                                  isDark: isDark,
                                ),
                                ...sortedGenres.map((g) => _buildColoredButton(
                                  label: g,
                                  isSelected: _filterGenres.contains(g),
                                  activeColor: const Color(0xFF8B5CF6),
                                  onTap: () {
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
                                )),
                              ],
                            ),
                            const SizedBox(height: 22),
                          ],

                          // 5. Media Type (Multi-select)
                          if (types.isNotEmpty) ...[
                            _buildSectionHeader(
                              title: 'Media Type',
                              icon: Icons.category_rounded,
                              activeColor: const Color(0xFF06B6D4),
                              activeCount: _filterTypes.length,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildColoredButton(
                                  label: 'All',
                                  isSelected: _filterTypes.isEmpty,
                                  activeColor: const Color(0xFF06B6D4),
                                  onTap: () {
                                    setState(() => _filterTypes.clear());
                                    setSheetState(() {});
                                  },
                                  isDark: isDark,
                                ),
                                ...types.map((t) => _buildColoredButton(
                                  label: t,
                                  isSelected: _filterTypes.contains(t),
                                  activeColor: const Color(0xFF06B6D4),
                                  onTap: () {
                                    setState(() {
                                      if (_filterTypes.contains(t)) {
                                        _filterTypes.remove(t);
                                      } else {
                                        _filterTypes.add(t);
                                      }
                                    });
                                    setSheetState(() {});
                                  },
                                  isDark: isDark,
                                )),
                              ],
                            ),
                            const SizedBox(height: 22),
                          ],

                          // 6. Status & Airing (Multi-select)
                          if (statuses.isNotEmpty) ...[
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
                              children: [
                                _buildColoredButton(
                                  label: 'All',
                                  isSelected: _filterStatuses.isEmpty,
                                  activeColor: const Color(0xFF10B981),
                                  onTap: () {
                                    setState(() => _filterStatuses.clear());
                                    setSheetState(() {});
                                  },
                                  isDark: isDark,
                                ),
                                ...statuses.map((st) => _buildColoredButton(
                                  label: st,
                                  isSelected: _filterStatuses.contains(st),
                                  activeColor: const Color(0xFF10B981),
                                  onTap: () {
                                    setState(() {
                                      if (_filterStatuses.contains(st)) {
                                        _filterStatuses.remove(st);
                                      } else {
                                        _filterStatuses.add(st);
                                      }
                                    });
                                    setSheetState(() {});
                                  },
                                  isDark: isDark,
                                )),
                              ],
                            ),
                            const SizedBox(height: 22),
                          ],

                          // 7. Studios (Multi-select)
                          if (sortedStudios.isNotEmpty) ...[
                            _buildSectionHeader(
                              title: 'Studios & Producers',
                              icon: Icons.movie_filter_rounded,
                              activeColor: const Color(0xFFEC4899),
                              activeCount: _filterStudios.length,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildColoredButton(
                                  label: 'All',
                                  isSelected: _filterStudios.isEmpty,
                                  activeColor: const Color(0xFFEC4899),
                                  onTap: () {
                                    setState(() => _filterStudios.clear());
                                    setSheetState(() {});
                                  },
                                  isDark: isDark,
                                ),
                                ...sortedStudios.map((s) => _buildColoredButton(
                                  label: s,
                                  isSelected: _filterStudios.contains(s),
                                  activeColor: const Color(0xFFEC4899),
                                  onTap: () {
                                    setState(() {
                                      if (_filterStudios.contains(s)) {
                                        _filterStudios.remove(s);
                                      } else {
                                        _filterStudios.add(s);
                                      }
                                    });
                                    setSheetState(() {});
                                  },
                                  isDark: isDark,
                                )),
                              ],
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
                        'Show Results ($matchingCount saved)',
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
}
