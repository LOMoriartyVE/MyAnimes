import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/app_text.dart';
import '../core/services/hive_service.dart';
import 'detail_page.dart';

class DataPage extends StatefulWidget {
  final void Function(int animeId)? onSelectAnime;

  const DataPage({super.key, this.onSelectAnime});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  String _searchQuery = '';
  String _filterSeason = '';
  String _filterYear = '';
  String _filterGenre = '';
  String _filterStudio = '';
  String _filterStatus = '';
  String _sortBy = 'title'; // title, score, year, episodes
  bool _isGridView = false;
  final Set<int> _reFetchingIds = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppText.get('nav_data_page'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
            tooltip: _isGridView ? 'List View' : 'Grid View',
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showFilterSheet,
            tooltip: AppText.get('sort_filter'),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: HiveService.appDataBoxListenable,
        builder: (context, box, _) {
          final allRaw = HiveService.getAllAppDataItems();
          final filtered = _filterAndSort(allRaw);

          return Column(
            children: [
              // Search Input
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

              // Active Filters Row
              if (_hasActiveFilters())
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_sortBy != 'title')
                          _activeChip('Sort: $_sortBy', () => setState(() => _sortBy = 'title')),
                        if (_filterSeason.isNotEmpty)
                          _activeChip('Season: $_filterSeason', () => setState(() => _filterSeason = '')),
                        if (_filterYear.isNotEmpty)
                          _activeChip('Year: $_filterYear', () => setState(() => _filterYear = '')),
                        if (_filterGenre.isNotEmpty)
                          _activeChip('Genre: $_filterGenre', () => setState(() => _filterGenre = '')),
                        if (_filterStudio.isNotEmpty)
                          _activeChip('Studio: $_filterStudio', () => setState(() => _filterStudio = '')),
                        if (_filterStatus.isNotEmpty)
                          _activeChip('Status: $_filterStatus', () => setState(() => _filterStatus = '')),
                      ],
                    ),
                  ),
                ),

              // Items Content
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.accent.withAlpha(80)),
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
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _buildListCard(filtered[i], isDark),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _hasActiveFilters() =>
      _sortBy != 'title' ||
      _filterSeason.isNotEmpty ||
      _filterYear.isNotEmpty ||
      _filterGenre.isNotEmpty ||
      _filterStudio.isNotEmpty ||
      _filterStatus.isNotEmpty;

  Widget _activeChip(String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        deleteIcon: const Icon(Icons.close, size: 12),
        onDeleted: onDeleted,
        visualDensity: VisualDensity.compact,
        backgroundColor: AppColors.accent.withAlpha(25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.accent.withAlpha(60)),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterAndSort(List<Map<String, dynamic>> items) {
    var result = List<Map<String, dynamic>>.from(items);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((m) {
        final title = (m['title'] ?? '').toString().toLowerCase();
        final titleJp = (m['title_japanese'] ?? '').toString().toLowerCase();
        return title.contains(q) || titleJp.contains(q);
      }).toList();
    }

    if (_filterSeason.isNotEmpty) {
      result = result.where((m) => (m['season'] ?? '').toString().toLowerCase() == _filterSeason.toLowerCase()).toList();
    }

    if (_filterYear.isNotEmpty) {
      result = result.where((m) => (m['year'] ?? '').toString() == _filterYear).toList();
    }

    if (_filterGenre.isNotEmpty) {
      result = result.where((m) {
        final genres = m['genres'];
        if (genres is List) {
          return genres.any((g) => (g is Map ? g['name'] : g).toString().toLowerCase() == _filterGenre.toLowerCase());
        }
        return false;
      }).toList();
    }

    if (_filterStudio.isNotEmpty) {
      result = result.where((m) {
        final studios = m['studios'];
        if (studios is List) {
          return studios.any((s) => (s is Map ? s['name'] : s).toString().toLowerCase() == _filterStudio.toLowerCase());
        }
        return false;
      }).toList();
    }

    if (_filterStatus.isNotEmpty) {
      result = result.where((m) => (m['status'] ?? '').toString().toLowerCase().contains(_filterStatus.toLowerCase())).toList();
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
        builder: (ctx) => DetailPage(animeId: animeId, onBack: () => Navigator.of(ctx).pop()),
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

    return InkWell(
      onTap: () => _openDetail(animeId),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 64,
                height: 90,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 64,
                  height: 90,
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  child: const Icon(Icons.broken_image_outlined, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (score != null && score > 0) ...[
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.starYellow),
                        const SizedBox(width: 3),
                        Text(
                          score.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.starYellow),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (year != null && year.isNotEmpty && year != 'Unknown')
                        Text('$year ', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                      if (season != null && season.isNotEmpty)
                        Text('${season.toUpperCase()} ', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                      Text('· $episodes Ep', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: isReFetching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_rounded, size: 20),
                  onPressed: isReFetching ? null : () => _refetch(animeId),
                  tooltip: AppText.get('refetch_item'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                  onPressed: () => _delete(item),
                  tooltip: AppText.get('delete_item'),
                ),
              ],
            ),
          ],
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
    final isReFetching = _reFetchingIds.contains(animeId);

    return InkWell(
      onTap: () => _openDetail(animeId),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            icon: isReFetching
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.sync_rounded, size: 16, color: Colors.white),
                            onPressed: isReFetching ? null : () => _refetch(animeId),
                            tooltip: AppText.get('refetch_item'),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: AppColors.starYellow),
                            const SizedBox(width: 3),
                            Text(
                              score.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final allItems = HiveService.getAllAppDataItems();
    final seasons = ['winter', 'spring', 'summer', 'fall'];
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return SafeArea(
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppText.get('sort_filter'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _sortBy = 'title';
                              _filterSeason = '';
                              _filterYear = '';
                              _filterGenre = '';
                              _filterStudio = '';
                              _filterStatus = '';
                            });
                            setSheetState(() {});
                          },
                          child: const Text('Reset All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: ['title', 'score', 'year', 'episodes'].map((s) {
                        final sel = _sortBy == s;
                        return ChoiceChip(
                          label: Text(s.toUpperCase()),
                          selected: sel,
                          onSelected: (_) {
                            setState(() => _sortBy = s);
                            setSheetState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Season', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _filterSeason.isEmpty,
                          onSelected: (_) {
                            setState(() => _filterSeason = '');
                            setSheetState(() {});
                          },
                        ),
                        ...seasons.map((s) => ChoiceChip(
                              label: Text(s.toUpperCase()),
                              selected: _filterSeason == s,
                              onSelected: (_) {
                                setState(() => _filterSeason = s);
                                setSheetState(() {});
                              },
                            )),
                      ],
                    ),
                    if (years.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Year', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _filterYear.isEmpty,
                              onSelected: (_) {
                                setState(() => _filterYear = '');
                                setSheetState(() {});
                              },
                            ),
                            const SizedBox(width: 8),
                            ...years.map((y) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(y),
                                    selected: _filterYear == y,
                                    onSelected: (_) {
                                      setState(() => _filterYear = y);
                                      setSheetState(() {});
                                    },
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                    if (sortedGenres.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Genres', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _filterGenre.isEmpty,
                              onSelected: (_) {
                                setState(() => _filterGenre = '');
                                setSheetState(() {});
                              },
                            ),
                            const SizedBox(width: 8),
                            ...sortedGenres.map((g) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(g),
                                    selected: _filterGenre == g,
                                    onSelected: (_) {
                                      setState(() => _filterGenre = g);
                                      setSheetState(() {});
                                    },
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
