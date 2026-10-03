import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_colors.dart';

/// Shimmer placeholder widgets for loading states.
class ShimmerLoading {
  static Widget _buildSingleRawCard({
    required BuildContext context,
    required bool isDark,
    double? width,
    double? height,
  }) {
    final baseColor = isDark ? const Color(0xFF1E2230) : const Color(0xFFE0E0EA);
    final blockColor = isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF0F0F8);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: baseColor,
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mock Poster
          Expanded(
            child: Container(
              color: blockColor,
            ),
          ),
          // Mock Info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Line 1
                Container(
                  height: 12,
                  width: 105,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                // Title Line 2
                Container(
                  height: 12,
                  width: 75,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                // Genre
                Container(
                  height: 9,
                  width: 45,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget cardGrid({int count = 6, required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E2230) : const Color(0xFFE0E0EA);
    final highlightColor = isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF0F0F8);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          return _buildSingleRawCard(context: context, isDark: isDark);
        },
      ),
    );
  }

  static Widget horizontalList({required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E2230) : const Color(0xFFE0E0EA);
    final highlightColor = isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF0F0F8);

    return SizedBox(
      height: 220,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return SizedBox(
              width: 130,
              child: _buildSingleRawCard(context: context, isDark: isDark),
            );
          },
        ),
      ),
    );
  }

  static Widget heroBanner({required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E2230) : const Color(0xFFE0E0EA);
    final highlightColor = isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF0F0F8);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: 400,
        width: double.infinity,
        color: baseColor,
      ),
    );
  }

  static Widget card({
    required BuildContext context,
    double? width,
    double? height,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E2230) : const Color(0xFFE0E0EA);
    final highlightColor = isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF0F0F8);

    return LayoutBuilder(
      builder: (context, constraints) {
        double? effectiveWidth = width;
        double? effectiveHeight = height;

        // If height is unconstrained (e.g. inside SingleChildScrollView, Column, ListView),
        // we MUST supply a bounded height so the internal Expanded widget doesn't crash during layout/paint.
        if (effectiveHeight == null) {
          if (!constraints.hasBoundedHeight || constraints.maxHeight == double.infinity) {
            effectiveWidth ??= (constraints.hasBoundedWidth && constraints.maxWidth.isFinite)
                ? constraints.maxWidth.clamp(90.0, 160.0)
                : 140.0;
            effectiveHeight = effectiveWidth * 1.5;
          } else {
            effectiveHeight = constraints.maxHeight;
          }
        }

        if (effectiveWidth == null && constraints.hasBoundedWidth && constraints.maxWidth.isFinite) {
          effectiveWidth = constraints.maxWidth;
        }

        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: _buildSingleRawCard(
            context: context,
            isDark: isDark,
            width: effectiveWidth,
            height: effectiveHeight,
          ),
        );
      },
    );
  }

  static Widget detailPage({
    required BuildContext context,
    VoidCallback? onBack,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 850;

    final baseColor = isDark ? const Color(0xFF1E2230) : const Color(0xFFE2E4EC);
    final highlightColor = isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF2F3F8);
    final cardBg = isDark ? const Color(0xFF1E2230) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;
    final blockColor = isDark ? const Color(0xFF262A38) : const Color(0xFFEBEDF5);
    final innerCardBg = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cover Banner Card Skeleton
              _buildCoverBannerSkeleton(
                isDesktop: isDesktop,
                isDark: isDark,
                cardBg: cardBg,
                cardBorder: cardBorder,
                baseColor: baseColor,
                highlightColor: highlightColor,
                blockColor: blockColor,
                onBack: onBack,
              ),

              // 2. Main content: Desktop (Sidebar + Tabs/Overview) vs Mobile
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 320,
                      child: _buildSidebarSkeleton(
                        isDark: isDark,
                        cardBg: innerCardBg,
                        cardBorder: cardBorder,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        blockColor: blockColor,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTabSelectorSkeleton(
                            isDark: isDark,
                            cardBg: innerCardBg,
                            cardBorder: cardBorder,
                            baseColor: baseColor,
                            highlightColor: highlightColor,
                            blockColor: blockColor,
                          ),
                          const SizedBox(height: 20),
                          _buildSynopsisSkeleton(
                            isDark: isDark,
                            cardBg: innerCardBg,
                            cardBorder: cardBorder,
                            baseColor: baseColor,
                            highlightColor: highlightColor,
                            blockColor: blockColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTabSelectorSkeleton(
                      isDark: isDark,
                      cardBg: innerCardBg,
                      cardBorder: cardBorder,
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      blockColor: blockColor,
                    ),
                    const SizedBox(height: 20),
                    _buildSynopsisSkeleton(
                      isDark: isDark,
                      cardBg: innerCardBg,
                      cardBorder: cardBorder,
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      blockColor: blockColor,
                    ),
                    const SizedBox(height: 24),
                    _buildSidebarSkeleton(
                      isDark: isDark,
                      cardBg: innerCardBg,
                      cardBorder: cardBorder,
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      blockColor: blockColor,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildCoverBannerSkeleton({
    required bool isDesktop,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color baseColor,
    required Color highlightColor,
    required Color blockColor,
    VoidCallback? onBack,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: isDesktop ? 32 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top action row
            Row(
              children: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                  onPressed: onBack,
                ),
                const Spacer(),
                _buildShimmerCircle(baseColor, highlightColor, blockColor),
                const SizedBox(width: 8),
                _buildShimmerCircle(baseColor, highlightColor, blockColor),
                const SizedBox(width: 8),
                _buildShimmerCircle(baseColor, highlightColor, blockColor),
              ],
            ),
            const SizedBox(height: 24),

            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildPosterSkeleton(baseColor, highlightColor),
                  const SizedBox(width: 32),
                  Expanded(
                    child: _buildBannerDetailsSkeleton(
                      isDesktop: true,
                      isDark: isDark,
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      blockColor: blockColor,
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildPosterSkeleton(baseColor, highlightColor),
                  const SizedBox(height: 24),
                  _buildBannerDetailsSkeleton(
                    isDesktop: false,
                    isDark: isDark,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    blockColor: blockColor,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static Widget _buildShimmerCircle(Color baseColor, Color highlightColor, Color blockColor) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: blockColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  static Widget _buildPosterSkeleton(Color baseColor, Color highlightColor) {
    return Container(
      width: 190,
      height: 270,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            width: 190,
            height: 270,
            color: baseColor,
          ),
        ),
      ),
    );
  }

  static Widget _buildBannerDetailsSkeleton({
    required bool isDesktop,
    required bool isDark,
    required Color baseColor,
    required Color highlightColor,
    required Color blockColor,
  }) {
    final align = isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badges row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 24,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 88,
                height: 24,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title line 1
          Container(
            height: isDesktop ? 28 : 22,
            width: isDesktop ? 380 : 250,
            decoration: BoxDecoration(
              color: blockColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),

          // Title line 2
          Container(
            height: isDesktop ? 22 : 18,
            width: isDesktop ? 240 : 170,
            decoration: BoxDecoration(
              color: blockColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 16),

          // MAL Score / Rank / Popularity / Members metric container
          Container(
            constraints: const BoxConstraints(maxWidth: 550),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: blockColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(4, (index) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 9,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF383D50) : const Color(0xFFD6D9E6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 32,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF383D50) : const Color(0xFFD6D9E6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              )),
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 130,
                height: 44,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Container(
                width: 56,
                height: 44,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Container(
                width: 110,
                height: 44,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildTabSelectorSkeleton({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color baseColor,
    required Color highlightColor,
    required Color blockColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.all(6),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              // Active tab mock
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  width: 60,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF383D50) : const Color(0xFFD6D9E6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ...List.generate(5, (i) {
                final widths = [110.0, 85.0, 95.0, 100.0, 115.0];
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Container(
                      width: widths[i % widths.length],
                      height: 14,
                      decoration: BoxDecoration(
                        color: blockColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSynopsisSkeleton({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color baseColor,
    required Color highlightColor,
    required Color blockColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 140,
                  height: 14,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            FractionallySizedBox(
              widthFactor: 0.65,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSidebarSkeleton({
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color baseColor,
    required Color highlightColor,
    required Color blockColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 12,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(6, (index) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 55,
                        height: 12,
                        decoration: BoxDecoration(
                          color: blockColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 75 + (index % 3) * 15.0,
                        height: 12,
                        decoration: BoxDecoration(
                          color: blockColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < 5)
                  Container(
                    height: 1,
                    color: blockColor,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
              ],
            )),
          ],
        ),
      ),
    );
  }
}

