import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/services/hive_service.dart';
import 'core/services/download_manager.dart';
import 'core/services/google_drive_service.dart';
import 'core/services/jikan_service.dart';
import 'core/localization/app_text.dart';
import 'pages/loading_page.dart';
import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/schedule_page.dart';
import 'pages/my_list_page.dart';
import 'pages/settings_page.dart';
import 'pages/detail_page.dart';
import 'pages/local_library_page.dart';
import 'widgets/global_search_app_bar.dart';
import 'widgets/desktop_layout.dart';
import 'pages/manga_detail_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  runApp(const MyAnimesApp());
}

class MyAnimesApp extends StatefulWidget {
  const MyAnimesApp({super.key});

  @override
  State<MyAnimesApp> createState() => _MyAnimesAppState();
}

class _MyAnimesAppState extends State<MyAnimesApp> {
  bool _initialized = false;
  String _themePack = 'default_dark';
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final startTime = DateTime.now();
    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      debugPrint("MediaKit init error (e.g. test environment without libmpv): $e");
    }
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("Failed to load .env file: $e");
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Firebase init failed or timed out: $e");
    }

    try {
      await HiveService.init();
      HiveService.healListItemsMetadata();
      HiveService.processOfflineQueue();
      DownloadManager.instance.init();

      // Trigger automatic backup to Google Drive when local data changes (debounced)
      HiveService.onDataChanged = () {
        GoogleDriveService.scheduleAutoBackup();
      };

      // Silently authenticate with Google Drive if previous credentials exist
      GoogleDriveService.signInSilently();

      // We do not await this, because FCM subscribeToTopic can hang indefinitely on Android emulators
      NotificationService.init().catchError((e) {
        debugPrint("Notification init failed: $e");
      });
    } catch (e) {
      debugPrint("Core services init failed: $e");
    }

    try {
      // Load saved settings
      _themePack = HiveService.themePack;
      _language = HiveService.language;
    } catch (e) {
      debugPrint("Settings load err: $e");
      _themePack = 'default_dark';
      _language = 'en';
    }
    
    AppText.setLanguage(_language);

    // Preload large API data before hiding loading screen if not already cached
    await _preloadData();

    // Ensure smooth render transition without artificial lag
    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 400) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    setState(() => _initialized = true);
  }

  Future<void> _preloadData() async {
    try {
      final hasCached = HiveService.hasAnySeasonCache();
      if (hasCached) {
        // Cache exists: HomePage will display instantly and manage stale refresh
        return;
      }

      final all = await JikanService.getSeasonNow(limit: 25, page: 1)
          .timeout(const Duration(seconds: 3));
      if (all.isNotEmpty) {
        await HiveService.cacheSeasonAllPages(all.map((a) => {
          'mal_id': a.id,
          'title': a.title,
          'title_japanese': a.japaneseTitle,
          'images': {'jpg': {'large_image_url': a.image}},
          'score': a.score,
          'synopsis': a.synopsis,
          'genres': a.genres.map((g) => {'name': g}).toList(),
          'status': a.status,
          'rating': a.rating,
          'studios': a.studios.map((s) => {'name': s}).toList(),
          'type': a.type,
          'source': a.source,
          'duration': a.duration,
          'episodes': a.episodes,
          'year': a.year,
          'members': a.members,
          'rank': a.rank,
          'popularity': a.popularity,
          'broadcast': {
             'day': a.broadcastDay,
             'time': a.broadcastTime,
          },
        }).toList());
      }
    } catch (e) {
      debugPrint("Preload error: $e");
    }
  }

  void _onThemeChanged() {
    setState(() {
      _themePack = HiveService.themePack;
    });
  }

  void _onLanguageChanged() {
    setState(() {
      _language = HiveService.language;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style
    final isDark = _themePack != 'default_light';
    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: AppColors.darkNavBar,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: AppColors.lightNavBar,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Animes',
      theme: AppTheme.getTheme(_themePack),
      locale: Locale(_language),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.unknown},
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: _language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
      home: _initialized
          ? MainLayout(
              onThemeChanged: _onThemeChanged,
              onLanguageChanged: _onLanguageChanged,
            )
          : const LoadingPage(),
    );
  }
}

class MainLayout extends StatefulWidget {
  final VoidCallback onThemeChanged;
  final VoidCallback onLanguageChanged;

