import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_model.dart';

class AnimeCard extends StatelessWidget {
  final AnimeModel anime;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final bool isInList;

  const AnimeCard({
    super.key,
    required this.anime,
    required this.onTap,
    this.onAdd,
    this.isInList = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).cardTheme.color,
          border: Border.all(
            color: Theme.of(context).dividerColor.withAlpha(40),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Poster ──
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: anime.image,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.darkCard,
                      child: const Center(
                        child: Icon(Icons.movie_outlined, size: 32, color: AppColors.darkTextHint),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.darkCard,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, size: 32, color: AppColors.darkTextHint),
                      ),
                    ),
                  ),

                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withAlpha(180)],
                        ),
                      ),
                    ),
                  ),

                  // Score badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withAlpha(25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: AppColors.starYellow),
                          const SizedBox(width: 3),
                          Text(
                            anime.scoreDisplay,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Add button
                  if (onAdd != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isInList
                                ? AppColors.success.withAlpha(200)
                                : Colors.black.withAlpha(120),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(25)),
                          ),
                          child: Icon(
                            isInList ? Icons.check : Icons.add,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Info ──
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    anime.genres.take(2).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
