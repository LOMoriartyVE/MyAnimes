import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/localization/app_text.dart';

class ExclusionsSettingsPage extends StatefulWidget {
  const ExclusionsSettingsPage({super.key});

  @override
  State<ExclusionsSettingsPage> createState() => _ExclusionsSettingsPageState();
}

class _ExclusionsSettingsPageState extends State<ExclusionsSettingsPage> {
  late Set<String> _excluded;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customCategoryController = TextEditingController();
  String _searchQuery = '';

  // Preset definitions
  static const List<String> _presetExplicit = ['Hentai', 'Erotica', 'Ecchi'];
  static const List<String> _presetRomance = ['Romance', 'Boys Love', 'Girls Love'];
  static const List<String> _presetHorror = ['Horror', 'Gore', 'Suspense'];
  static const List<String> _presetAction = ['Action', 'Martial Arts', 'Military'];

  // Categorized standard genres and themes
  static const List<String> _matureCategories = [
    'Hentai',
    'Erotica',
    'Ecchi',
    'Boys Love',
    'Girls Love',
    'Gore',
  ];

  static const List<String> _mainGenres = [
    'Action',
    'Adventure',
    'Avant Garde',
    'Award Winning',
    'Comedy',
    'Drama',
    'Fantasy',
    'Gourmet',
    'Horror',
    'Mystery',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Suspense',
    'Thriller',
  ];

  static const List<String> _themes = [
    'Adult Cast',
    'Anthropomorphic',
    'CGDCT',
    'Childcare',
    'Combat Sports',
    'Crossdressing',
    'Delinquents',
    'Detective',
    'Educational',
    'Gag Humor',
    'Harem',
    'High Stakes Game',
    'Historical',
    'Idols (Female)',
    'Idols (Male)',
    'Isekai',
    'Iyashikei',
    'Love Polygon',
    'Magical Sex Shift',
    'Mahou Shoujo',
    'Martial Arts',
    'Mecha',
    'Medical',
    'Military',
    'Music',
    'Mythology',
    'Organized Crime',
    'Otaku Culture',
    'Parody',
    'Performing Arts',
    'Pets',
    'Psychological',
    'Racing',
    'Reincarnation',
    'Reverse Harem',
    'Romantic Subtext',
    'Samurai',
    'School',
    'Showbiz',
    'Space',
    'Strategy Game',
    'Super Power',
    'Survival',
    'Team Sports',
    'Time Travel',
    'Vampire',
    'Video Game',
    'Visual Arts',
    'Workplace',
  ];

  static const List<String> _demographics = [
    'Shounen',
    'Seinen',
    'Shoujo',
    'Josei',
    'Kids',
  ];

  static const List<String> _mediaTypes = [
    'Music',
    'Special',
    'OVA',
    'ONA',
  ];

