import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer placeholder widgets for loading states.
class ShimmerLoading {
  static Widget _buildSingleRawCard({required BuildContext context, required bool isDark}) {
    final baseColor = isDark ? const Color(0xFF1E2230) : const Color(0xFFE0E0EA);
    final blockColor = isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF0F0F8);

    return Container(
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
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                // Title Line 2
                Container(
                  height: 12,
                  width: 90,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                // Genre
                Container(
                  height: 9,
                  width: 50,
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

  static Widget card({required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E2230) : const Color(0xFFE0E0EA);
    final highlightColor = isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF0F0F8);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: _buildSingleRawCard(context: context, isDark: isDark),
    );
  }

  static Widget detailPage({required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E2230) : const Color(0xFFE0E0EA);
    final highlightColor = isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF0F0F8);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: [
          Container(height: 300, width: double.infinity, color: baseColor),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 28, width: 250, color: baseColor),
                const SizedBox(height: 12),
                Container(height: 16, width: 180, color: baseColor),
                const SizedBox(height: 24),
                Container(height: 80, width: double.infinity, color: baseColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
