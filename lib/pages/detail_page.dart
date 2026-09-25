import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_model.dart';
import '../core/models/anime_list_item.dart';
import '../core/models/character_model.dart';
import '../core/services/jikan_service.dart';
import '../core/services/hive_service.dart';
import '../core/services/notification_service.dart';
import '../core/localization/app_text.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/error_state.dart';
import '../widgets/category_picker.dart';
import '../widgets/user_rating_sheet.dart';
import '../widgets/share_card_dialog.dart';
import '../pages/wet_anime_page.dart';

class DetailPage extends StatefulWidget {
  final int animeId;
  final VoidCallback onBack;

  const DetailPage({super.key, required this.animeId, required this.onBack});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  AnimeModel? _anime;
  List<CharacterModel> _characters = [];
  List<String> _pictures = [];
  Map<String, dynamic>? _statistics;
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _news = [];
  List<AnimeModel> _recommendations = [];
  bool _recsLoading = true;

  bool _loading = true;
  String _activeTab = 'overview';
  bool _synopsisExpanded = false;
  bool _charsLoading = true;
  bool _picsLoading = true;
  bool _statsLoading = true;
  bool _reviewsLoading = true;
  bool _newsLoading = true;
  String? _error;

  bool _witanimeChecked = false;
  bool _witanimeExists = false;
  int _witanimePublishedCount = 0;
  Set<int> _publishedEpisodes = {};
  String? _witanimeFoundUrl;
  String? _witanimeFoundSlug;

  String _slugify(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    String s = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').trim();
    while (s.startsWith('-')) s = s.substring(1);
    while (s.endsWith('-')) s = s.substring(0, s.length - 1);
    return s;
  }

  String _computeCleanSlug(AnimeModel anime) {
    if (_witanimeFoundSlug != null && _witanimeFoundSlug!.isNotEmpty) {
      return _witanimeFoundSlug!;
    }
    final titleForSlug = (anime.romajiTitle != null && anime.romajiTitle!.isNotEmpty)
        ? anime.romajiTitle!
        : anime.title;
    return _slugify(titleForSlug);
  }

  Future<void> _checkWitanimeLink(AnimeModel anime) async {
    final candidateSlugs = <String>[];
    void addSlug(String? s) {
      final slug = _slugify(s);
      if (slug.isNotEmpty && !candidateSlugs.contains(slug)) {
        candidateSlugs.add(slug);
      }
    }

    // 1. Romaji title (preferred on WitAnime, e.g. "tefuda-ga-oome-no-victoria")
    addSlug(anime.romajiTitle);
    // 2. English / Main title (e.g. "victoria-of-many-faces")
    addSlug(anime.title);
    
    // 3. Stripped version (removing season/part markers)
    if (anime.romajiTitle != null) {
      final stripped = anime.romajiTitle!
          .replaceAll(RegExp(r'(?:season|part|2nd|3rd|4th|\bii\b|\biii\b|\biv\b).*', caseSensitive: false), '')
          .trim();
      addSlug(stripped);
    }
    if (anime.title.isNotEmpty) {
      final stripped = anime.title
          .replaceAll(RegExp(r'(?:season|part|2nd|3rd|4th|\bii\b|\biii\b|\biv\b).*', caseSensitive: false), '')
          .trim();
      addSlug(stripped);
    }

    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8',
    };

    final domainCandidates = [
      HiveService.witanimeDomain,
      'witanime.site',
      'witanime.net',
      'witanime.com',
    ].toSet().toList();