  @override
  void initState() {
    super.initState();
    _excluded = HiveService.excludedCategories.toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _toggleCategory(String category) async {
    HapticFeedback.selectionClick();
    setState(() {
      // Find matching entry regardless of case
      final lower = category.trim().toLowerCase();
      final existing = _excluded.firstWhere(
        (e) => e.trim().toLowerCase() == lower,
        orElse: () => '',
      );

      if (existing.isNotEmpty) {
        _excluded.remove(existing);
      } else {
        _excluded.add(category.trim());
      }
    });

    await HiveService.setExcludedCategories(_excluded.toList());
  }

  bool _isCategoryExcluded(String category) {
    final lower = category.trim().toLowerCase();
    return _excluded.any((e) => e.trim().toLowerCase() == lower);
  }

  Future<void> _togglePreset(List<String> presetCategories) async {
    HapticFeedback.mediumImpact();
    final allActive = presetCategories.every(_isCategoryExcluded);

    setState(() {
      for (final cat in presetCategories) {
        final lower = cat.trim().toLowerCase();
        if (allActive) {
          _excluded.removeWhere((e) => e.trim().toLowerCase() == lower);
        } else {
          if (!_isCategoryExcluded(cat)) {
            _excluded.add(cat);
          }
        }
      }
    });

    await HiveService.setExcludedCategories(_excluded.toList());
  }

  Future<void> _clearAllExclusions() async {
    HapticFeedback.lightImpact();
    setState(() {
      _excluded.clear();
    });
    await HiveService.setExcludedCategories([]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All exclusions cleared. All anime and manga are now visible.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addCustomCategory() async {
    final text = _customCategoryController.text.trim();
    if (text.isEmpty) return;

    if (_isCategoryExcluded(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$text" is already excluded.')),
      );
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _excluded.add(text);
      _customCategoryController.clear();
    });

    await HiveService.setExcludedCategories(_excluded.toList());
  }

  List<String> _filterList(List<String> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((item) => item.toLowerCase().contains(q)).toList();
  }

  // Get custom exclusions (entries not in any predefined lists)
  List<String> _getCustomExclusions() {
    final allKnown = {
      ..._matureCategories.map((s) => s.toLowerCase()),
      ..._mainGenres.map((s) => s.toLowerCase()),
      ..._themes.map((s) => s.toLowerCase()),
      ..._demographics.map((s) => s.toLowerCase()),
      ..._mediaTypes.map((s) => s.toLowerCase()),
    };

    return _excluded.where((e) => !allKnown.contains(e.toLowerCase())).toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customExclusions = _filterList(_getCustomExclusions());

    final filteredMature = _filterList(_matureCategories);
    final filteredMain = _filterList(_mainGenres);
    final filteredThemes = _filterList(_themes);
    final filteredDemographics = _filterList(_demographics);
    final filteredMediaTypes = _filterList(_mediaTypes);

    final bool hasAnyMatch = filteredMature.isNotEmpty ||
        filteredMain.isNotEmpty ||
        filteredThemes.isNotEmpty ||
        filteredDemographics.isNotEmpty ||
        filteredMediaTypes.isNotEmpty ||
        customExclusions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppText.get('exclusions'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_excluded.isNotEmpty)
            TextButton(
              onPressed: _clearAllExclusions,
              child: const Text(
                'Reset All',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Summary Banner ──
              _buildTopBanner(isDark),
              const SizedBox(height: 18),

              // ── Quick Presets ──
              _buildPresetsBar(isDark),
              const SizedBox(height: 16),

              // ── Search Bar ──
              _buildSearchBar(isDark),
              const SizedBox(height: 14),

              // ── Add Custom Category Field ──
              _buildAddCustomField(isDark),
              const SizedBox(height: 22),

              if (!hasAnyMatch)
                _buildNoMatchState(isDark)
              else ...[
                // Custom Exclusions (if any)
                if (customExclusions.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'Custom Exclusions',
                    icon: Icons.bookmark_added_rounded,
                    count: customExclusions.length,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildChipsWrap(customExclusions, isCustom: true),
                  const SizedBox(height: 22),
                ],

                // 1. Mature & Sensitive
                if (filteredMature.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'Mature & Explicit',
                    subtitle: 'Adult, 18+, and sensitive categories',
                    icon: Icons.explicit_rounded,
                    accentColor: const Color(0xFFEF4444),
                    count: filteredMature.where(_isCategoryExcluded).length,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildChipsWrap(filteredMature, highlightColor: const Color(0xFFEF4444)),
                  const SizedBox(height: 22),
                ],

                // 2. Main Genres
                if (filteredMain.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'Main Genres',
                    subtitle: 'Primary narrative and story genres',
                    icon: Icons.movie_filter_rounded,
                    accentColor: AppColors.accent,
                    count: filteredMain.where(_isCategoryExcluded).length,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildChipsWrap(filteredMain),
                  const SizedBox(height: 22),
                ],

                // 3. Themes & Tropes
                if (filteredThemes.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'Themes & Tropes',
                    subtitle: 'Specific story tropes, settings, and themes',
                    icon: Icons.palette_outlined,
                    accentColor: const Color(0xFF8B5CF6),
                    count: filteredThemes.where(_isCategoryExcluded).length,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildChipsWrap(filteredThemes),
                  const SizedBox(height: 22),
                ],

                // 4. Demographics
                if (filteredDemographics.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'Demographics',
                    subtitle: 'Target audience classifications',
                    icon: Icons.people_alt_outlined,
                    accentColor: const Color(0xFF06B6D4),
                    count: filteredDemographics.where(_isCategoryExcluded).length,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildChipsWrap(filteredDemographics),
                  const SizedBox(height: 22),
                ],

                // 5. Media Types
                if (filteredMediaTypes.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: 'Media Types',
                    subtitle: 'Anime formats and promotional releases',
                    icon: Icons.tv_rounded,
                    accentColor: const Color(0xFFF59E0B),
                    count: filteredMediaTypes.where(_isCategoryExcluded).length,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildChipsWrap(filteredMediaTypes),
                  const SizedBox(height: 22),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBanner(bool isDark) {
    final count = _excluded.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: count > 0 ? Colors.redAccent.withAlpha(60) : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          width: count > 0 ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (count > 0 ? Colors.redAccent : Colors.black).withAlpha(isDark ? 30 : 12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.redAccent.withAlpha(30) : AppColors.accent.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              count > 0 ? Icons.block_rounded : Icons.shield_outlined,
              color: count > 0 ? Colors.redAccent : AppColors.accent,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Content Filter',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: count > 0 ? Colors.redAccent.withAlpha(35) : AppColors.completed.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count > 0 ? '$count Excluded' : 'All Visible',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: count > 0 ? Colors.redAccent : AppColors.completed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Excluded categories are hidden everywhere in the app, including Home recommendations, Search, Seasonal schedule, and the Random Selector.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsBar(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 16, color: Colors.orangeAccent),
            const SizedBox(width: 6),
            Text(
              'Quick Presets',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetChip('🔞 Adult / Explicit', _presetExplicit, const Color(0xFFEF4444), isDark),
              const SizedBox(width: 8),
              _buildPresetChip('💘 Romance & BL/GL', _presetRomance, const Color(0xFFEC4899), isDark),
              const SizedBox(width: 8),
              _buildPresetChip('👻 Horror & Gore', _presetHorror, const Color(0xFF8B5CF6), isDark),
              const SizedBox(width: 8),
              _buildPresetChip('⚔️ Action & Combat', _presetAction, const Color(0xFF3B82F6), isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, List<String> categories, Color color, bool isDark) {
    final allActive = categories.every(_isCategoryExcluded);
    final anyActive = categories.any(_isCategoryExcluded);

    return InkWell(
      onTap: () => _togglePreset(categories),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: allActive
              ? color.withAlpha(45)
              : (anyActive ? color.withAlpha(20) : (isDark ? const Color(0xFF1E2230) : const Color(0xFFE2E8F0))),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: allActive ? color : (anyActive ? color.withAlpha(120) : Colors.transparent),
            width: allActive ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: allActive ? FontWeight.bold : FontWeight.w600,
                color: allActive
                    ? (isDark ? Colors.white : color)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              allActive ? Icons.check_circle_rounded : (anyActive ? Icons.indeterminate_check_box_rounded : Icons.add_circle_outline_rounded),
              size: 14,
              color: allActive ? color : (isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search categories to exclude...',
          hintStyle: TextStyle(color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint, fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 20, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        ),
      ),
    );
  }

  Widget _buildAddCustomField(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191D2A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2B3248) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _customCategoryController,
              onSubmitted: (_) => _addCustomCategory(),
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Add custom category or tag to exclude...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _addCustomCategory,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16),
                SizedBox(width: 4),
                Text('Exclude', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    required IconData icon,
    Color? accentColor,
    required int count,
    required bool isDark,
  }) {
    final color = accentColor ?? AppColors.accent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.redAccent.withAlpha(35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count excluded',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChipsWrap(List<String> categories, {Color? highlightColor, bool isCustom = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((category) {
        final isExcluded = _isCategoryExcluded(category);
        final activeColor = highlightColor ?? Colors.redAccent;

        return InkWell(
          onTap: () => _toggleCategory(category),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isExcluded
                  ? activeColor.withAlpha(isDark ? 45 : 30)
                  : (isDark ? const Color(0xFF1E2232) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExcluded
                    ? activeColor
                    : (isDark ? const Color(0xFF2D354E) : const Color(0xFFE2E8F0)),
                width: isExcluded ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isExcluded ? Icons.block_rounded : Icons.add_circle_outline_rounded,
                  size: 14,
                  color: isExcluded ? activeColor : (isDark ? Colors.white54 : Colors.black45),
                ),
                const SizedBox(width: 6),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isExcluded ? FontWeight.w800 : FontWeight.w600,
                    color: isExcluded
                        ? (isDark ? Colors.white : activeColor)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                if (isCustom) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _toggleCategory(category),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isExcluded ? activeColor : Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoMatchState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              'No categories match "$_searchQuery"',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the "Exclude" button above to add it as a custom exclusion.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
