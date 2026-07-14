import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/app_text.dart';
import '../core/services/hive_service.dart';
import '../core/services/jikan_service.dart';

class DesktopNavigationRail extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final void Function(String genreId, String genreName)? onGenreSelected;

  const DesktopNavigationRail({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.onGenreSelected,
  });

  @override
  State<DesktopNavigationRail> createState() => _DesktopNavigationRailState();
}

class _DesktopNavigationRailState extends State<DesktopNavigationRail> {
  bool _isLibraryExpanded = true;
  bool _isGenresExpanded = false;
  List<Map<String, dynamic>> _genresList = [];

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    var cached = HiveService.getCachedGenres();
    if (cached == null || cached.isEmpty) {
      cached = await JikanService.getAnimeGenres();
      if (cached.isNotEmpty) {
        await HiveService.cacheGenres(cached);
      }
    }
    if (mounted) {
      setState(() {
        _genresList = cached ?? [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark ? const Color(0xFF11121A) : const Color(0xFFF0F1F6);
    
    // Check if the current tab belongs to library (My List is index 2, Local Library is index 4)
    final isLibraryActive = widget.currentIndex == 2 || widget.currentIndex == 4;

    return Container(
      width: 240,
      color: sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          
          // ── App Brand Logo & Name ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppColors.brandGradient.createShader(bounds),
                  child: const Text(
                    'MyAnimes',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // ── Main Menu Section ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // Home
                _buildMenuItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: AppText.get('nav_home'),
                  index: 0,
                ),
                const SizedBox(height: 6),
                
                // Explore
                _buildMenuItem(
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  label: 'Explore',
                  index: 1,
                ),
                const SizedBox(height: 6),
                
                // My Library Expandable
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLibraryHeader(isLibraryActive),
                      if (_isLibraryExpanded) ...[
                        _buildSubmenuItem(
                          label: 'Online Watchlist',
                          index: 2,
                        ),
                        _buildSubmenuItem(
                          label: 'Local Files',
                          index: 4,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                
                // Schedule
                _buildMenuItem(
                  icon: Icons.calendar_month_outlined,
                  activeIcon: Icons.calendar_month,
                  label: 'Schedule',
                  index: 5,
                ),
                
                const SizedBox(height: 24),
                
                // ── Genres Section ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'GENRES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white30 : Colors.black38,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                
                _buildGenreItem(
                  icon: Icons.bolt_outlined,
                  label: 'Action',
                  genreId: '1',
                ),
                _buildGenreItem(
                  icon: Icons.landscape_outlined,
                  label: 'Adventure',
                  genreId: '2',
                ),
                _buildGenreItem(
                  icon: Icons.face_outlined,
                  label: 'Comedy',
                  genreId: '4',
                ),
                _buildGenreItem(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Fantasy',
                  genreId: '10',
                ),
                _buildGenreItem(
                  icon: Icons.science_outlined,
                  label: 'Sci-Fi',
                  genreId: '24',
                ),
                
                _buildGenresDropdown(),
              ],
            ),
          ),
          
          // ── Settings (at the bottom) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: _buildMenuItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: AppText.get('nav_settings'),
              index: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = widget.currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => widget.onTabSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Left purple indicator bar
            if (isSelected)
              Container(
                width: 3,
                height: 18,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            Icon(
              isSelected ? activeIcon : icon,
              size: 20,
              color: isSelected ? AppColors.accent : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white70 : Colors.black54),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryHeader(bool isLibraryActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () {
        setState(() {
          _isLibraryExpanded = !_isLibraryExpanded;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              isLibraryActive ? Icons.folder_copy : Icons.folder_copy_outlined,
              size: 20,
              color: isLibraryActive ? AppColors.accent : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'My Library',
                style: TextStyle(
                  color: isLibraryActive ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white70 : Colors.black54),
                  fontWeight: isLibraryActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              _isLibraryExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: isDark ? Colors.white30 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmenuItem({
    required String label,
    required int index,
  }) {
    final isSelected = widget.currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => widget.onTabSelected(index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        margin: const EdgeInsets.only(left: 36, right: 8, top: 2, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.accent : (isDark ? Colors.white60 : Colors.black54),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildGenreItem({
    required IconData icon,
    required String label,
    required String genreId,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () {
        if (widget.onGenreSelected != null) {
          widget.onGenreSelected!(genreId, label);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenresDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Filter out the top 5 genres from the all genres list to avoid duplicates
    final top5Ids = {'1', '2', '4', '10', '24'};
    final otherGenres = _genresList.where((g) {
      final id = g['mal_id']?.toString();
      return id != null && !top5Ids.contains(id);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isGenresExpanded = !_isGenresExpanded;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'More Genres',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Icon(
                  _isGenresExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
              ],
            ),
          ),
        ),
        if (_isGenresExpanded) ...[
          for (var genre in otherGenres)
            _buildSubmenuGenreItem(
              label: genre['name'] ?? 'Unknown',
              genreId: genre['mal_id']?.toString() ?? '',
            ),
        ],
      ],
    );
  }

  Widget _buildSubmenuGenreItem({
    required String label,
    required String genreId,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () {
        if (widget.onGenreSelected != null) {
          widget.onGenreSelected!(genreId, label);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 32,
        margin: const EdgeInsets.only(left: 36, right: 8, top: 1, bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontWeight: FontWeight.w500,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
