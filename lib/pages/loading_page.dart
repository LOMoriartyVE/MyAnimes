import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/app_text.dart';

/// A sleek, lightweight, high-performance loading page adhering to the
/// 60-30-10 rule (clean neutral background, balanced typography, focused accent indicator).
class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.03).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = AppText.isArabic;

    // 60-30-10 Color Theory:
    // 60% Dominant: Background canvas
    // 30% Secondary: Containers, typography, subtle borders
    // 10% Accent: Progress indicator, active glow
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 30% Ambient Subtle Neutral Glow
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(isDark ? 0.08 : 0.04),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),

          // Central Brand Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brand Logo with Subtle Pulse
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.18),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/MA_logo.png',
                        width: 108,
                        height: 108,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                              ),
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 64,
                              color: AppColors.accent,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Clean Brand Typography
                Text(
                  'My Animes',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  isAr ? 'عالم الأنمي بين يديك' : 'Your Personal Anime World',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: textSecondary,
                  ),
                ),

                const SizedBox(height: 36),

                // 10% Accent: Slim Modern Progress Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 72),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.06),
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  isAr ? 'جاري التحميل...' : 'Loading...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondary.withOpacity(0.7),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
