import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/app_text.dart';
import '../core/services/hive_service.dart';
import '../core/services/mal_auth_service.dart';
import '../pages/profile_page.dart';

class GlobalSearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final TextEditingController searchController;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool isDesktop;

  const GlobalSearchAppBar({
    super.key,
    required this.searchController,
    this.focusNode,
    required this.onChanged,
    required this.onClear,
    this.isDesktop = false,
  });

  @override
  State<GlobalSearchAppBar> createState() => _GlobalSearchAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

class _GlobalSearchAppBarState extends State<GlobalSearchAppBar> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onStateChange);
    widget.focusNode?.addListener(_onStateChange);
  }

  @override
  void didUpdateWidget(covariant GlobalSearchAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onStateChange);
      widget.searchController.addListener(_onStateChange);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onStateChange);
      widget.focusNode?.addListener(_onStateChange);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onStateChange);
    widget.focusNode?.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  void _showProfileDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoggedIn = MalAuthService.instance.isLoggedIn;
    final username = HiveService.malUsername ?? 'Anime Fan';
    final picUrl = HiveService.malUserPicture;
    final animeCount = HiveService.animeCount;
    final mangaCount = HiveService.mangaCount;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              CircleAvatar(
                radius: 36,
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                backgroundImage: (isLoggedIn && picUrl != null) ? NetworkImage(picUrl) : null,
                child: (!isLoggedIn || picUrl == null)
                    ? Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: isDark ? Colors.white70 : Colors.black54,
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              // Username
              Text(
                username,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isLoggedIn ? Colors.teal.withOpacity(0.15) : (isDark ? Colors.white10 : Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLoggedIn ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                      size: 13,
                      color: isLoggedIn ? Colors.teal : Colors.grey,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isLoggedIn ? 'MAL Connected' : 'Not Connected to MAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isLoggedIn ? Colors.teal : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Stats Container
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '$animeCount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Anime in List',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 28,
                      width: 1,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    Column(
                      children: [
                        Text(
                          '$mangaCount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.lavender,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manga in List',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Button to open Profile Page
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfilePage()),
                    );
                  },
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
                  label: const Text(
                    'Go to Profile Page',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isFocused = widget.focusNode?.hasFocus ?? false;
    final bool hasText = widget.searchController.text.isNotEmpty;
    final bool isExpanded = isFocused || hasText;

    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: EdgeInsets.symmetric(horizontal: widget.isDesktop ? 24 : 16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Left Logo - smoothly collapses when search is focused/active
            if (!widget.isDesktop)
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => AppColors.brandGradient.createShader(bounds),
                      child: const Text(
                        'MA',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),

            // Search Bar Container - expands to fill the space
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isExpanded
                        ? AppColors.accent.withOpacity(0.8)
                        : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    width: isExpanded ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(
                      Icons.search,
                      size: 20,
                      color: isExpanded
                          ? AppColors.accent
                          : (isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: widget.searchController,
                        focusNode: widget.focusNode,
                        onChanged: widget.onChanged,
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: AppText.get('search_anime'),
                          hintStyle: TextStyle(
                            color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    if (hasText) ...[
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: widget.onClear,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                      ),
                      const SizedBox(width: 12),
                    ] else if (isFocused) ...[
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          widget.focusNode?.unfocus();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                      ),
                      const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
            ),

            // Profile Button - collapses on search focus, opens Profile Dialog on tap
            if (!widget.isDesktop)
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _showProfileDialog(context),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: MalAuthService.instance.isLoggedInNotifier,
                        builder: (context, isLoggedIn, _) {
                          final picUrl = HiveService.malUserPicture;
                          return CircleAvatar(
                            radius: 16,
                            backgroundColor: isDark ? Colors.white10 : Colors.black12,
                            backgroundImage: (isLoggedIn && picUrl != null) ? NetworkImage(picUrl) : null,
                            child: (!isLoggedIn || picUrl == null)
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 18,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}
