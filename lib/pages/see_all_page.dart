import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/models/anime_model.dart';
import '../core/theme/app_colors.dart';
import '../widgets/shimmer_loading.dart';

/// Generic "See All" page that supports:
/// - Grid display of an initial list
/// - Infinite scroll: calls [onLoadMore] to fetch the next page
/// - Horizontal mode (for reviews-like content) via [reviewMode]
class SeeAllPage extends StatefulWidget {
  final String title;
  final List<AnimeModel> animeList;
  final void Function(int animeId) onSelectAnime;

  /// Optional: async callback to load more items when scrolling near the end.
  /// Return [] if no more pages. [page] is 2-based (first extra page).
  final Future<List<AnimeModel>> Function(int page)? onLoadMore;

  /// Optional: reviews mode (renders horizontal review cards instead of anime grid)
  final bool reviewMode;
  final List<Map<String, dynamic>> reviewList;

  const SeeAllPage({
    super.key,
    required this.title,
    required this.animeList,
    required this.onSelectAnime,
    this.onLoadMore,
    this.reviewMode = false,
    this.reviewList = const [],
  });

  @override
  State<SeeAllPage> createState() => _SeeAllPageState();
}

class _SeeAllPageState extends State<SeeAllPage> {
  late List<AnimeModel> _items;
  late List<Map<String, dynamic>> _reviews;
  bool _loadingMore = false;
  bool _noMore = false;
  int _nextPage = 2; // We already have page 1
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _items   = List<AnimeModel>.from(widget.animeList);
    _reviews = List<Map<String, dynamic>>.from(widget.reviewList);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    // If no loadMore provided, mark no more
    if (widget.onLoadMore == null) _noMore = true;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.reviewMode) return; // reviews handle their own scroll
    if (_loadingMore || _noMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (widget.onLoadMore == null) return;
    setState(() => _loadingMore = true);
    try {
      // Add 1s gap between pages to respect rate limit
      await Future.delayed(const Duration(milliseconds: 1000));
      final more = await widget.onLoadMore!(_nextPage);
      if (!mounted) return;
      if (more.isEmpty) {
        setState(() { _noMore = true; _loadingMore = false; });
      } else {
        setState(() {
          _items.addAll(more);
          _nextPage++;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: widget.reviewMode ? _buildReviewBody(isDark) : _buildAnimeGrid(isDark),
    );
  }

  Widget _buildAnimeGrid(bool isDark) {
    if (_items.isEmpty) {
      return const Center(child: Text("No content to display"));
    }
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _items.length + (_loadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return ShimmerLoading.card(context: context);
        }
        final anime = _items[index];
        return GestureDetector(
          onTap: () => widget.onSelectAnime(anime.id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CachedNetworkImage(
                    imageUrl: anime.image,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: AppColors.starYellow),
                          const SizedBox(width: 4),
                          Text(anime.scoreDisplay, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewBody(bool isDark) {
    if (_reviews.isEmpty) {
      return const Center(child: Text("No reviews to display"));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildReviewCard(_reviews[index], isDark),
        );
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, bool isDark) {
    final user    = review['user'] ?? {};
    final anime   = review['entry'] ?? {};
    final score   = review['score'] ?? 0;
    final content = review['review'] ?? '';

    return Container(
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
                radius: 18,
                backgroundImage: user['images']?['jpg']?['image_url'] != null
                    ? NetworkImage(user['images']['jpg']['image_url'])
                    : null,
                backgroundColor: AppColors.accent.withAlpha(50),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['username'] ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("on ${anime['title'] ?? 'Anime'}",
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.starYellow.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.star, size: 14, color: AppColors.starYellow),
                  const SizedBox(width: 4),
                  Text("$score", style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.starYellow)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(fontSize: 13, height: 1.5,
                color: isDark ? Colors.white70 : Colors.black87),
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