  const MainLayout({
    super.key,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex   = 0;
  final Set<int> _loadedTabs = {0};
  int? _selectedAnimeId;
  int? _selectedMangaId;
  DateTime? _lastBackPressTime;

  final TextEditingController _globalSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _globalSearchQuery = '';
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChange);
    _checkVersionUpdate();
  }

  void _onSearchFocusChange() {
    if (mounted) {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    _globalSearchController.dispose();
    super.dispose();
  }

  void _onGlobalSearchChanged(String query) {
    if (!mounted) return;
    setState(() {
      _globalSearchQuery = query;
    });
  }

  void _clearGlobalSearch() {
    _globalSearchController.clear();
    _searchFocusNode.unfocus();
    if (!mounted) return;
    setState(() {
      _globalSearchQuery = '';
      _isSearchFocused = false;
    });
  }

  void _navigateToDetail(int animeId) {
    if (!mounted) return;
    setState(() { _selectedAnimeId = animeId; _selectedMangaId = null; });
  }

  void _navigateToManga(int mangaId) {
    if (!mounted) return;
    setState(() { _selectedMangaId = mangaId; _selectedAnimeId = null; });
  }

  void _backFromDetail() {
    if (!mounted) return;
    setState(() { _selectedAnimeId = null; _selectedMangaId = null; });
  }

  void _switchTab(int index) {
    if (!mounted) return;
    _searchFocusNode.unfocus();
    setState(() {
      _currentIndex = index;
      _loadedTabs.add(index);
      _selectedAnimeId = null;
      _selectedMangaId = null;
      _isSearchFocused = false;
    });
  }

  Future<bool> _handleBackPress() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppText.get('press_back_again')),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show manga detail page as overlay
    if (_selectedMangaId != null) {
      return AnimatedOverlay(
        child: MangaDetailPage(
          key: ValueKey('manga_$_selectedMangaId'),
          mangaId: _selectedMangaId!,
          onBack: _backFromDetail,
        ),
      );
    }

