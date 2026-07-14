import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/app_text.dart';
import '../core/services/hive_service.dart';
import '../core/services/mal_auth_service.dart';
import '../pages/profile_page.dart';

class GlobalSearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool isDesktop;

  const GlobalSearchAppBar({
    super.key,
    required searchController,
    required onChanged,
    required onClear,
    isDesktop = false,
  })  : searchController = searchController,
        onChanged = onChanged,
        onClear = onClear,
        isDesktop = isDesktop;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
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
            if (!isDesktop) ...[
              // Logo for mobile
              ShaderMask(
                shaderCallback: (bounds) => AppColors.brandGradient.createShader(bounds),
                child: const Text(
                  'MA',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(
                      Icons.search,
                      size: 20,
                      color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: onChanged,
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
                    if (searchController.text.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: onClear,
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
            if (!isDesktop) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilePage()),
                  );
                },
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
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}
