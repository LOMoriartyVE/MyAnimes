import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/services/jikan_service.dart';
import '../core/localization/app_text.dart';
import '../core/models/anime_list_item.dart';
import '../core/models/anime_model.dart';
import '../pages/detail_page.dart';
import '../pages/manga_detail_page.dart';
import 'category_picker.dart';

enum MediumFilter { all, anime, manga }
enum SourceFilter { planToWatch, myListAll, discover }

class RandomCandidate {
  final int id;
  final String title;
  final String? romajiTitle;
  final String image;
  final double? score;
  final String type;
  final bool isManga;
  final String episodesOrChapters;
  final List<String> genres;
  final List<String> studios;
  final String? synopsis;
  final String? year;
  final String sourceLabel;

  RandomCandidate({
    required this.id,
    required this.title,
    this.romajiTitle,
    required this.image,
    this.score,
    required this.type,
    required this.isManga,
    required this.episodesOrChapters,
    required this.genres,
    this.studios = const [],
    this.synopsis,
    this.year,
    required this.sourceLabel,
  });
}

class RandomSelectorSheet extends StatefulWidget {
  final ScrollController? scrollController;

  const RandomSelectorSheet({super.key, this.scrollController});

  static Future<void> show(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 650;
    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 780),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(28)),
              child: const RandomSelectorSheet(),
            ),
          ),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: RandomSelectorSheet(scrollController: scrollController),
          ),
        ),
      );
    }
  }

  @override
  State<RandomSelectorSheet> createState() => _RandomSelectorSheetState();
}