    // Show anime detail page as overlay
    if (_selectedAnimeId != null) {
      return AnimatedOverlay(
        child: DetailPage(
          key: ValueKey('anime_$_selectedAnimeId'),
          animeId: _selectedAnimeId!,
          onBack: _backFromDetail,
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_globalSearchQuery.isNotEmpty || _isSearchFocused) {
          _clearGlobalSearch();
          return;
        }
        final shouldExit = await _handleBackPress();
        if (shouldExit && mounted) {
          SystemNavigator.pop();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return DesktopLayout(
              currentIndex: _currentIndex,
              onTabSelected: _switchTab,
              onThemeChanged: widget.onThemeChanged,
              onLanguageChanged: widget.onLanguageChanged,
              onSelectAnime: _navigateToDetail,
              onSelectManga: _navigateToManga,
              searchController: _globalSearchController,
              searchQuery: _globalSearchQuery,
              onSearchChanged: _onGlobalSearchChanged,
              onSearchClear: _clearGlobalSearch,
            );
          }

          final bool isSearching = _globalSearchQuery.isNotEmpty || _isSearchFocused;

          return Scaffold(
            appBar: _currentIndex == 0
                ? GlobalSearchAppBar(
                    searchController: _globalSearchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onGlobalSearchChanged,
                    onClear: _clearGlobalSearch,
                    isDesktop: false,
                  )
                : null,
            body: isSearching
                ? SearchPage(
                    onSelectAnime: _navigateToDetail,
                    onSelectManga: _navigateToManga,
                    searchQuery: _globalSearchQuery,
                    hideSearchBar: true,
                  )
                : IndexedStack(
                    index: _currentIndex,
                    children: [
                      HomePage(
                        onSelectAnime: _navigateToDetail,
                        onSelectManga: _navigateToManga,
                        onSeeAllSchedule: () => _switchTab(1),
                      ),
                      _loadedTabs.contains(1)
                          ? SchedulePage(onSelectAnime: _navigateToDetail)
                          : const SizedBox.shrink(),
                      _loadedTabs.contains(2)
                          ? MyListPage(onSelectAnime: _navigateToDetail)
                          : const SizedBox.shrink(),
                      _loadedTabs.contains(3)
                          ? SettingsPage(
                              onThemeChanged: widget.onThemeChanged,
                              onLanguageChanged: widget.onLanguageChanged,
                            )
                          : const SizedBox.shrink(),
                      _loadedTabs.contains(4)
                          ? const LocalLibraryPage()
                          : const SizedBox.shrink(),
                    ],
                  ),
            bottomNavigationBar: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkNavBar : AppColors.lightNavBar,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(0, Icons.home_rounded, AppText.get('nav_home')),
                            _buildNavItem(1, Icons.calendar_month_rounded, AppText.get('nav_schedule')),
                            _buildNavItem(2, Icons.list_alt_rounded, AppText.get('nav_my_list')),
                            _buildNavItem(4, Icons.folder_copy_rounded, AppText.get('nav_library')),
                            _buildNavItem(3, Icons.settings_rounded, AppText.get('nav_settings')),
                          ],
                        ),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {bool showBadge = false}) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listCount = showBadge ? HiveService.getAllListItems().length : 0;
    final unselectedColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? AppColors.accent : unselectedColor,
                ),
                if (showBadge && listCount > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$listCount',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.accent : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkVersionUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lastShown = HiveService.getLastVersionShown();
      const currentVersion = '1.4.0';
      if (lastShown != currentVersion) {
        _showWhatsNewDialog(context);
        HiveService.setLastVersionShown(currentVersion);
      }
    });
  }

  void _showWhatsNewDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = AppText.isArabic;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.new_releases, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                isAr ? "ما الجديد في v1.4.0" : "What's New in v1.4.0",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWhatsNewItem(
                  icon: Icons.calendar_month_rounded,
                  title: isAr ? "تحديد مواسم متعددة وفلاتر الجدول" : "Multi-Season Schedule & Filters",
                  desc: isAr 
                    ? "اختر عدة مواسم في وقت واحد مع فلاتر ذكية لإخفاء الأنميات المنتهية، أو قيد المشاهدة، أو المتجاهلة، أو المخطط لها."
                    : "Select multiple seasons at once with flexible schedule filters to hide finished, currently watching, ignored, or planned anime.",
                  isDark: isDark,
                ),
                _buildWhatsNewItem(
                  icon: Icons.tune_rounded,
                  title: isAr ? "تطوير الفرز والفلترة المتقدمة" : "Advanced Multi-Choice Filters",
                  desc: isAr 
                    ? "نطاقات مخصصة للحلقات، دعم الأنميات غير محددة الحلقات، وألوان مخصصة ومميزة لكل تصنيف واستوديو."
                    : "Custom episode numeric ranges, unknown end episode support, and vibrant curated color badges for every genre and studio.",
                  isDark: isDark,
                ),
                _buildWhatsNewItem(
                  icon: Icons.grid_view_rounded,
                  title: isAr ? "أزرار أنماط العرض المتوافقة مع الثيم" : "Theme-Aware Header Mode Switcher",
                  desc: isAr 
                    ? "تبديل سريع بين أنماط العرض في الشريط العلوي بلون الثيم المخصص، مع إزالة الأشرطة الزائدة لتوفير مساحة عرض قصوى."
                    : "Compact header view mode switcher matching the active theme accent, removing redundant bars to maximize schedule viewing space.",
                  isDark: isDark,
                ),
                _buildWhatsNewItem(
                  icon: Icons.palette_rounded,
                  title: isAr ? "استقرار وتناسق التصميم والألوان" : "Design Stability & Theme Harmony",
                  desc: isAr 
                    ? "استقرار كامل لمساحات القوائم ومنع القفزات عند التحديد مع توافق كامل للألوان في الوضعين الفاتح والداكن."
                    : "Zero layout jumping on filter selection with pixel-perfect contrast across dark and light themes.",
                  isDark: isDark,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: Text(isAr ? "ابدأ الاستكشاف" : "Start Exploring"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWhatsNewItem({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black54,
                    fontSize: 12,
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

class AnimatedOverlay extends StatefulWidget {
  final Widget child;
  const AnimatedOverlay({super.key, required this.child});

  @override
  State<AnimatedOverlay> createState() => _AnimatedOverlayState();
}

class _AnimatedOverlayState extends State<AnimatedOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const ElasticOutCurve(0.95),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
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
