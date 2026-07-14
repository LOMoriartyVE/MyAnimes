import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_list_item.dart';
import '../core/localization/app_text.dart';

/// Result returned from the CategoryPickerSheet.
/// Either a category was selected, or the user chose to delete the item from the list.
sealed class CategoryPickerResult {}

class CategorySelected extends CategoryPickerResult {
  final AnimeCategory category;
  CategorySelected(this.category);
}

class DeleteFromList extends CategoryPickerResult {}

/// Bottom sheet dialog for selecting anime list category.
/// Also shows a Delete button when the anime is already in the list.
class CategoryPickerSheet extends StatelessWidget {
  final AnimeCategory? currentCategory;

  const CategoryPickerSheet({super.key, this.currentCategory});

  static Future<CategoryPickerResult?> show(BuildContext context, {AnimeCategory? current}) {
    return showModalBottomSheet<CategoryPickerResult>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryPickerSheet(currentCategory: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInList = currentCategory != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppText.get('select_category'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildOption(context, AnimeCategory.planned, Icons.bookmark_outline, AppColors.planned),
              _buildOption(context, AnimeCategory.watching, Icons.play_circle_outline, AppColors.watching),
              _buildOption(context, AnimeCategory.completed, Icons.check_circle_outline, AppColors.completed),
              _buildOption(context, AnimeCategory.ignored, Icons.visibility_off_outlined, AppColors.ignored),
    
              // ── Delete button (only shown when already in list) ──
              if (isInList) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Divider(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline, color: AppColors.error, size: 24),
                  ),
                  title: Text(
                    AppText.get('delete_from_list'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(DeleteFromList()),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                ),
              ],
    
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, AnimeCategory category, IconData icon, Color color) {
    final isSelected = currentCategory == category;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String label;
    switch (category) {
      case AnimeCategory.planned:
        label = AppText.get('planned');
        break;
      case AnimeCategory.watching:
        label = AppText.get('watching');
        break;
      case AnimeCategory.completed:
        label = AppText.get('completed');
        break;
      case AnimeCategory.ignored:
        label = AppText.get('ignored');
        break;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(isSelected ? 60 : 25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: color)
          : null,
      onTap: () => Navigator.of(context).pop(CategorySelected(category)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
