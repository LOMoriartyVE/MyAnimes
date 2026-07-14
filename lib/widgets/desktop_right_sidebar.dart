import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_list_item.dart';
import '../core/models/anime_model.dart';
import '../core/services/hive_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DesktopRightSidebar extends StatefulWidget {
  final void Function(int) onSelectAnime;

  const DesktopRightSidebar({
    super.key,
    required this.onSelectAnime,
  });

  @override
  State<DesktopRightSidebar> createState() => _DesktopRightSidebarState();
}

class _DesktopRightSidebarState extends State<DesktopRightSidebar> {
  List<AnimeListItem> _continueWatching = [];
  List<AnimeModel> _newEpisodes = [];
  List<AnimeModel> _topRated = [];

  @override
  void initState() {
    super.initState();
    _loadSidebarData();
  }

  void _loadSidebarData() {
    // 1. Continue Watching: load items marked as "watching"
    final allItems = HiveService.getAllListItems();
    final watchingItems = allItems.where((item) => item.category == 'watching').toList();
    
    // 2. New Episodes: load seasonal anime
    List<AnimeModel> seasonal = [];
    final cachedSeason = HiveService.getCachedSeasonAllPages();
    if (cachedSeason != null && cachedSeason.isNotEmpty) {
      seasonal = cachedSeason.map((m) => AnimeModel.fromJson(m)).toList();
    }

    // 3. Top Rated: load top anime
    List<AnimeModel> top = [];
    final cachedTop = HiveService.getCachedTopAnime();
    if (cachedTop != null && cachedTop.isNotEmpty) {
      top = cachedTop.map((m) => AnimeModel.fromJson(m)).toList();
    }

    setState(() {
      _continueWatching = watchingItems;
      _newEpisodes = seasonal;
      _topRated = top;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark ? const Color(0xFF13141B) : const Color(0xFFF9F9FC);

    return Container(
      width: 320,
      color: sidebarBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section 1: Continue Watching ──
            _buildSectionHeader('Continue Watching'),
            const SizedBox(height: 12),
            if (_continueWatching.isEmpty)
              _buildEmptyState('No anime in watchlist.', onSuggest: () {
                // Add some default suggestions if list is empty
              })
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _continueWatching.length.clamp(0, 3),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildContinueWatchingCard(_continueWatching[index]);
                },
              ),

            const SizedBox(height: 32),

            // ── Section 2: New Episodes This Week ──
            _buildSectionHeader('New Episodes This Week'),
            const SizedBox(height: 12),
            if (_newEpisodes.isEmpty)
              _buildEmptyState('No updates this week.')
            else
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newEpisodes.length.clamp(0, 8),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _buildNewEpisodeCard(_newEpisodes[index]);
                  },
                ),
              ),

            const SizedBox(height: 32),

            // ── Section 3: Top Rated ──
            _buildSectionHeader('Top Rated'),
            const SizedBox(height: 12),
            if (_topRated.isEmpty)
              _buildEmptyState('No top rated loaded.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topRated.length.clamp(0, 4),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildTopRatedCard(_topRated[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : Colors.black87,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildEmptyState(String message, {VoidCallback? onSuggest}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C24) : const Color(0xFFEEEEF4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildContinueWatchingCard(AnimeListItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF191B24) : Colors.white;
    final borderColor = isDark ? const Color(0xFF222533) : const Color(0xFFE5E5ED);

    int maxEps = 0;
    if (item.episodes != 'Unknown') {
      maxEps = int.tryParse(item.episodes) ?? 0;
    }
    final progressVal = maxEps > 0 ? (item.episodeProgress / maxEps).clamp(0.0, 1.0) : 0.0;
    final rating = item.userRating?.overall ?? (item.score ?? 0.0);

    return GestureDetector(
      onTap: () => widget.onSelectAnime(item.animeId),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: item.image,
                width: 52,
                height: 68,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ep ${item.episodeProgress}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progressVal,
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                            color: AppColors.accent,
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 13, color: AppColors.starYellow),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewEpisodeCard(AnimeModel anime) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => widget.onSelectAnime(anime.id),
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: anime.image,
                    width: 110,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                // Episode Overlay
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Ep. ${anime.episodes ?? '?'}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Rating Overlay
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 10, color: AppColors.starYellow),
                        const SizedBox(width: 1.5),
                        Text(
                          anime.scoreDisplay,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.2,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRatedCard(AnimeModel anime) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => widget.onSelectAnime(anime.id),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF191B24) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF222533) : const Color(0xFFE5E5ED)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: anime.image,
                width: 36,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anime.status,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 14, color: AppColors.starYellow),
                const SizedBox(width: 2),
                Text(
                  anime.scoreDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