class _RandomSelectorSheetState extends State<RandomSelectorSheet>
    with SingleTickerProviderStateMixin {
  MediumFilter _medium = MediumFilter.anime;
  SourceFilter _source = SourceFilter.planToWatch;
  String _selectedGenre = 'All';
  String _selectedProducer = 'All';
  double _minScore = 0.0;

  bool _genresExpanded = false;
  bool _producersExpanded = false;
  String _genreSearchQuery = '';
  String _producerSearchQuery = '';
  final TextEditingController _genreSearchController = TextEditingController();
  final TextEditingController _producerSearchController = TextEditingController();
  List<Map<String, dynamic>> _fetchedProducers = [];

  late AnimationController _spinController;
  late Animation<double> _spinAnimation;

  bool _isSpinning = false;
  RandomCandidate? _selectedCandidate;
  RandomCandidate? _animatingCandidate;
  bool _synopsisExpanded = false;

  static const List<String> _baseGenres = [
    'Action',
    'Adventure',
    'Avant Garde',
    'Award Winning',
    'Boys Love',
    'Comedy',
    'Cyberpunk',
    'Demons',
    'Drama',
    'Ecchi',
    'Fantasy',
    'Girls Love',
    'Gourmet',
    'Harem',
    'Historical',
    'Horror',
    'Isekai',
    'Iyashikei',
    'Josei',
    'Kids',
    'Magic',
    'Mahou Shoujo',
    'Martial Arts',
    'Mecha',
    'Military',
    'Music',
    'Mystery',
    'Mythology',
    'Parody',
    'Psychological',
    'Racing',
    'Reincarnation',
    'Romance',
    'Samurai',
    'School',
    'Sci-Fi',
    'Seinen',
    'Shoujo',
    'Shounen',
    'Slice of Life',
    'Space',
    'Sports',
    'Super Power',
    'Supernatural',
    'Suspense',
    'Time Travel',
    'Vampire',
  ];

  static const List<String> _baseProducers = [
    'MAPPA',
    'ufotable',
    'Bones',
    'Madhouse',
    'Wit Studio',
    'Kyoto Animation',
    'A-1 Pictures',
    'CloverWorks',
    'Toei Animation',
    'Trigger',
    'Studio Ghibli',
    'Shaft',
    'J.C.Staff',
    'Production I.G',
    'TMS Entertainment',
    'Pierrot',
    'Sunrise',
    'David Production',
    'White Fox',
    'Silver Link.',
    'Doga Kobo',
    'Lerche',
    'Tatsunoko Production',
    'P.A. Works',
    'Kinema Citrus',
    'CoMix Wave Films',
    'Studio Deen',
    'Brain\'s Base',
    'Science SARU',
    'LIDENFILMS',
    'Feel',
    'Project No.9',
    'ENGI',
    'Passione',
    'Bibury Animation Studios',
    'Studio Bind',
    'OLM',
    'Telecom Animation Film',
    'Nippon Animation',
    'Gonzo',
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _spinAnimation = CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeOutCubic,
    );

    // If user's plan to watch is empty, default source to My List All or Discover
    final planned = HiveService.getAllListItems().where((i) => i.category == AnimeCategory.planned).toList();
    if (planned.isEmpty) {
      final all = HiveService.getAllListItems();
      _source = all.isNotEmpty ? SourceFilter.myListAll : SourceFilter.discover;
    }

    // Pre-fetch Jikan producers in background to enrich producer pool
    JikanService.getProducers().then((list) {
      if (mounted && list.isNotEmpty) {
        setState(() {
          _fetchedProducers = list;
        });
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _genreSearchController.dispose();
    _producerSearchController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  List<String> _getGenres() {
    final set = <String>{};
    set.addAll(_baseGenres);

    final cached = HiveService.getCachedGenres();
    if (cached != null) {
      for (final g in cached) {
        final name = (g['name'] ?? g['genre'])?.toString().trim();
        if (name != null && name.isNotEmpty) set.add(name);
      }
    }

    for (final item in HiveService.getAllListItems()) {
      set.addAll(item.genres);
    }

    for (final item in HiveService.getAllAppDataItems()) {
      if (item['genres'] is List) {
        for (final g in (item['genres'] as List)) {
          final name = (g is Map ? g['name'] : g)?.toString().trim();
          if (name != null && name.isNotEmpty) set.add(name);
        }
      }
    }

    // Filter out user-excluded categories
    final excluded = HiveService.excludedCategories.map((e) => e.toLowerCase()).toSet();
    set.removeWhere((g) => excluded.contains(g.toLowerCase()));

    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...list];
  }

  List<String> _getProducers() {
    final set = <String>{};
    set.addAll(_baseProducers);

    for (final item in HiveService.getAllListItems()) {
      if (item.studios != null) {
        for (final s in item.studios!) {
          final trimmed = s.trim();
          if (trimmed.isNotEmpty && trimmed != 'Unknown Studio' && trimmed != 'Unknown') {
            set.add(trimmed);
          }
        }
      }
    }

    for (final item in HiveService.getAllAppDataItems()) {
      if (item['studios'] is List) {
        for (final s in (item['studios'] as List)) {
          final name = (s is Map ? s['name'] : s)?.toString().trim();
          if (name != null && name.isNotEmpty && name != 'Unknown Studio' && name != 'Unknown') {
            set.add(name);
          }
        }
      }
      if (item['producers'] is List) {
        for (final p in (item['producers'] as List)) {
          final name = (p is Map ? p['name'] : p)?.toString().trim();
          if (name != null && name.isNotEmpty && name != 'Unknown') {
            set.add(name);
          }
        }
      }
    }

    for (final p in _fetchedProducers) {
      final name = (p['titles']?[0]?['title'] ?? p['name'])?.toString().trim();
      if (name != null && name.isNotEmpty) {
        set.add(name);
      }
    }

    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...list];
  }

  bool _isItemManga(dynamic item) {
    if (item is AnimeListItem) {
      final t = (item.type ?? '').toLowerCase();
      if (t == 'manga' || t == 'manhwa' || t == 'manhua' || t == 'novel' || t == 'light novel' || t == 'one-shot') {
        return true;
      }
      return HiveService.getCachedMangaDetail(item.animeId) != null;
    } else if (item is Map) {
      final t = (item['type'] ?? '').toString().toLowerCase();
      return t == 'manga' || t == 'manhwa' || t == 'manhua' || t == 'novel' || t == 'light novel' || t == 'one-shot';
    }
    return false;
  }

  List<RandomCandidate> _gatherCandidates() {
    final List<RandomCandidate> candidates = [];

    // 1. From My List
    if (_source == SourceFilter.planToWatch || _source == SourceFilter.myListAll) {
      final all = HiveService.getAllListItems();
      final items = _source == SourceFilter.planToWatch
          ? all.where((i) => i.category == AnimeCategory.planned).toList()
          : all;

      for (final item in items) {
        final isManga = _isItemManga(item);
        if (_medium == MediumFilter.anime && isManga) continue;
        if (_medium == MediumFilter.manga && !isManga) continue;

        if (_minScore > 0 && (item.score == null || item.score! < _minScore)) continue;

        if (_selectedGenre != 'All') {
          final hasGenre = item.genres.any((g) => g.toLowerCase() == _selectedGenre.toLowerCase());
          if (!hasGenre) continue;
        }

        List<String> studios = item.studios != null ? List<String>.from(item.studios!) : [];
        if (studios.isEmpty) {
          final detail = HiveService.getCachedAnimeDetail(item.animeId);
          if (detail != null && detail['studios'] is List) {
            studios = (detail['studios'] as List)
                .map((s) => (s is Map ? s['name'] : s).toString())
                .where((s) => s.isNotEmpty && s != 'Unknown Studio' && s != 'Unknown')
                .toList();
          }
        }

        if (_selectedProducer != 'All') {
          if (isManga) continue;
          final hasProducer = studios.any((s) => s.toLowerCase() == _selectedProducer.toLowerCase());
          if (!hasProducer) continue;
        }

        String label = _source == SourceFilter.planToWatch ? 'Plan to Watch' : 'From My List';
        candidates.add(RandomCandidate(
          id: item.animeId,
          title: item.title,
          image: item.image,
          score: item.score,
          type: item.type ?? (isManga ? 'Manga' : 'Anime'),
          isManga: isManga,
          episodesOrChapters: isManga ? '${item.episodes} Ch' : '${item.episodes} Ep',
          genres: item.genres,
          studios: studios,
          year: item.year,
          sourceLabel: label,
        ));
      }
    }

    // 2. Discover / Top & App Data
    if (_source == SourceFilter.discover || candidates.isEmpty) {
      // Anime candidates
      if (_medium != MediumFilter.manga) {
        final appData = HiveService.getAllAppDataItems();
        for (final item in appData) {
          final isManga = _isItemManga(item);
          if (isManga) continue;

          final id = (item['mal_id'] ?? item['id']) as int? ?? 0;
          if (id <= 0) continue;

          final score = (item['score'] as num?)?.toDouble();
          if (_minScore > 0 && (score == null || score < _minScore)) continue;

          List<String> genres = [];
          if (item['genres'] is List) {
            genres = (item['genres'] as List)
                .map((g) => (g is Map ? g['name'] : g).toString())
                .toList();
          }

          if (_selectedGenre != 'All') {
            final has = genres.any((g) => g.toLowerCase() == _selectedGenre.toLowerCase());
            if (!has) continue;
          }

          List<String> studios = [];
          if (item['studios'] is List) {
            studios.addAll((item['studios'] as List)
                .map((s) => (s is Map ? s['name'] : s).toString())
                .where((s) => s.isNotEmpty && s != 'Unknown Studio' && s != 'Unknown'));
          }
          if (item['producers'] is List) {
            studios.addAll((item['producers'] as List)
                .map((p) => (p is Map ? p['name'] : p).toString())
                .where((p) => p.isNotEmpty && p != 'Unknown'));
          }

          if (_selectedProducer != 'All') {
            final has = studios.any((s) => s.toLowerCase() == _selectedProducer.toLowerCase());
            if (!has) continue;
          }

          final img = item['images']?['jpg']?['large_image_url'] ??
              item['images']?['jpg']?['image_url'] ??
              item['image']?.toString() ??
              '';

          candidates.add(RandomCandidate(
            id: id,
            title: item['title']?.toString() ?? 'Anime #$id',
            romajiTitle: item['title_japanese']?.toString(),
            image: img,
            score: score,
            type: item['type']?.toString() ?? 'TV',
            isManga: false,
            episodesOrChapters: '${item['episodes'] ?? '?'} Ep',
            genres: genres,
            studios: studios,
            synopsis: item['synopsis']?.toString(),
            year: item['year']?.toString(),
            sourceLabel: 'Discover • App Data',
          ));
        }

        // Also check top cached anime
        final topAnime = HiveService.getCachedTopAnime() ?? [];
        for (final item in topAnime) {
          final id = (item['mal_id'] ?? item['id']) as int? ?? 0;
          if (id <= 0 || candidates.any((c) => c.id == id && !c.isManga)) continue;

          final score = (item['score'] as num?)?.toDouble();
          if (_minScore > 0 && (score == null || score < _minScore)) continue;

          List<String> genres = [];
          if (item['genres'] is List) {
            genres = (item['genres'] as List)
                .map((g) => (g is Map ? g['name'] : g).toString())
                .toList();
          }

          if (_selectedGenre != 'All') {
            final has = genres.any((g) => g.toLowerCase() == _selectedGenre.toLowerCase());
            if (!has) continue;
          }

          List<String> studios = [];
          if (item['studios'] is List) {
            studios.addAll((item['studios'] as List)
                .map((s) => (s is Map ? s['name'] : s).toString())
                .where((s) => s.isNotEmpty && s != 'Unknown Studio' && s != 'Unknown'));
          }
          if (item['producers'] is List) {
            studios.addAll((item['producers'] as List)
                .map((p) => (p is Map ? p['name'] : p).toString())
                .where((p) => p.isNotEmpty && p != 'Unknown'));
          }

          if (_selectedProducer != 'All') {
            final has = studios.any((s) => s.toLowerCase() == _selectedProducer.toLowerCase());
            if (!has) continue;
          }

          final img = item['images']?['jpg']?['large_image_url'] ??
              item['images']?['jpg']?['image_url'] ??
              item['image']?.toString() ??
              '';

          candidates.add(RandomCandidate(
            id: id,
            title: item['title']?.toString() ?? 'Anime #$id',
            romajiTitle: item['title_japanese']?.toString(),
            image: img,
            score: score,
            type: item['type']?.toString() ?? 'TV',
            isManga: false,
            episodesOrChapters: '${item['episodes'] ?? '?'} Ep',
            genres: genres,
            studios: studios,
            synopsis: item['synopsis']?.toString(),
            year: item['year']?.toString(),
            sourceLabel: 'Discover • Top Rated',
          ));
        }
      }

      // Manga candidates (only include if no specific anime producer is selected)
      if (_medium != MediumFilter.anime && _selectedProducer == 'All') {
        final topManga = HiveService.getCachedTopManga() ?? [];
        for (final item in topManga) {
          final id = (item['mal_id'] ?? item['id']) as int? ?? 0;
          if (id <= 0) continue;

          final score = (item['score'] as num?)?.toDouble();
          if (_minScore > 0 && (score == null || score < _minScore)) continue;

          List<String> genres = [];
          if (item['genres'] is List) {
            genres = (item['genres'] as List)
                .map((g) => (g is Map ? g['name'] : g).toString())
                .toList();
          }

          if (_selectedGenre != 'All') {
            final has = genres.any((g) => g.toLowerCase() == _selectedGenre.toLowerCase());
            if (!has) continue;
          }

          final img = item['images']?['jpg']?['large_image_url'] ??
              item['images']?['jpg']?['image_url'] ??
              item['image']?.toString() ??
              '';

          candidates.add(RandomCandidate(
            id: id,
            title: item['title']?.toString() ?? 'Manga #$id',
            romajiTitle: item['title_japanese']?.toString(),
            image: img,
            score: score,
            type: item['type']?.toString() ?? 'Manga',
            isManga: true,
            episodesOrChapters: '${item['chapters'] ?? '?'} Ch',
            genres: genres,
            studios: const [],
            synopsis: item['synopsis']?.toString(),
            year: item['published']?['prop']?['from']?['year']?.toString(),
            sourceLabel: 'Discover • Top Manga',
          ));
        }
      }
    }

    // Filter out user-excluded categories
    candidates.removeWhere((c) => HiveService.isExcluded(genres: c.genres, type: c.type));

    return candidates;
  }

  void _rollDice() async {
    if (_isSpinning) return;
    HapticFeedback.heavyImpact();

    final candidates = _gatherCandidates();
    if (candidates.isEmpty) {
      final filters = <String>[];
      if (_selectedGenre != 'All') filters.add('Genre: $_selectedGenre');
      if (_selectedProducer != 'All') filters.add('Studio: $_selectedProducer');
      if (_minScore > 0) filters.add('Score ≥ $_minScore');

      final details = filters.isNotEmpty ? ' (${filters.join(', ')})' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No titles match your selected filters$details! Try choosing another option.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSpinning = true;
      _synopsisExpanded = false;
    });

    _spinController.reset();
    _spinController.forward();

    final random = Random();
    final totalSteps = 16;
    for (int i = 0; i < totalSteps; i++) {
      await Future.delayed(Duration(milliseconds: 30 + (i * 8)));
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _animatingCandidate = candidates[random.nextInt(candidates.length)];
      });
    }

    // Pick final winner
    final winner = candidates[random.nextInt(candidates.length)];

    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    HapticFeedback.vibrate();
    setState(() {
      _isSpinning = false;
      _selectedCandidate = winner;
      _animatingCandidate = null;
    });
  }

  void _openDetails(RandomCandidate candidate) {
    if (candidate.isManga) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => MangaDetailPage(
            mangaId: candidate.id,
            onBack: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => DetailPage(
            animeId: candidate.id,
            onBack: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    }
  }

  Future<void> _addToList(RandomCandidate candidate) async {
    final existing = HiveService.getListItem(candidate.id);
    final result = await CategoryPickerSheet.show(context, current: existing?.category);
    if (result == null || !mounted) return;

    if (result is CategorySelected) {
      if (existing != null) {
        await HiveService.updateCategory(candidate.id, result.category);
      } else {
        final dummyAnime = AnimeModel(
          id: candidate.id,
          title: candidate.title,
          image: candidate.image,
          score: candidate.score,
          genres: candidate.genres,
          type: candidate.type,
          episodes: candidate.episodesOrChapters.replaceAll(RegExp(r'[^0-9]'), ''),
          year: candidate.year ?? '',
        );
        await HiveService.addToList(AnimeListItem.fromAnime(dummyAnime, result.category));
      }
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${candidate.title} added to list!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.completed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final candidateToShow = _animatingCandidate ?? _selectedCandidate;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.casino_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Random Selector',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                      ),
                      Text(
                        'What should you watch or read next?',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Body
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // Filter Section 1: Medium (Anime / Manga / Both)
                _buildSectionHeader('Medium', Icons.movie_filter_rounded, isDark),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        title: 'Anime',
                        icon: Icons.tv_rounded,
                        isSelected: _medium == MediumFilter.anime,
                        onTap: () => setState(() => _medium = MediumFilter.anime),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        title: 'Manga',
                        icon: Icons.menu_book_rounded,
                        isSelected: _medium == MediumFilter.manga,
                        onTap: () => setState(() => _medium = MediumFilter.manga),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        title: 'Both',
                        icon: Icons.shuffle_rounded,
                        isSelected: _medium == MediumFilter.all,
                        onTap: () => setState(() => _medium = MediumFilter.all),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filter Section 2: Source
                _buildSectionHeader('Source Pool', Icons.folder_special_rounded, isDark),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        title: 'Plan to Watch',
                        subtitle: 'Clear Backlog',
                        icon: Icons.bookmark_added_rounded,
                        isSelected: _source == SourceFilter.planToWatch,
                        onTap: () => setState(() => _source = SourceFilter.planToWatch),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        title: 'My List (All)',
                        subtitle: 'Your Library',
                        icon: Icons.view_list_rounded,
                        isSelected: _source == SourceFilter.myListAll,
                        onTap: () => setState(() => _source = SourceFilter.myListAll),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoiceChip(
                        title: 'Discover',
                        subtitle: 'Top & Data',
                        icon: Icons.explore_rounded,
                        isSelected: _source == SourceFilter.discover,
                        onTap: () => setState(() => _source = SourceFilter.discover),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filter Section 3: Genre chips with Show more
                _buildGenreSection(isDark),
                const SizedBox(height: 16),

                // Filter Section 4: Producer / Studio chips with Show more
                _buildProducerSection(isDark),
                const SizedBox(height: 16),

                // Filter Section 4: Rating threshold
                _buildSectionHeader('Minimum Score', Icons.star_rounded, isDark),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildScoreFilterChip('Any', 0.0, isDark),
                    const SizedBox(width: 8),
                    _buildScoreFilterChip('★ 7.0+', 7.0, isDark),
                    const SizedBox(width: 8),
                    _buildScoreFilterChip('★ 8.0+ (Top)', 8.0, isDark),
                  ],
                ),
                const SizedBox(height: 24),

                // The Big Roll Dice Button
                GestureDetector(
                  onTap: _rollDice,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RotationTransition(
                          turns: _spinAnimation,
                          child: const Icon(Icons.casino_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isSpinning
                              ? 'Rolling the Dice...'
                              : (_selectedCandidate == null ? 'Spin / Pick Random' : 'Reroll Another! 🎲'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Winner / Animated Result Card
                if (candidateToShow != null) ...[
                  _buildResultCard(candidateToShow, isDark),
                ] else ...[
                  _buildPlaceholderGuide(isDark),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreSection(bool isDark) {
    final allGenres = _getGenres();
    final topGenres = [
      'All',
      'Action',
      'Adventure',
      'Comedy',
      'Drama',
      'Fantasy',
      'Romance',
      'Sci-Fi',
      'Slice of Life',
      'Supernatural',
      'Mystery',
      'Sports',
      'Suspense',
      'Horror',
    ].where((g) => allGenres.contains(g)).toList();

    // Ensure selected genre is always visible when collapsed
    if (!topGenres.contains(_selectedGenre) && _selectedGenre != 'All') {
      topGenres.insert(1, _selectedGenre);
    }

    final remainingCount = allGenres.length - topGenres.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and Show more / less button
        Row(
          children: [
            Icon(Icons.tag_rounded, size: 16, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(
              AppText.get('genre_filter'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (_selectedGenre != 'All') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedGenre,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
            const Spacer(),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _genresExpanded = !_genresExpanded);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _genresExpanded
                          ? AppText.get('show_less')
                          : '${AppText.get('show_more')} (${allGenres.length})',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _genresExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (!_genresExpanded) ...[
          // Horizontal scrolling row with top genres + "+ More" chip at the end
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: topGenres.length + (remainingCount > 0 ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                if (idx == topGenres.length) {
                  // Show more chip
                  return ActionChip(
                    avatar: Icon(Icons.add_rounded, size: 15, color: AppColors.accent),
                    label: Text('${AppText.get('show_more')} ($remainingCount)'),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                    backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: AppColors.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _genresExpanded = true);
                    },
                  );
                }

                final genre = topGenres[idx];
                final isSelected = _selectedGenre == genre;
                return ChoiceChip(
                  label: Text(genre),
                  selected: isSelected,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedGenre = genre);
                  },
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    ),
                  ),
                );
              },
            ),
          ),
        ] else ...[
          // Expanded container with search filter and all genre chips
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard.withValues(alpha: 0.5) : AppColors.lightCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Search Bar
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _genreSearchController,
                    onChanged: (val) => setState(() => _genreSearchQuery = val.trim()),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: AppText.get('search_genres'),
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      suffixIcon: _genreSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 14),
                              onPressed: () {
                                _genreSearchController.clear();
                                setState(() => _genreSearchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Wrap of all genres matching search
                Builder(
                  builder: (context) {
                    final filtered = _genreSearchQuery.isEmpty
                        ? allGenres
                        : allGenres
                            .where((g) => g.toLowerCase().contains(_genreSearchQuery.toLowerCase()))
                            .toList();

                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'No genres found matching "$_genreSearchQuery"',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                            ),
                          ),
                        ),
                      );
                    }

                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: filtered.map((genre) {
                            final isSelected = _selectedGenre == genre;
                            return ChoiceChip(
                              label: Text(genre),
                              selected: isSelected,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedGenre = genre);
                              },
                              selectedColor: AppColors.accent,
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.transparent
                                      : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _genresExpanded = false);
                    },
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 16),
                    label: Text(AppText.get('show_less'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProducerSection(bool isDark) {
    final allProducers = _getProducers();
    final topProducers = [
      'All',
      'MAPPA',
      'ufotable',
      'Bones',
      'Madhouse',
      'Wit Studio',
      'Kyoto Animation',
      'A-1 Pictures',
      'CloverWorks',
      'Toei Animation',
      'Trigger',
      'Studio Ghibli',
      'Shaft',
      'J.C.Staff',
      'Production I.G',
    ].where((p) => allProducers.contains(p)).toList();

    // Ensure selected producer is visible when collapsed
    if (!topProducers.contains(_selectedProducer) && _selectedProducer != 'All') {
      topProducers.insert(1, _selectedProducer);
    }

    final remainingCount = allProducers.length - topProducers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and Show more / less button
        Row(
          children: [
            Icon(Icons.business_rounded, size: 16, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(
              AppText.get('studio_producer'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (_selectedProducer != 'All') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedProducer,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
            const Spacer(),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _producersExpanded = !_producersExpanded);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _producersExpanded
                          ? AppText.get('show_less')
                          : '${AppText.get('show_more')} (${allProducers.length})',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _producersExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (!_producersExpanded) ...[
          // Horizontal scrolling row with top producers + "+ More" chip at the end
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: topProducers.length + (remainingCount > 0 ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                if (idx == topProducers.length) {
                  // Show more chip
                  return ActionChip(
                    avatar: Icon(Icons.add_rounded, size: 15, color: AppColors.accent),
                    label: Text('${AppText.get('show_more')} ($remainingCount)'),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                    backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: AppColors.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _producersExpanded = true);
                    },
                  );
                }

                final producer = topProducers[idx];
                final isSelected = _selectedProducer == producer;
                return ChoiceChip(
                  label: Text(producer),
                  selected: isSelected,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedProducer = producer);
                  },
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    ),
                  ),
                );
              },
            ),
          ),
        ] else ...[
          // Expanded container with search filter and all producer chips
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard.withValues(alpha: 0.5) : AppColors.lightCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Search Bar
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _producerSearchController,
                    onChanged: (val) => setState(() => _producerSearchQuery = val.trim()),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: AppText.get('search_producers'),
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      suffixIcon: _producerSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 14),
                              onPressed: () {
                                _producerSearchController.clear();
                                setState(() => _producerSearchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Wrap of all producers matching search
                Builder(
                  builder: (context) {
                    final filtered = _producerSearchQuery.isEmpty
                        ? allProducers
                        : allProducers
                            .where((p) => p.toLowerCase().contains(_producerSearchQuery.toLowerCase()))
                            .toList();

                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'No studios found matching "$_producerSearchQuery"',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                            ),
                          ),
                        ),
                      );
                    }

                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: filtered.map((producer) {
                            final isSelected = _selectedProducer == producer;
                            return ChoiceChip(
                              label: Text(producer),
                              selected: isSelected,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedProducer = producer);
                              },
                              selectedColor: AppColors.accent,
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.transparent
                                      : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _producersExpanded = false);
                    },
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 16),
                    label: Text(AppText.get('show_less'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.15)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.accent : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.accent : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreFilterChip(String label, double minScore, bool isDark) {
    final isSelected = _minScore == minScore;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _minScore = minScore),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.starYellow.withValues(alpha: 0.2)
                : (isDark ? AppColors.darkCard : AppColors.lightCard),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.starYellow
                  : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.starYellow : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderGuide(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 48, color: AppColors.accent.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            'Ready to discover?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "Spin / Pick Random" above to randomly select your next binge-watch or read based on your filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(RandomCandidate candidate, bool isDark) {
    final existingInList = HiveService.getListItem(candidate.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: _isSpinning ? 0.3 : 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent.withValues(alpha: 0.25), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                Icon(
                  candidate.isManga ? Icons.menu_book_rounded : Icons.tv_rounded,
                  size: 15,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  candidate.sourceLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.accent,
                  ),
                ),
                const Spacer(),
                if (existingInList != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.completed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.completed.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 11, color: AppColors.completed),
                        const SizedBox(width: 4),
                        Text(
                          existingInList.category.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.completed,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 100,
                    height: 145,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: candidate.image,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                          ),
                        ),
                        if (candidate.score != null && candidate.score! > 0)
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
                                  const SizedBox(width: 2),
                                  Text(
                                    candidate.score!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
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
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      if (candidate.romajiTitle != null && candidate.romajiTitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          candidate.romajiTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // Format & Episodes pill
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              candidate.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              candidate.episodesOrChapters,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          if (candidate.year != null && candidate.year!.isNotEmpty && candidate.year != 'Unknown')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                candidate.year!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          if (candidate.studios.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                candidate.studios.first,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Genres
                      if (candidate.genres.isNotEmpty)
                        Text(
                          candidate.genres.take(3).join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Synopsis
          if (candidate.synopsis != null && candidate.synopsis!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => setState(() => _synopsisExpanded = !_synopsisExpanded),
                child: Text(
                  candidate.synopsis!,
                  maxLines: _synopsisExpanded ? 10 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () => _openDetails(candidate),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(candidate.isManga ? 'Read Details' : 'View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => _addToList(candidate),
                    icon: Icon(
                      existingInList != null ? Icons.edit_note_rounded : Icons.bookmark_add_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    label: Text(
                      existingInList != null ? 'Edit List' : 'Add to List',
                      style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
}