    for (final domain in domainCandidates) {
      for (final slug in candidateSlugs) {
        final url = 'https://$domain/anime/$slug/';
        try {
          final res = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final body = res.body;
            final is404 = (res.statusCode == 404) ||
                body.contains('<title>404') ||
                body.contains('الخطأ 404') ||
                body.contains('الصفحة المطلوبة غير موجودة') ||
                body.contains('Sorry, page not found');
            if (!is404) {
              if (domain != HiveService.witanimeDomain) {
                await HiveService.setWitanimeDomain(domain);
              }

              int maxEp = 0;
              final Set<int> published = {};
              final matches = RegExp(r'episode/[^"]*?(?:-|%20|_)(\d+)/?').allMatches(body);
              for (final m in matches) {
                final n = int.tryParse(m.group(1) ?? '');
                if (n != null && n > 0 && n < 2000) {
                  published.add(n);
                  if (n > maxEp) maxEp = n;
                }
              }
              final arMatches = RegExp(r'الحلقة\s*(\d+)').allMatches(body);
              for (final m in arMatches) {
                final n = int.tryParse(m.group(1) ?? '');
                if (n != null && n > 0 && n < 2000) {
                  published.add(n);
                  if (n > maxEp) maxEp = n;
                }
              }

              if (mounted) {
                setState(() {
                  _witanimeExists = true;
                  _witanimeChecked = true;
                  _witanimeFoundUrl = url;
                  _witanimeFoundSlug = slug;
                  _witanimePublishedCount = maxEp > 0 ? maxEp : 1;
                  _publishedEpisodes = published.isNotEmpty ? published : {1};
                });
              }
              return;
            }
          }
        } catch (_) {}
      }
    }

    // Fallback: search on WitAnime
    for (final domain in domainCandidates) {
      final queryTitle = (anime.romajiTitle != null && anime.romajiTitle!.isNotEmpty)
          ? anime.romajiTitle!
          : anime.title;
      final searchUrl = 'https://$domain/?s=${Uri.encodeComponent(queryTitle)}';
      try {
        final res = await http.get(Uri.parse(searchUrl), headers: headers).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final body = res.body;
          final match = RegExp(r'href="https?://[^/]+/anime/([a-zA-Z0-9-]+)/?"').firstMatch(body);
          if (match != null) {
            final foundSlug = match.group(1);
            if (foundSlug != null && foundSlug.isNotEmpty) {
              final targetUrl = 'https://$domain/anime/$foundSlug/';
              if (domain != HiveService.witanimeDomain) {
                await HiveService.setWitanimeDomain(domain);
              }
              if (mounted) {
                setState(() {
                  _witanimeExists = true;
                  _witanimeChecked = true;
                  _witanimeFoundUrl = targetUrl;
                  _witanimeFoundSlug = foundSlug;
                  _witanimePublishedCount = 1;
                  _publishedEpisodes = {1};
                });
              }
              return;
            }
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _witanimeExists = false;
        _witanimeChecked = true;
        _witanimePublishedCount = 0;
        _publishedEpisodes = {};
      });
    }
  }

  Future<List<String>> _fetchGalleryPictures(String title) async {
    final results = <String>[];

    try {
      final jikanPics = await JikanService.getAnimePictures(widget.animeId);
      results.addAll(jikanPics);
    } catch (_) {}

    final searchTitle = title
        .replaceAll(RegExp(r'\(TV\)', caseSensitive: false), '')
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
      final cached = HiveService.getCachedAnimeDetail(widget.animeId);
      if (cached != null) {
        final anime = AnimeModel.fromJson(cached);
        _updateListItemMetadata(anime);
        if (mounted) setState(() { _anime = anime; _loading = false; });
        _loadExtraDetails();
        _checkWitanimeLink(anime);
        
        if (anime.romajiTitle == null || anime.romajiTitle!.isEmpty) {
          _updateCacheFromApi();
        }
        return;
      }

      final animeObj = await JikanService.getAnimeById(widget.animeId);
      await HiveService.cacheAnimeDetail(widget.animeId, _animeToJson(animeObj));
      _updateListItemMetadata(animeObj);

      if (mounted) {
        setState(() {
          _anime = animeObj;
          _loading = false;
        });
        _checkWitanimeLink(animeObj);
      }
      _loadExtraDetails();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _updateCacheFromApi() async {
    try {
      final animeObj = await JikanService.getAnimeById(widget.animeId);
      await HiveService.cacheAnimeDetail(widget.animeId, _animeToJson(animeObj));
      _updateListItemMetadata(animeObj);
      if (mounted) {
        setState(() {
          _anime = animeObj;
        });
        _checkWitanimeLink(animeObj);
      }
    } catch (e) {
      debugPrint("Error updating cached anime in background: $e");
    }
  }

  void _updateListItemMetadata(AnimeModel anime) {
    final item = HiveService.getListItem(anime.id);
    if (item != null) {
      final shouldUpdateEpisodes = (item.episodes == '?' || item.episodes.isEmpty || item.episodes == '0') &&
          anime.episodes != '?' &&
          anime.episodes != '0' &&
          anime.episodes.isNotEmpty;

      if (item.type == null || item.studios == null || item.year == null || shouldUpdateEpisodes) {
        final updated = AnimeListItem(
          animeId: item.animeId,
          title: item.title,
          image: item.image,
          score: item.score,
          genres: item.genres,
          category: item.category,
          addedAt: item.addedAt,
          userRating: item.userRating,
          episodes: shouldUpdateEpisodes ? anime.episodes : item.episodes,
          episodeProgress: item.episodeProgress,
          type: item.type ?? anime.type,
          studios: item.studios ?? anime.studios,
          year: item.year ?? anime.year,
          rank: item.rank ?? anime.rank,
          popularity: item.popularity ?? anime.popularity,
          season: item.season ?? anime.season,
          isMalSynced: item.isMalSynced,
          personalNotes: item.personalNotes,
          tags: item.tags,
        );
        HiveService.addToList(updated);
      }
    }
  }

  Map<String, dynamic> _animeToJson(AnimeModel a) {
    return {
      'mal_id': a.id,
      'title': a.romajiTitle ?? a.title,
      'title_english': a.title,
      'title_japanese': a.japaneseTitle,
      'images': {'jpg': {'large_image_url': a.image}},
      'score': a.score,
      'synopsis': a.synopsis,
      'genres': a.genres.map((g) => {'name': g}).toList(),
      'status': a.status,
      'rating': a.rating,
      'trailer': a.trailerId != null ? {'youtube_id': a.trailerId} : null,
      'studios': a.studios.map((s) => {'name': s}).toList(),
      'type': a.type,
      'source': a.source,
      'duration': a.duration,
      'episodes': a.episodes,
      'year': a.year,
      'members': a.members,
      'rank': a.rank,
      'popularity': a.popularity,
      'aired': {'from': a.airedFrom, 'to': a.airedTo},
      'broadcast': {'day': a.broadcastDay, 'time': a.broadcastTime},
    };
  }

  Future<void> _handleAddToList() async {
    if (_anime == null) return;
    final existing = HiveService.getListItem(_anime!.id);
    final result = await CategoryPickerSheet.show(context, current: existing?.category);
    if (result == null || !mounted) return;
    switch (result) {
      case CategorySelected(:final category):
        if (existing != null) {
          await HiveService.updateCategory(_anime!.id, category);
        } else {
          await HiveService.addToList(AnimeListItem.fromAnime(_anime!, category));
        }
      case DeleteFromList():
        await HiveService.removeFromList(_anime!.id);
    }
    setState(() {});
  }

  void _loadExtraDetails() {
    // 1. Characters
    final cachedChars = HiveService.getCachedAnimeExtraDetails(widget.animeId, 'characters');
    if (cachedChars is List && cachedChars.isNotEmpty) {
      _characters = cachedChars.map((e) => CharacterModel.fromJson(e as Map<String, dynamic>)).toList();
      _charsLoading = false;
    }
    JikanService.getAnimeCharacters(widget.animeId, limit: 10).then((chars) {
      if (chars.isNotEmpty) {
        HiveService.cacheAnimeExtraDetails(widget.animeId, 'characters', chars.map((c) => c.toJson()).toList());
      }
      if (mounted) setState(() { _characters = chars.isNotEmpty ? chars : _characters; _charsLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _charsLoading = false; });
    });

    // 2. Pictures
    _fetchGalleryPictures(_anime!.title).then((pics) {
      if (mounted) setState(() { _pictures = pics; _picsLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _picsLoading = false; });
    });

    // 3. Statistics
    final cachedStats = HiveService.getCachedAnimeExtraDetails(widget.animeId, 'statistics');
    if (cachedStats is Map) {
      _statistics = Map<String, dynamic>.from(cachedStats);
      _statsLoading = false;
    }
    JikanService.getAnimeStatistics(widget.animeId).then((stats) {
      if (stats != null) {
        HiveService.cacheAnimeExtraDetails(widget.animeId, 'statistics', stats);
      }
      if (mounted) setState(() { _statistics = stats ?? _statistics; _statsLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _statsLoading = false; });
    });

    // 4. Reviews
    final cachedReviews = HiveService.getCachedAnimeExtraDetails(widget.animeId, 'reviews');
    if (cachedReviews is List && cachedReviews.isNotEmpty) {
      _reviews = cachedReviews.cast<Map<String, dynamic>>();
      _reviewsLoading = false;
    }
    JikanService.getAnimeReviews(widget.animeId).then((rev) {
      if (rev.isNotEmpty) {
        HiveService.cacheAnimeExtraDetails(widget.animeId, 'reviews', rev);
      }
      if (mounted) setState(() { _reviews = rev.isNotEmpty ? rev : _reviews; _reviewsLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _reviewsLoading = false; });
    });

    // 5. News
    final cachedNews = HiveService.getCachedAnimeExtraDetails(widget.animeId, 'news');
    if (cachedNews is List && cachedNews.isNotEmpty) {
      _news = cachedNews.cast<Map<String, dynamic>>();
      _newsLoading = false;
    }
    JikanService.getAnimeNews(widget.animeId).then((news) {
      if (news.isNotEmpty) {
        HiveService.cacheAnimeExtraDetails(widget.animeId, 'news', news);
      }
      if (mounted) setState(() { _news = news.isNotEmpty ? news : _news; _newsLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _newsLoading = false; });
    });

    // 6. Recommendations
    final cachedRecs = HiveService.getCachedAnimeExtraDetails(widget.animeId, 'recommendations');
    if (cachedRecs is List && cachedRecs.isNotEmpty) {
      _recommendations = (cachedRecs as List).map((m) => AnimeModel.fromJson(m as Map<String, dynamic>)).toList();
      _recsLoading = false;
    }
    JikanService.getAnimeRecommendations(widget.animeId).then((recs) {
      if (recs.isNotEmpty) {
        HiveService.cacheAnimeExtraDetails(widget.animeId, 'recommendations', recs.map((a) => _animeToJson(a)).toList());
      }
      if (mounted) setState(() { _recommendations = recs.isNotEmpty ? recs : _recommendations; _recsLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() { _recsLoading = false; });
    });
  }

  Future<void> _handleRate() async {
    if (_anime == null) return;
    final existing = HiveService.getListItem(_anime!.id);
    final rating = await UserRatingSheet.show(context, existing: existing?.userRating);
    if (rating != null && mounted) {
      if (existing != null) {
        await HiveService.updateUserRating(_anime!.id, rating);
      } else {
        final newItem = AnimeListItem.fromAnime(_anime!, AnimeCategory.planned);
        newItem.userRating = rating;
        await HiveService.addToList(newItem);
        await HiveService.updateUserRating(_anime!.id, rating);
      }
      setState(() {});
    }
  }

  Future<void> _launchTrailer() async {
    if (_anime?.trailerId == null) return;
    final url = Uri.parse('https://www.youtube.com/watch?v=${_anime!.trailerId}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      final temp = await getTemporaryDirectory();
      final name = 'anime_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${temp.path}/$name');
      await file.writeAsBytes(response.bodyBytes);
      
      await Share.shareXFiles([XFile(file.path)], text: 'Check out this anime picture!');
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
      final name = 'anime_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (Platform.isWindows) {
        final outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Image',
          fileName: name,
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        );
        if (outputFile == null) return;
        await File(outputFile).writeAsBytes(response.bodyBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Image saved successfully!'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Open Folder',
                textColor: Colors.white,
                onPressed: () {
                  final dir = File(outputFile).parent.path;
                  Process.run('explorer.exe', [dir]);
                },
              ),
            ),
          );
        }
        return;
      }

      final temp = await getTemporaryDirectory();
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

    if (_anime == null) return const SizedBox.shrink();

    final anime = _anime!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listItem = HiveService.getListItem(anime.id);
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
                  _buildCoverBanner(anime, inList, isDark, listItem, isDesktop),
                  
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
                          child: _buildSidebar(anime, isDark),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTabSelector(isDark),
                              const SizedBox(height: 20),
                              _buildActiveTabContent(anime, isDark, false),
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
                        _buildActiveTabContent(anime, isDark, true),
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

  Widget _buildCoverBanner(AnimeModel anime, bool inList, bool isDark, AnimeListItem? listItem, bool isDesktop) {
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
                  child: anime.image.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: anime.image,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        )
                      : const SizedBox.shrink(),
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
                          HiveService.hasAlertEnabled(anime.id)
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          color: HiveService.hasAlertEnabled(anime.id)
                              ? AppColors.starYellow
                              : Colors.white,
                          size: 20,
                        ),
                      ),
                      onPressed: () async {
                        final hasAlert = HiveService.hasAlertEnabled(anime.id);
                        final newStatus = !hasAlert;
                        await HiveService.setAlertEnabled(anime.id, newStatus);
                        if (newStatus) {
                          await NotificationService.subscribeToAnime(anime.id);
                        } else {
                          await NotificationService.unsubscribeFromAnime(anime.id);
                        }
                        setState(() {});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(newStatus ? 'Airing alerts enabled!' : 'Airing alerts disabled!'),
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
                      onPressed: () => ShareCardDialog.show(context, anime),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildPosterCard(anime),
                          const SizedBox(width: 32),
                          Expanded(child: _buildBannerDetails(anime, inList, isDark, listItem, true)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildPosterCard(anime),
                          const SizedBox(height: 24),
                          _buildBannerDetails(anime, inList, isDark, listItem, false),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterCard(AnimeModel anime) {
    return Container(
      width: 190,
      height: 270,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.25),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: anime.image.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: anime.image,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: Colors.white10),
                  )
                : Container(color: Colors.white10),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accent.withOpacity(0.4)),
              ),
              child: Text(
                anime.type.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerDetails(AnimeModel anime, bool inList, bool isDark, AnimeListItem? listItem, bool isDesktop) {
    final align = isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = isDesktop ? TextAlign.start : TextAlign.center;
    
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            if (anime.studios.isNotEmpty)
              _badge(anime.studios.first, AppColors.accent.withOpacity(0.15),
                  textColor: AppColors.accent,
                  borderColor: AppColors.accent.withOpacity(0.3)),
            _badge(anime.status, isDark ? const Color(0xFF1E2230) : const Color(0xFFE0E0EA),
                textColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                borderColor: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          ],
        ),
        const SizedBox(height: 12),

        Text(
          anime.title,
          style: TextStyle(
            fontSize: isDesktop ? 32 : 22,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
            height: 1.1,
            letterSpacing: -0.5,
          ),
          textAlign: textAlign,
        ),
        
        if (anime.romajiTitle != null && anime.romajiTitle != anime.title) ...[
          const SizedBox(height: 4),
          Text(
            anime.romajiTitle!,
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            textAlign: textAlign,
          ),
        ],

        if (anime.japaneseTitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            anime.japaneseTitle,
            style: TextStyle(
              fontSize: isDesktop ? 13 : 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : Colors.black38,
              letterSpacing: 1.2,
            ),
            textAlign: textAlign,
          ),
        ],
        const SizedBox(height: 16),

        Container(
          constraints: const BoxConstraints(maxWidth: 550),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Expanded(child: _metricBox('MAL Score', anime.scoreDisplay, isScore: true, isDark: isDark)),
              _metricDivider(),
              Expanded(child: _metricBox('Rank', anime.rank != null ? '#${anime.rank}' : 'N/A', isDark: isDark)),
              _metricDivider(),
              Expanded(child: _metricBox('Popularity', anime.popularity != null ? '#${anime.popularity}' : 'N/A', isDark: isDark)),
              _metricDivider(),
              Expanded(child: _metricBox('Members', anime.members != null ? _formatNumber(anime.members!) : '0', isMembers: true, isDark: isDark)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _handleAddToList,
              style: ElevatedButton.styleFrom(
                backgroundColor: inList
                    ? AppColors.success.withOpacity(0.2)
                    : AppColors.accent,
                foregroundColor: inList ? AppColors.success : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                side: inList ? BorderSide(color: AppColors.success.withOpacity(0.4)) : null,
                elevation: 0,
              ),
              icon: Icon(inList ? Icons.check : Icons.add, size: 18),
              label: Text(
                inList ? AppText.get('added_to_list') : AppText.get('add_to_list'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ),
              child: IconButton(
                icon: const Icon(Icons.star_outline),
                onPressed: _handleRate,
                tooltip: AppText.get('your_rating'),
              ),
            ),
            Opacity(
              opacity: _witanimeExists ? 1.0 : 0.35,
              child: ElevatedButton.icon(
                onPressed: _witanimeExists
                    ? () {
                        final animeUrl = _witanimeFoundUrl ??
                            'https://${HiveService.witanimeDomain}/anime/${_computeCleanSlug(anime)}/';
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WitAnimePage(
                              initialUrl: animeUrl,
                              animeTitle: anime.title,
                              animeImageUrl: anime.image,
                            ),
                          ),
                        );
                      }
                    : null,
                onLongPress: _witanimeExists
                    ? () async {
                        final animeUrl = _witanimeFoundUrl ??
                            'https://${HiveService.witanimeDomain}/anime/${_computeCleanSlug(anime)}/';
                        final uri = Uri.parse(animeUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  disabledBackgroundColor: isDark ? Colors.white12 : Colors.black12,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: isDark ? Colors.white38 : Colors.black38,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  elevation: 0,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text(
                  'WitAnime',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricBox(String label, String value, {bool isScore = false, bool isMembers = false, bool isDark = true}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white54 : Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isScore) ...[
              const Icon(Icons.star_rounded, size: 14, color: AppColors.starYellow),
              const SizedBox(width: 2),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isScore
                    ? AppColors.starYellow
                    : (isMembers ? AppColors.lavender : (isDark ? Colors.white : Colors.black87)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildSidebar(AnimeModel anime, bool isDark) {
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
              Text(
                'Specifications'.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white70 : Colors.black87,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              _specRow('Type', anime.type, isBadge: true),
              _specDivider(isDark),
              _specRow('Episodes', '${anime.episodes} episodes'),
              _specDivider(isDark),
              _specRow('Duration', anime.duration),
              _specDivider(isDark),
              _specRow('Aired Dates', '${anime.airedFrom?.split('T')?.first ?? '?'} to ${anime.airedTo?.split('T')?.first ?? '?'}'),
              _specDivider(isDark),
              _specRow('Season', anime.season ?? 'N/A'),
              _specDivider(isDark),
              _specRow('Broadcast', '${anime.broadcastDay ?? ''} ${anime.broadcastTime ?? ''}'.trim().isNotEmpty ? '${anime.broadcastDay ?? ''} ${anime.broadcastTime ?? ''}' : 'Unknown'),
              _specDivider(isDark),
              _specRow('Source', anime.source),
              _specDivider(isDark),
              _specRow('Rating', anime.rating),
            ],
          ),
        ),
        const SizedBox(height: 20),

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
              Text(
                'Classifications'.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white70 : Colors.black87,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: anime.genres.map((genre) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.3) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    ),
                    child: Text(
                      genre,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse('https://myanimelist.net/anime/${anime.id}');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.accent.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('View on Official MAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _copyToClipboard('https://myanimelist.net/anime/${anime.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.black.withOpacity(0.3) : Colors.white,
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    elevation: 0,
                    side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy MAL Listing Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _specRow(String label, String value, {bool isBadge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: isBadge
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _specDivider(bool isDark) {
    return Divider(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), height: 1);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied link to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildTabSelector(bool isDark) {
    final tabs = [
      {'id': 'overview', 'label': 'Overview'},
      {'id': 'stats', 'label': 'Metrics & Stats'},
      {'id': 'characters', 'label': 'Cast & Characters'},
      {'id': 'recommendations', 'label': 'Recommendations'},
      {'id': 'reviews', 'label': 'Community Reviews'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      padding: const EdgeInsets.all(6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _activeTab == tab['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _activeTab = tab['id']!;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tab['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(AnimeModel anime, bool isDark, bool isMobile) {
    Widget content;
    switch (_activeTab) {
      case 'stats':
        content = _buildStatsTab(anime, isDark);
        break;
      case 'characters':
        content = _buildCharactersTab(isDark);
        break;
      case 'recommendations':
        content = _buildRecommendationsTab(isDark);
        break;
      case 'reviews':
        content = _buildReviewsTab(isDark);
        break;
      case 'overview':
      default:
        content = _buildOverviewTab(anime, isDark);
        break;
    }

    if (isMobile) {
      if (_activeTab == 'overview') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            const SizedBox(height: 24),
            _buildSidebar(anime, isDark),
          ],
        );
      }
    }

    return content;
  }

  Widget _buildOverviewTab(AnimeModel anime, bool isDark) {
    final cleanSlug = _computeCleanSlug(anime);

    int numEpisodes = 12;
    if (anime.episodes != 'Unknown' && anime.episodes != '?') {
      numEpisodes = int.tryParse(anime.episodes) ?? 12;
      if (numEpisodes == 0 || _witanimePublishedCount > numEpisodes) {
        numEpisodes = _witanimePublishedCount;
      }
    } else {
      numEpisodes = _witanimePublishedCount;
    }
    if (numEpisodes == 0) {
      numEpisodes = 12;
    }

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
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Synopsis / Storyline',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                anime.synopsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                maxLines: _synopsisExpanded ? null : 5,
                overflow: _synopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              if (anime.synopsis.length > 250) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _synopsisExpanded = !_synopsisExpanded;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _synopsisExpanded ? 'Collapse Text ▲' : 'Read Full Synopsis ▼',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (anime.trailerId != null) ...[
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
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Official Media Trailer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _launchTrailer,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage('https://img.youtube.com/vi/${anime.trailerId}/hqdefault.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Watch Trailer',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        if (_witanimeExists) ...[
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
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Episodes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: numEpisodes,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final epNum = index + 1;
                      final isPublished = _publishedEpisodes.isEmpty
                          ? epNum <= _witanimePublishedCount
                          : _publishedEpisodes.contains(epNum);

                      return GestureDetector(
                        onTap: isPublished
                            ? () {
                                final epUrl = 'https://${HiveService.witanimeDomain}/episode/$cleanSlug-%d8%a7%d9%84%d8%ad%d9%84%d9%82%d8%a9-$epNum/';
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WitAnimePage(
                                      initialUrl: epUrl,
                                      animeTitle: '${anime.title} - Ep. $epNum',
                                      animeImageUrl: anime.image,
                                    ),
                                  ),
                                );
                              }
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Episode not published on WitAnime yet'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                        onLongPress: isPublished
                            ? () async {
                                final epUrl = 'https://${HiveService.witanimeDomain}/episode/$cleanSlug-%d8%a7%d9%84%d8%ad%d9%84%d9%82%d8%a9-$epNum/';
                                final uri = Uri.parse(epUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              }
                            : null,
                        child: Opacity(
                          opacity: isPublished ? 1.0 : 0.45,
                          child: Container(
                            width: 180,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withOpacity(0.3) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPublished
                                    ? (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)
                                    : (isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (anime.image.isNotEmpty)
                                  Opacity(
                                    opacity: 0.1,
                                    child: CachedNetworkImage(
                                      imageUrl: anime.image,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                Center(
                                  child: Icon(
                                    isPublished ? Icons.play_circle_fill : Icons.watch_later_outlined,
                                    size: 36,
                                    color: isPublished
                                        ? AppColors.accent.withOpacity(0.85)
                                        : (isDark ? Colors.white30 : Colors.black.withOpacity(0.3)),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  right: 8,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Episode $epNum',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      Text(
                                        isPublished ? 'Watch Episode' : 'Not Published',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isPublished ? Theme.of(context).hintColor : (isDark ? Colors.white30 : Colors.black.withOpacity(0.3)),
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
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Gallery Pictures',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
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
                          itemBuilder: (context, index) => ShimmerLoading.card(context: context, width: 130),
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
                                  child: url.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: url,
                                          width: 130,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(width: 130, color: Colors.white10, child: const Icon(Icons.broken_image, color: Colors.white24)),
                                        )
                                      : Container(width: 130, color: Colors.white10, child: const Icon(Icons.broken_image, color: Colors.white24)),
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

  Widget _buildStatsTab(AnimeModel anime, bool isDark) {
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

    final total = (_statistics!['watching'] ?? 0) +
        (_statistics!['completed'] ?? 0) +
        (_statistics!['on_hold'] ?? 0) +
        (_statistics!['dropped'] ?? 0) +
        (_statistics!['plan_to_watch'] ?? 0);
    final totalVal = total > 0 ? total : 1;

    final stats = [
      {
        'label': 'Completed',
        'value': _statistics!['completed'] ?? 0,
        'color': AppColors.success,
      },
      {
        'label': 'Watching',
        'value': _statistics!['watching'] ?? 0,
        'color': AppColors.watching,
      },
      {
        'label': 'Plan to Watch',
        'value': _statistics!['plan_to_watch'] ?? 0,
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
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Community List Breakdown',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
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

              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        totalCircle,
                        const SizedBox(width: 40),
                        Expanded(child: statsList),
                      ],
                    )
                  : Column(
                      children: [
                        totalCircle,
                        const SizedBox(height: 24),
                        statsList,
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCharactersTab(bool isDark) {
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
        child: const Center(child: Text('No character data available.', style: TextStyle(color: Colors.grey))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Key Characters',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            mainAxisExtent: 80,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _characters.length,
          itemBuilder: (context, index) {
            final char = _characters[index];
            return _buildCharacterCard(char, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildCharacterCard(CharacterModel char, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: char.image.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: char.image,
                    width: 44,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(width: 44, height: 56, color: Colors.white10, child: const Icon(Icons.person, size: 20, color: Colors.white30)),
                  )
                : Container(width: 44, height: 56, color: Colors.white10, child: const Icon(Icons.person, size: 20, color: Colors.white30)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  char.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    char.role,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
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

  Widget _buildRecommendationsTab(bool isDark) {
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
        child: const Center(child: Text('No recommendations available.', style: TextStyle(color: Colors.grey))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Linked & Recommended Shows',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Text(
                    'Handpicked suggestions based on similarity. Click to navigate.',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisExtent: 220,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _recommendations.length,
          itemBuilder: (context, index) {
            final rec = _recommendations[index];
            return GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailPage(
                      animeId: rec.id,
                      onBack: widget.onBack,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                          rec.image.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: rec.image,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(color: Colors.white10, child: const Icon(Icons.movie, color: Colors.white24)),
                                )
                              : Container(color: Colors.white10, child: const Icon(Icons.movie, color: Colors.white24)),
                          if (rec.score != null)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 10, color: AppColors.starYellow),
                                    const SizedBox(width: 2),
                                    Text(
                                      rec.scoreDisplay,
                                      style: const TextStyle(color: AppColors.starYellow, fontSize: 10, fontWeight: FontWeight.bold),
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
                      child: Text(
                        rec.title,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
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
        child: const Center(child: Text('No reviews available.', style: TextStyle(color: Colors.grey))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Community Reviews',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _reviews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final review = _reviews[index];
            final user = review['user'] ?? {};
            final score = review['score'] ?? 0;
            final content = review['review'] ?? '';
            final username = user['username'] ?? 'User';
            final avatarUrl = user['images']?['jpg']?['image_url'] as String?;
            
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            backgroundColor: AppColors.accent.withOpacity(0.2),
                            child: avatarUrl == null
                                ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U')
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'MAL Member',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 12, color: AppColors.starYellow),
                            const SizedBox(width: 4),
                            Text(
                              '$score / 10',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
          },
        ),
      ],
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
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor ?? Colors.white),
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
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(color: Theme.of(context).dividerColor.withOpacity(0.12), height: 1);
  }

  Widget _buildUserRatingCard(UserRating rating) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.06),
            AppColors.mauve.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppText.get('your_rating'),
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent, fontSize: 14)),
              TextButton.icon(
                onPressed: () async {
                  final existing = HiveService.getListItem(_anime!.id);
                  final r = await UserRatingSheet.show(context, existing: existing?.userRating ?? rating);
                  if (r != null && mounted) {
                    if (existing != null) {
                      await HiveService.updateUserRating(_anime!.id, r);
                    } else {
                      final newItem = AnimeListItem.fromAnime(_anime!, AnimeCategory.planned);
                      newItem.userRating = r;
                      await HiveService.addToList(newItem);
                      await HiveService.updateUserRating(_anime!.id, r);
                    }
                    setState(() {});
                  }
                },
                icon: Icon(Icons.edit_outlined, size: 14, color: AppColors.accent),
                label: Text(AppText.get('edit') , style: TextStyle(fontSize: 12, color: AppColors.accent)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceAround,
            children: [
              _ratingPill(AppText.get('overall_rating'), rating.overall, AppColors.accent, large: true),
              _ratingPill(AppText.get('story_rating'), rating.story, AppColors.lavender),
              _ratingPill(AppText.get('character_rating'), rating.character, AppColors.mauve),
              _ratingPill(AppText.get('dialogues_rating'), rating.dialogues, const Color(0xFF38BDF8)),
              _ratingPill(AppText.get('main_idea_rating'), rating.mainIdea, const Color(0xFFFB923C)),
              _ratingPill(AppText.get('draw_rating'), rating.draw, const Color(0xFF60C8A0)),
              _ratingPill(AppText.get('animation_rating'), rating.animation, AppColors.watching),
              _ratingPill(AppText.get('music_rating'), rating.music, AppColors.starYellow),
            ],
          ),
          if (rating.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              rating.notes,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
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
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: large ? 20 : 15,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: color.withOpacity(0.8)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
