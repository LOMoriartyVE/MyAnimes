import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_model.dart';
import '../core/models/anime_relation_item.dart';
import 'detail_page.dart';

class FranchiseTimelinePage extends StatefulWidget {
  final AnimeModel currentAnime;
  final List<AnimeRelationItem> timelineItems;
  final VoidCallback onBack;

  const FranchiseTimelinePage({
    super.key,
    required this.currentAnime,
    required this.timelineItems,
    required this.onBack,
  });

  @override
  State<FranchiseTimelinePage> createState() => _FranchiseTimelinePageState();
}

class _FranchiseTimelinePageState extends State<FranchiseTimelinePage> {
  String _selectedFilter = 'all';

  Color _getRelationColor(String relationType, bool isCurrent) {
    if (isCurrent) return AppColors.accent;
    final lower = relationType.toLowerCase();
    if (lower.contains('prequel')) return const Color(0xFF3B82F6);
    if (lower.contains('sequel')) return const Color(0xFF8B5CF6);
    if (lower.contains('parent story') || lower.contains('full story')) return const Color(0xFF6366F1);
    if (lower.contains('side story')) return const Color(0xFF10B981);
    if (lower.contains('spin-off') || lower.contains('spinoff')) return const Color(0xFFF59E0B);
    if (lower.contains('movie')) return const Color(0xFFEC4899);
    if (lower.contains('alternative') || lower.contains('other')) return const Color(0xFFA855F7);
    if (lower.contains('summary')) return const Color(0xFF06B6D4);
    if (lower.contains('character')) return const Color(0xFFF43F5E);
    return const Color(0xFF64748B);
  }

  IconData _getRelationIcon(String relationType, bool isCurrent) {
    if (isCurrent) return Icons.star_rounded;
    final lower = relationType.toLowerCase();
    if (lower.contains('prequel')) return Icons.skip_previous_rounded;
    if (lower.contains('sequel')) return Icons.skip_next_rounded;
    if (lower.contains('side story')) return Icons.alt_route_rounded;
    if (lower.contains('spin-off') || lower.contains('spinoff')) return Icons.shuffle_rounded;
    if (lower.contains('movie')) return Icons.movie_outlined;
    if (lower.contains('alternative')) return Icons.swap_horiz_rounded;
    if (lower.contains('summary')) return Icons.summarize_outlined;
    return Icons.link_rounded;
  }

  List<AnimeRelationItem> get _filteredItems {
    if (_selectedFilter == 'all') return widget.timelineItems;
    if (_selectedFilter == 'main') {
      return widget.timelineItems.where((i) {
        final t = i.relationType.toLowerCase();
        return i.malId == widget.currentAnime.id ||
            t.contains('prequel') ||
            t.contains('sequel') ||
            t.contains('parent');
      }).toList();
    }
    if (_selectedFilter == 'movies') {
      return widget.timelineItems.where((i) {
        final t = i.relationType.toLowerCase();
        final f = (i.format ?? '').toLowerCase();
        return t.contains('movie') || f == 'movie';
      }).toList();
    }
    if (_selectedFilter == 'side') {
      return widget.timelineItems.where((i) {
        final t = i.relationType.toLowerCase();
        return t.contains('side') || t.contains('spin') || t.contains('ova') || t.contains('special');
      }).toList();
    }
    return widget.timelineItems;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0F15) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF141721) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Franchise Universe Timeline',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            Text(
              widget.currentAnime.title,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? const Color(0xFF141721).withOpacity(0.6) : Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('all', 'All Entries (${widget.timelineItems.length})', isDark),
                  const SizedBox(width: 8),
                  _filterChip('main', 'Main Story & Seasons', isDark),
                  const SizedBox(width: 8),
                  _filterChip('movies', 'Movies', isDark),
                  const SizedBox(width: 8),
                  _filterChip('side', 'Side Stories & Spin-offs', isDark),
                ],
              ),
            ),
          ),
          // Timeline List
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No entries found for this filter.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isCurrent = item.malId == widget.currentAnime.id;
                      final isFirst = index == 0;
                      final isLast = index == items.length - 1;
                      return _buildTimelineRow(item, isCurrent, isFirst, isLast, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String id, String label, bool isDark) {
    final isSelected = _selectedFilter == id;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _selectedFilter = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineRow(
    AnimeRelationItem item,
    bool isCurrent,
    bool isFirst,
    bool isLast,
    bool isDark,
  ) {
    final color = _getRelationColor(item.relationType, isCurrent);
    final icon = _getRelationIcon(item.relationType, isCurrent);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Spine with Node Dot & Year
          SizedBox(
            width: 72,
            child: Column(
              children: [
                // Top Connector line
                Expanded(
                  flex: 1,
                  child: Container(
                    width: 2.5,
                    color: isFirst
                        ? Colors.transparent
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
                // Timeline Node Dot & Year
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent ? color : color.withOpacity(0.18),
                    border: Border.all(color: color, width: 2),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 14,
                    color: isCurrent ? Colors.white : color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.year ?? '—',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isCurrent ? color : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                // Bottom Connector line
                Expanded(
                  flex: 2,
                  child: Container(
                    width: 2.5,
                    color: isLast
                        ? Colors.transparent
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Anime Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () {
                  if (isCurrent) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailPage(
                        key: ValueKey('anime_${item.malId}'),
                        animeId: item.malId,
                        onBack: () => Navigator.of(context).pop(),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? color.withOpacity(isDark ? 0.16 : 0.08)
                        : (isDark ? AppColors.darkCard : AppColors.lightCard),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent
                          ? color
                          : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      width: isCurrent ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Cover Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: (item.image != null && item.image!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: item.image!,
                                width: 56,
                                height: 78,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 56,
                                  height: 78,
                                  color: Colors.white10,
                                  child: const Icon(Icons.movie, color: Colors.white24),
                                ),
                              )
                            : Container(
                                width: 56,
                                height: 78,
                                color: Colors.white10,
                                child: const Icon(Icons.movie, color: Colors.white24),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: color.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    isCurrent ? '★ Current Entry' : item.relationType,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (item.format != null && item.format!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.format!,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (item.episodes != null && item.episodes! > 0)
                                  Text(
                                    '${item.episodes} eps',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                if (item.episodes != null && item.episodes! > 0 && item.status != null)
                                  Text(
                                    ' · ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                if (item.status != null)
                                  Text(
                                    item.status!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isCurrent)
                        Icon(
                          Icons.chevron_right_rounded,
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
