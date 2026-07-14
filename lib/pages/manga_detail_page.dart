import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_model.dart';
import '../core/models/anime_list_item.dart';
import '../core/models/character_model.dart';
import '../core/services/jikan_service.dart';
import '../core/services/hive_service.dart';
import '../core/services/notification_service.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/error_state.dart';
import '../widgets/category_picker.dart';
import '../widgets/user_rating_sheet.dart';
import '../widgets/share_card_dialog.dart';

class MangaDetailPage extends StatefulWidget {
  final int mangaId;
  final VoidCallback onBack;

  const MangaDetailPage({super.key, required this.mangaId, required this.onBack});

  @override
  State<MangaDetailPage> createState() => _MangaDetailPageState();
}

class _MangaDetailPageState extends State<MangaDetailPage> {
  AnimeModel? _manga;
  List<CharacterModel> _characters = [];
  List<String> _pictures = [];
  Map<String, dynamic>? _statistics;
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _news = [];
  List<AnimeModel> _recommendations = [];

  bool _loading = true;
  String _activeTab = 'overview';
  bool _synopsisExpanded = false;
  bool _charsLoading = true;
  bool _picsLoading = true;
  bool _statsLoading = true;
  bool _reviewsLoading = true;
  bool _newsLoading = true;
  bool _recsLoading = true;
  String? _error;

  bool _witmangaChecked = false;
  bool _witmangaExists = false;

