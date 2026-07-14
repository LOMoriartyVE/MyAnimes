import 'package:flutter/material.dart';
import '../core/models/anime_model.dart';
import '../core/localization/app_text.dart';
import '../core/theme/app_colors.dart';
import 'anime_card.dart';

class HorizontalAnimeList extends StatelessWidget {
  final String title;
  final List<AnimeModel> data;
  final void Function(int animeId) onSelect;
  final void Function(AnimeModel anime) onAdd;
  final bool Function(int animeId) isInList;
  final VoidCallback? onSeeAll;

  const HorizontalAnimeList({
    super.key,
    required this.title,
    required this.data,
    required this.onSelect,
    required this.onAdd,
    required this.isInList,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text(
                    AppText.get('see_all'),
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: data.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final anime = data[index];
              return SizedBox(
                width: 150,
                child: AnimeCard(
                  anime: anime,
                  onTap: () => onSelect(anime.id),
                  onAdd: () => onAdd(anime),
                  isInList: isInList(anime.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
