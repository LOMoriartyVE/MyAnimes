import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/localization/app_text.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _initCheckTimer;
  bool _dbInitialized = false;

  @override
  void initState() {
    super.initState();
    _dbInitialized = HiveService.isInitialized;
    if (!_dbInitialized) {
      _initCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (
        timer,
      ) {
        if (HiveService.isInitialized) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _dbInitialized = true;
            });
          }
        }
      });
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _initCheckTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildFallbackGlow() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [AppColors.accent.withOpacity(0.08), Colors.transparent],
          radius: 1.5,
        ),
      ),
    );
  }

  List<String> _getPosterUrls() {
    final urls = <String>{};

    // Try season cache
    final season =
        HiveService.getCachedSeasonAllPages() ??
        HiveService.getSeasonCacheIgnoringTtl();
    if (season != null) {
      for (var item in season) {
        final img = item['images']?['jpg']?['large_image_url'] ?? item['image'];
        if (img != null && img.toString().isNotEmpty) {
          urls.add(img.toString());
        }
      }
    }

    // Try top anime cache
    final top = HiveService.getCachedTopAnime();
    if (top != null) {
      for (var item in top) {
        final img = item['images']?['jpg']?['large_image_url'] ?? item['image'];
        if (img != null && img.toString().isNotEmpty) {
          urls.add(img.toString());
        }
      }
    }

    // Try upcoming cache
    final upcoming = HiveService.getCachedUpcoming();
    if (upcoming != null) {
      for (var item in upcoming) {
        final img = item['images']?['jpg']?['large_image_url'] ?? item['image'];
        if (img != null && img.toString().isNotEmpty) {
          urls.add(img.toString());
        }
      }
    }

    return urls.toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = AppText.isArabic;

    final List<String> phrases = isAr
        ? [
            'أنمي الموسم',
            'الأنميات القادمة',
            'الأنميات المستمرة',
            'الأنميات الشائعة',
            'أعلى التقييمات',
            'مكتبتي الخاصة',
          ]
        : [
            'Season Animes',
            'Upcoming Animes',
            'Active Animes',
            'Popular Shows',
            'Top Reviews',
            'My Library',
          ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: _dbInitialized
                  ? ValueListenableBuilder(
                      valueListenable: HiveService.cacheBoxListenable,
                      builder: (context, box, child) {
                        final posterUrls = _getPosterUrls();
                        if (posterUrls.isEmpty) {
                          return _buildFallbackGlow();
                        }
                        return ScrollingPosterCollage(posterUrls: posterUrls);
                      },
                    )
                  : _buildFallbackGlow(),
            ),
          ),

          // 2. Solid Color Overlay (0 blur)
          Positioned.fill(
            child: Container(
              color: isDark
                  ? AppColors.darkBg.withOpacity(0.65)
                  : Colors.white.withOpacity(0.65),
            ),
          ),

          // 3. Central Brand & Progress Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Breathing Logo
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _opacityAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            blurRadius: 35,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          'assets/MA_logo.png',
                          width: 120,
                          height: 120,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                size: 70,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Brand Gradient Text
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.brandGradient.createShader(bounds),
                  child: const Text(
                    'My Animes',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Typewriter Category Text Effect
                SizedBox(
                  height: 32,
                  child: RepaintBoundary(
                    child: TypewriterText(
                      texts: phrases,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Premium Slim Linear Progress Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 4,
                      child: RepaintBoundary(
                        child: LinearProgressIndicator(
                          backgroundColor: isDark
                              ? Colors.white12
                              : Colors.black12,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  isAr ? 'جاري تحميل المجموعة...' : 'Loading collection...',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
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

/// A slow, smooth vertically scrolling grid of tilted anime posters.
class ScrollingPosterCollage extends StatefulWidget {
  final List<String> posterUrls;
  const ScrollingPosterCollage({super.key, required this.posterUrls});

  @override
  State<ScrollingPosterCollage> createState() => _ScrollingPosterCollageState();
}

class _ScrollingPosterCollageState extends State<ScrollingPosterCollage> {
  late ScrollController _scrollController;
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      // Re-trigger in a moment if layout isn't fully calculated yet
      _scrollTimer = Timer(const Duration(milliseconds: 500), _startScrolling);
      return;
    }

    _scrollController
        .animateTo(
          maxScroll,
          duration: const Duration(seconds: 240),
          curve: Curves.linear,
        )
        .then((_) {
          if (mounted) {
            _scrollController.jumpTo(0);
            _startScrolling();
          }
        });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Duplicate posters to ensure enough content for smooth scrolling
    final items = <String>[];
    for (int i = 0; i < 4; i++) {
      items.addAll(widget.posterUrls);
    }

    return Transform.rotate(
      angle: -0.06, // Slight tilt of the entire collage
      child: Transform.scale(
        scale: 1.15, // Scale up slightly to prevent empty corners due to tilt
        child: GridView.builder(
          controller: _scrollController,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.7,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final url = items[index];
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Opacity(
                  opacity:
                      0.9, // Increased collage opacity for better visibility
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey.withOpacity(0.05)),
                    errorWidget: (context, url, error) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Typewriter Text component that selects phrases in random order, types/deletes them.
class TypewriterText extends StatefulWidget {
  final List<String> texts;
  final TextStyle style;
  const TypewriterText({super.key, required this.texts, required this.style});

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayText = '';
  late List<String> _shuffledTexts;
  int _textsIndex = 0;
  int _charIndex = 0;
  bool _isDeleting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Copy and shuffle phrases to satisfy the random selection requirement
    _shuffledTexts = List<String>.from(widget.texts)..shuffle();
    _tick();
  }

  void _tick() {
    if (!mounted) return;

    final currentFullText = _shuffledTexts[_textsIndex];

    if (_isDeleting) {
      if (_charIndex > 0) {
        setState(() {
          _charIndex--;
          _displayText = currentFullText.substring(0, _charIndex);
        });
        _timer = Timer(const Duration(milliseconds: 40), _tick);
      } else {
        _isDeleting = false;
        // Move to the next text
        _textsIndex = (_textsIndex + 1) % _shuffledTexts.length;
        // Reshuffle when we loop through all texts to maintain randomness
        if (_textsIndex == 0) {
          _shuffledTexts.shuffle();
        }
        _timer = Timer(const Duration(milliseconds: 300), _tick);
      }
    } else {
      if (_charIndex < currentFullText.length) {
        setState(() {
          _charIndex++;
          _displayText = currentFullText.substring(0, _charIndex);
        });
        _timer = Timer(const Duration(milliseconds: 90), _tick);
      } else {
        _isDeleting = true;
        _timer = Timer(const Duration(milliseconds: 1600), _tick);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_displayText, style: widget.style),
        const _BlinkingCursor(),
      ],
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Text(
        '|',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