  Future<void> _checkWitmangaLink(AnimeModel manga) async {
    final titleForSlug = (manga.romajiTitle != null && manga.romajiTitle!.isNotEmpty)
        ? manga.romajiTitle!
        : manga.title;
    String cleanSlug = titleForSlug.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').trim();
    if (cleanSlug.endsWith('-')) cleanSlug = cleanSlug.substring(0, cleanSlug.length - 1);
    if (cleanSlug.startsWith('-')) cleanSlug = cleanSlug.substring(1);

    final url = 'https://${HiveService.witmangaDomain}/manga/$cleanSlug/';
    try {
      final response = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 4));
      bool exists = (response.statusCode != 404);
      if (!exists) {
        final getResponse = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
        exists = (getResponse.statusCode != 404);
      }
      if (mounted) {
        setState(() {
          _witmangaExists = exists;
          _witmangaChecked = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _witmangaExists = false;
          _witmangaChecked = true;
        });
      }
    }
  }

  Future<List<String>> _fetchGalleryPictures(String title) async {
    final results = <String>[];

    try {
      final jikanPics = await JikanService.getMangaPictures(widget.mangaId);
      results.addAll(jikanPics);
    } catch (_) {}

    final searchTitle = title
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]+'), ' ')
        .trim();

    try {
      final wallhavenUrl = 'https://wallhaven.cc/api/v1/search?q=${Uri.encodeComponent(searchTitle)}&categories=010';
      final response = await http.get(Uri.parse(wallhavenUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] is List) {
          for (final item in data['data']) {
            final path = item['path'] as String?;
            if (path != null && path.isNotEmpty) {
              results.add(path);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Wallhaven fetch error: $e');
    }

    try {
      final safebooruTag = searchTitle.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final safebooruUrl = 'https://safebooru.org/index.php?page=dapi&s=post&q=index&json=1&tags=${Uri.encodeComponent(safebooruTag)}&limit=25';
      final response = await http.get(Uri.parse(safebooruUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          for (final item in data) {
            var fileUrl = item['file_url'] as String?;
            if (fileUrl != null && fileUrl.isNotEmpty) {
              if (fileUrl.startsWith('//')) {
                fileUrl = 'https:$fileUrl';
              }
              results.add(fileUrl);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Safebooru fetch error: $e');
    }

    return results.toSet().toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cached = HiveService.getCachedMangaDetail(widget.mangaId);
      if (cached != null) {
        final manga = AnimeModel.fromJson(cached);
        _updateListItemMetadata(manga);
        if (mounted) setState(() { _manga = manga; _loading = false; });
        _loadExtraDetails();
        _checkWitmangaLink(manga);
        
        if (manga.romajiTitle == null || manga.romajiTitle!.isEmpty) {
          _updateCacheFromApi();
        }
        return;
      }

      final mangaObj = await JikanService.getMangaById(widget.mangaId);
      await HiveService.cacheMangaDetail(widget.mangaId, _mangaToJson(mangaObj));
      _updateListItemMetadata(mangaObj);

      if (mounted) {
        setState(() {
          _manga = mangaObj;
          _loading = false;
        });
      }
      _loadExtraDetails();
      _checkWitmangaLink(mangaObj);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _updateCacheFromApi() async {
    try {
      final mangaObj = await JikanService.getMangaById(widget.mangaId);
      await HiveService.cacheMangaDetail(widget.mangaId, _mangaToJson(mangaObj));
      _updateListItemMetadata(mangaObj);
      if (mounted) {
        setState(() {
          _manga = mangaObj;
        });
      }
    } catch (e) {
      debugPrint("Error updating cached manga in background: $e");
    }
  }

  void _updateListItemMetadata(AnimeModel anime) {
    final item = HiveService.getListItem(anime.id);
    if (item != null) {
      if (item.type == null || item.studios == null || item.year == null) {
        final updated = AnimeListItem(
          animeId: item.animeId,
          title: item.title,
          image: item.image,
          score: item.score,
          genres: item.genres,
          category: item.category,
          addedAt: item.addedAt,
          userRating: item.userRating,
          episodes: item.episodes,
          episodeProgress: item.episodeProgress,
          type: anime.type,
          studios: anime.studios,
          year: anime.year,
          rank: anime.rank,
          popularity: anime.popularity,
          season: anime.season,
        );
        HiveService.addToList(updated);
      }
    }
  }

  Map<String, dynamic> _mangaToJson(AnimeModel m) {
    return {
      'mal_id': m.id,
      'title': m.romajiTitle ?? m.title,
      'title_english': m.title,
      'title_japanese': m.japaneseTitle,
      'images': {'jpg': {'large_image_url': m.image}},
      'score': m.score,
      'synopsis': m.synopsis,
      'genres': m.genres.map((g) => {'name': g}).toList(),
      'status': m.status,
      'rating': m.rating,
      'type': m.type,
      'source': m.source,
      'duration': m.duration,
      'episodes': m.episodes,
      'year': m.year,
      'members': m.members,
      'rank': m.rank,
      'popularity': m.popularity,
      'aired': {'from': m.airedFrom, 'to': m.airedTo},
    };
  }

  void _loadExtraDetails() {
    final manga = _manga;
    if (manga == null) return;

    _fetchGalleryPictures(manga.title).then((pics) {
      if (mounted) setState(() { _pictures = pics; _picsLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _picsLoading = false; });
    });

    JikanService.getMangaStatistics(widget.mangaId).then((stats) {
      if (mounted) setState(() { _statistics = stats; _statsLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _statsLoading = false; });
    });

    JikanService.getMangaReviews(widget.mangaId).then((rev) {
      if (mounted) setState(() { _reviews = rev; _reviewsLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _reviewsLoading = false; });
    });

    JikanService.getMangaNews(widget.mangaId).then((news) {
      if (mounted) setState(() { _news = news; _newsLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _newsLoading = false; });
    });

    JikanService.getMangaRecommendations(widget.mangaId).then((recs) {
      if (mounted) setState(() { _recommendations = recs; _recsLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _recsLoading = false; });
    });

    if (_characters.isEmpty) {
      JikanService.getMangaCharacters(widget.mangaId, limit: 10).then((chars) {
        if (mounted) setState(() { _characters = chars; _charsLoading = false; });
      }).catchError((_) {
        if (mounted) setState(() { _charsLoading = false; });
      });
    } else {
      if (mounted) setState(() { _charsLoading = false; });
    }
  }

  Future<void> _shareImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final temp = await getTemporaryDirectory();
      final name = 'manga_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${temp.path}/$name');
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Check out this picture from ${_manga?.title ?? 'this Manga'}!');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final temp = await getTemporaryDirectory();
      final name = 'manga_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${temp.path}/$name');
      await file.writeAsBytes(response.bodyBytes);
      await Gal.putImage(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved to gallery!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleAddToList() async {
    if (_manga == null) return;
    final existing = HiveService.getListItem(_manga!.id);
    final result = await CategoryPickerSheet.show(context, current: existing?.category);
    if (result == null || !mounted) return;
    switch (result) {
      case CategorySelected(:final category):
        if (existing != null) {
          await HiveService.updateCategory(_manga!.id, category);
        } else {
          await HiveService.addToList(AnimeListItem.fromAnime(_manga!, category));
        }
      case DeleteFromList():
        await HiveService.removeFromList(_manga!.id);
    }
    setState(() {});
  }

  Future<void> _handleRate() async {
    if (_manga == null) return;
    final existing = HiveService.getListItem(_manga!.id);
    final rating = await UserRatingSheet.show(context, existing: existing?.userRating);
    if (rating != null && mounted) {
      if (existing != null) {
        await HiveService.updateUserRating(_manga!.id, rating);
      } else {
        await HiveService.addToList(AnimeListItem.fromAnime(_manga!, AnimeCategory.planned));
        await HiveService.updateUserRating(_manga!.id, rating);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) { if (!didPop) widget.onBack(); },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _buildBackButton(),
                Expanded(child: ShimmerLoading.detailPage(context: context)),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) { if (!didPop) widget.onBack(); },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _buildBackButton(),
                Expanded(child: ErrorStateWidget(message: _error, onRetry: _fetchDetails)),
              ],
            ),
          ),
        ),
      );
    }

    if (_manga == null) return const SizedBox.shrink();

    final manga = _manga!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listItem = HiveService.getListItem(manga.id);
    final inList = listItem != null;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 850;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) widget.onBack(); },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F5FA),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCoverBanner(manga, inList, isDark, listItem, isDesktop),
                  
                  if (listItem?.userRating != null && listItem!.userRating!.hasRating) ...[
                    _buildUserRatingCard(listItem.userRating!),
                    const SizedBox(height: 24),
                  ],

                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 320,
                          child: _buildSidebar(manga, isDark),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTabSelector(isDark),
                              const SizedBox(height: 20),
                              _buildActiveTabContent(manga, isDark, false),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTabSelector(isDark),
                        const SizedBox(height: 20),
                        _buildActiveTabContent(manga, isDark, true),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverBanner(AnimeModel manga, bool inList, bool isDark, AnimeListItem? listItem, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: manga.image,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: (isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F5FA)).withOpacity(0.7),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          (isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F5FA)).withOpacity(0.9),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
              vertical: isDesktop ? 32 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                      onPressed: widget.onBack,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          HiveService.hasAlertEnabled(manga.id)
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          color: HiveService.hasAlertEnabled(manga.id)
                              ? AppColors.starYellow
                              : Colors.white,
                          size: 20,
                        ),
                      ),
                      onPressed: () async {
                        final hasAlert = HiveService.hasAlertEnabled(manga.id);
                        final newStatus = !hasAlert;
                        await HiveService.setAlertEnabled(manga.id, newStatus);
                        if (newStatus) {
                          await NotificationService.subscribeToManga(manga.id);
                        } else {
                          await NotificationService.unsubscribeFromManga(manga.id);
                        }
                        setState(() {});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(newStatus ? 'Manga updates alerts enabled!' : 'Manga updates alerts disabled!'),
                              backgroundColor: newStatus ? Colors.green : Colors.black87,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share, color: Colors.white, size: 20),
                      ),
                      onPressed: () => ShareCardDialog.show(context, manga),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: isDesktop ? 180 : 120,
                      height: isDesktop ? 260 : 175,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl: manga.image,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _badge('Manga', AppColors.mauve),
                              _badge(manga.status, AppColors.accent),
                              if (manga.year != 'Unknown' && manga.year.isNotEmpty)
                                _badge(
                                  manga.year,
                                  isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                  textColor: isDark ? Colors.white70 : Colors.black87,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            manga.title,
                            style: TextStyle(
                              fontSize: isDesktop ? 28 : 20,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (manga.japaneseTitle.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              manga.japaneseTitle,
                              style: TextStyle(
                                fontSize: isDesktop ? 16 : 14,
                                color: (isDark ? Colors.white : Colors.black87).withOpacity(0.6),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.starYellow.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.starYellow.withAlpha(60)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 16, color: AppColors.starYellow),
                                    const SizedBox(width: 4),
                                    Text(
                                      manga.scoreDisplay,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.starYellow,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _handleAddToList,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: inList
                                        ? AppColors.success.withAlpha(30)
                                        : AppColors.mauve,
                                    foregroundColor: inList ? AppColors.success : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: inList ? BorderSide(color: AppColors.success.withAlpha(60)) : null,
                                    elevation: 0,
                                  ),
                                  icon: Icon(inList ? Icons.check : Icons.bookmark_add_outlined, size: 20),
                                  label: Text(
                                    inList ? 'Added to List' : 'Add to List',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black.withOpacity(0.3) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.star_outline),
                                  onPressed: _handleRate,
                                  tooltip: 'Rate Manga',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
    );
  }

  Widget _buildTabSelector(bool isDark) {
    final tabs = ['overview', 'metrics', 'cast', 'recs', 'reviews'];
    final titles = {
      'overview': 'Overview',
      'metrics': 'Metrics & Stats',
      'cast': 'Characters',
      'recs': 'Recommendations',
      'reviews': 'Reviews',
    };

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = _activeTab == tab;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.mauve : (isDark ? AppColors.darkCard : AppColors.lightCard),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.mauve : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
              ),
              child: Center(
                child: Text(
                  titles[tab]!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveTabContent(AnimeModel manga, bool isDark, bool isMobile) {
    Widget content;
    switch (_activeTab) {
      case 'overview':
        content = _buildOverviewTab(manga, isDark);
        break;
      case 'metrics':
        content = _buildStatsTab(manga, isDark);
        break;
      case 'cast':
        content = _buildCastTab(isDark);
        break;
      case 'recs':
        content = _buildRecsTab(isDark);
        break;
      case 'reviews':
        content = _buildReviewsTab(isDark);
        break;
      default:
        content = const SizedBox.shrink();
        break;
    }

    if (isMobile) {
      if (_activeTab == 'overview') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            const SizedBox(height: 24),
            _buildSidebar(manga, isDark),
          ],
        );
      }
    }

    return content;
  }

  Widget _buildOverviewTab(AnimeModel manga, bool isDark) {
    final titleForSlug = (manga.romajiTitle != null && manga.romajiTitle!.isNotEmpty)
        ? manga.romajiTitle!
        : manga.title;
    String cleanSlug = titleForSlug.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').trim();
    if (cleanSlug.endsWith('-')) cleanSlug = cleanSlug.substring(0, cleanSlug.length - 1);
    if (cleanSlug.startsWith('-')) cleanSlug = cleanSlug.substring(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.mauve,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Synopsis',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final text = manga.synopsis;
                  final canExpand = text.length > 280;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        maxLines: _synopsisExpanded ? null : 5,
                        overflow: _synopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      if (canExpand) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(() => _synopsisExpanded = !_synopsisExpanded),
                          child: Text(
                            _synopsisExpanded ? 'Show Less' : 'Read More',
                            style: const TextStyle(
                              color: AppColors.mauve,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ]
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),

        if (_witmangaExists) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton.icon(
              onPressed: () async {
                final url = 'https://${HiveService.witmangaDomain}/manga/$cleanSlug/';
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch WitManga')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mauve,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              icon: const Icon(Icons.chrome_reader_mode_outlined),
              label: const Text('Read on WitManga', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],

        if (_charsLoading || _characters.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
            ),
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.mauve,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Characters',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 155,
                  child: _charsLoading
                      ? ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 4,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) => ShimmerLoading.card(context: context),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _characters.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final char = _characters[index];
                            return SizedBox(
                              width: 90,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: char.image,
                                      width: 90,
                                      height: 110,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    char.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  Text(
                                    char.role,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],

        if (_picsLoading || _pictures.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.mauve,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Gallery Pictures',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: _picsLoading
                      ? ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) => ShimmerLoading.card(context: context),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _pictures.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final url = _pictures[index];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    width: 130,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Column(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _saveImage(url),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () => _shareImage(url),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsTab(AnimeModel manga, bool isDark) {
    if (_statsLoading) {
      return Center(child: ShimmerLoading.card(context: context));
    }
    if (_statistics == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
        ),
        child: const Center(child: Text('No statistics available.', style: TextStyle(color: Colors.grey))),
      );
    }

    final total = (_statistics!['reading'] ?? 0) +
        (_statistics!['completed'] ?? 0) +
        (_statistics!['on_hold'] ?? 0) +
        (_statistics!['dropped'] ?? 0) +
        (_statistics!['plan_to_read'] ?? 0);
    final totalVal = total > 0 ? total : 1;

    final stats = [
      {
        'label': 'Completed',
        'value': _statistics!['completed'] ?? 0,
        'color': AppColors.success,
      },
      {
        'label': 'Reading',
        'value': _statistics!['reading'] ?? 0,
        'color': AppColors.watching,
      },
      {
        'label': 'Plan to Read',
        'value': _statistics!['plan_to_read'] ?? 0,
        'color': AppColors.planned,
      },
      {
        'label': 'On Hold',
        'value': _statistics!['on_hold'] ?? 0,
        'color': AppColors.warning,
      },
      {
        'label': 'Dropped',
        'value': _statistics!['dropped'] ?? 0,
        'color': AppColors.error,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.mauve,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Community List Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              final totalCircle = Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 8,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.withOpacity(0.1)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatNumber(total),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final statsList = Column(
                children: stats.map((stat) {
                  final val = stat['value'] as int;
                  final color = stat['color'] as Color;
                  final ratio = val / totalVal;
                  final percent = (ratio * 100).toStringAsFixed(1);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  stat['label'] as String,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Text(
                              '${_formatNumber(val)} ($percent%)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            backgroundColor: Colors.grey.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 4, child: totalCircle),
                    const SizedBox(width: 24),
                    Expanded(flex: 6, child: statsList),
                  ],
                );
              } else {
                return Column(
                  children: [
                    totalCircle,
                    const SizedBox(height: 24),
                    statsList,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCastTab(bool isDark) {
    if (_charsLoading) {
      return Center(child: ShimmerLoading.card(context: context));
    }
    if (_characters.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
        ),
        child: const Center(child: Text('No character information available.', style: TextStyle(color: Colors.grey))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.mauve,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Characters List',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _characters.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, index) {
              final char = _characters[index];
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CachedNetworkImage(
                        imageUrl: char.image,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            char.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            char.role,
                            style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecsTab(bool isDark) {
    if (_recsLoading) {
      return Center(child: ShimmerLoading.card(context: context));
    }
    if (_recommendations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
        ),
        child: const Center(child: Text('No recommendations found.', style: TextStyle(color: Colors.grey))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.mauve,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Recommended Manga',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recommendations.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.62,
            ),
            itemBuilder: (context, index) {
              final rec = _recommendations[index];
              return GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MangaDetailPage(
                        mangaId: rec.id,
                        onBack: widget.onBack,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.02),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CachedNetworkImage(
                        imageUrl: rec.image,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            rec.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab(bool isDark) {
    if (_reviewsLoading) {
      return Center(child: ShimmerLoading.card(context: context));
    }
    if (_reviews.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
        ),
        child: const Center(child: Text('No reviews written yet.', style: TextStyle(color: Colors.grey))),
      );
    }

    return Column(
      children: _reviews.map((review) {
        final user = review['user'] ?? {};
        final score = review['score'] ?? 0;
        final content = review['review'] ?? '';
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          ),
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 16),
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
                    backgroundColor: AppColors.mauve.withAlpha(50),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user['username'] ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.starYellow.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 12, color: AppColors.starYellow),
                        const SizedBox(width: 2),
                        Text(
                          '$score',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.starYellow),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSidebar(AnimeModel manga, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.mauve,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('Genres', manga.genres.isEmpty ? 'None' : manga.genres.join(', ')),
          _divider(),
          _infoRow('Type', manga.type),
          _divider(),
          _infoRow('Chapters', manga.episodes),
          _divider(),
          _infoRow('Status', manga.status),
          _divider(),
          _infoRow('Published', manga.year),
          if (manga.rank != null) ...[
            _divider(),
            _infoRow('Rank', '#${manga.rank}'),
          ],
          if (manga.popularity != null) ...[
            _divider(),
            _infoRow('Popularity', '#${manga.popularity}'),
          ],
          if (manga.members != null) ...[
            _divider(),
            _infoRow('Members', _formatNumber(manga.members!)),
          ],
          _divider(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                final malUrl = 'https://myanimelist.net/manga/${manga.id}';
                final uri = Uri.parse(malUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new, size: 14, color: AppColors.mauve),
              label: const Text('View on MyAnimeList', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.mauve)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, {Color? textColor, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor ?? Colors.white),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, thickness: 0.5);
  }

  Widget _buildUserRatingCard(UserRating rating) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.mauve.withAlpha(15), AppColors.lavender.withAlpha(15)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mauve.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Your Rating',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.mauve, fontSize: 14)),
              TextButton.icon(
                onPressed: () async {
                  final r = await UserRatingSheet.show(context, existing: rating);
                  if (r != null && mounted) {
                    await HiveService.updateUserRating(_manga!.id, r);
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.mauve),
                label: const Text('Edit', style: TextStyle(fontSize: 12, color: AppColors.mauve)),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ratingPill('Overall', rating.overall, AppColors.mauve, large: true),
              _ratingPill('Story', rating.story, AppColors.lavender),
              _ratingPill('Art', rating.draw, AppColors.accent),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ratingPill('Characters', rating.character, AppColors.mauve),
              _ratingPill('Music', rating.music, AppColors.starYellow),
              _ratingPill('Overall vibe', rating.animation, const Color(0xFF60C8A0)),
            ],
          ),
          if (rating.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(rating.notes,
                style: TextStyle(fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontStyle: FontStyle.italic),
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  Widget _ratingPill(String label, double value, Color color, {bool large = false}) {
    return Column(
      children: [
        Text(
          value > 0 ? value.toStringAsFixed(1) : '-',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: large ? 20 : 15, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: color.withAlpha(180)),
            textAlign: TextAlign.center),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
