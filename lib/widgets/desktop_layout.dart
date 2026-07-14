import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../pages/home_page.dart';
import '../pages/schedule_page.dart';
import '../pages/my_list_page.dart';
import '../pages/settings_page.dart';
import '../pages/search_page.dart';
import '../pages/local_library_page.dart';
import 'desktop_navigation_rail.dart';
import 'desktop_right_sidebar.dart';
import '../pages/profile_page.dart';
import '../core/services/mal_auth_service.dart';
import '../core/services/hive_service.dart';
import '../pages/notifications_page.dart';


class DesktopLayout extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onThemeChanged;
  final VoidCallback onLanguageChanged;
  final void Function(int) onSelectAnime;
  final void Function(int) onSelectManga;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;

  const DesktopLayout({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onSelectAnime,
    required this.onSelectManga,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchClear,
  });

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  late int _desktopIndex;
  String? _genreId;
  String? _genreName;

  @override
  void initState() {
    super.initState();
    _desktopIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(covariant DesktopLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _desktopIndex = widget.currentIndex;
    }
    if (widget.searchQuery.isNotEmpty && widget.searchQuery != oldWidget.searchQuery) {
      _desktopIndex = 1; // Auto switch to Explore/Search page on typing search
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _desktopIndex = index;
      _genreId = null;
      _genreName = null;
    });
    widget.onTabSelected(index);
    if (index != 1) {
      widget.onSearchClear();
    }
  }

  void _onGenreSelected(String genreId, String genreName) {
    setState(() {
      _genreId = genreId;
      _genreName = genreName;
      _desktopIndex = 1; // Explore / Search page index
    });
    // Clear top search bar if selecting sidebar genre directly
    widget.onSearchClear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentBg = isDark ? const Color(0xFF0C0E14) : const Color(0xFFF4F4F8);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Left Sidebar Navigation
          DesktopNavigationRail(
            currentIndex: _desktopIndex,
            onTabSelected: _onTabSelected,
            onGenreSelected: _onGenreSelected,
          ),
          
          // 2. Main Content Area (Header + Body Pane)
          Expanded(
            child: Container(
              color: contentBg,
              child: Column(
                children: [
                  // Top Header with Search & Profile Actions
                  _buildDesktopHeader(context),
                  
                  // Content Pane
                  Expanded(
                    child: IndexedStack(
                      index: _desktopIndex,
                      children: [
                        HomePage(
                          onSelectAnime: widget.onSelectAnime,
                          onSelectManga: widget.onSelectManga,
                          isDesktop: true,
                          onSeeAllSchedule: () => _onTabSelected(5),
                        ),
                        SearchPage(
                          onSelectAnime: widget.onSelectAnime,
                          onSelectManga: widget.onSelectManga,
                          searchQuery: widget.searchQuery,
                          hideSearchBar: true,
                          initialGenreId: _genreId,
                          initialGenreName: _genreName,
                        ),
                        MyListPage(onSelectAnime: widget.onSelectAnime),
                        SettingsPage(
                          onThemeChanged: widget.onThemeChanged,
                          onLanguageChanged: widget.onLanguageChanged,
                        ),
                        const LocalLibraryPage(),
                        SchedulePage(onSelectAnime: widget.onSelectAnime),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final searchBg = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
    final searchBorder = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    // Determine current section title
    String title = 'Home';
    if (widget.searchQuery.isNotEmpty) {
      title = 'Search';
    } else {
      switch (_desktopIndex) {
        case 0: title = 'Home'; break;
        case 1: title = 'Explore'; break;
        case 2: title = 'Library'; break;
        case 3: title = 'Settings'; break;
        case 4: title = 'Local Files'; break;
        case 5: title = 'Schedule'; break;
      }
    }

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Section Title
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          
          const Spacer(),
          
          // Search Pill
          Container(
            width: 340,
            height: 38,
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: searchBorder),
            ),
            child: TextField(
              controller: widget.searchController,
              onChanged: widget.onSearchChanged,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(color: textColor, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Chainsaw Man',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.black38,
                  fontSize: 13.5,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
                suffixIcon: widget.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                        onPressed: widget.onSearchClear,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          
          const Spacer(),
          
          // Notification Bell with Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 22),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsPage()),
                  );
                },
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF87171),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // Profile Widget
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            child: Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: MalAuthService.instance.isLoggedInNotifier,
                  builder: (context, isLoggedIn, _) {
                    final username = HiveService.malUsername;
                    return Row(
                      children: [
                        Text(
                          isLoggedIn ? (username ?? 'MAL Profile') : 'Profile',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          backgroundImage: (isLoggedIn && HiveService.malUserPicture != null)
                              ? NetworkImage(HiveService.malUserPicture!)
                              : null,
                          child: (!isLoggedIn || HiveService.malUserPicture == null)
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 18,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                )
                              : null,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
