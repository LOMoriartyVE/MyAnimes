import 'package:flutter/material.dart';
import '../services/hive_service.dart';

/// App color palette derived from the MA_logo.png
/// Logo uses a lavender-blue (#A8B4F0) to mauve-pink (#D4A0D0) gradient.
class AppColors {
  // ── Brand Gradient ──
  static const Color lavender = Color(0xFFA8B4F0);
  static const Color mauve = Color(0xFFD4A0D0);

  static LinearGradient get brandGradient {
    if (!HiveService.isInitialized) {
      return const LinearGradient(
        colors: [lavender, mauve],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    final pack = HiveService.themePack;
    if (pack == 'cyberpunk_neon') {
      return const LinearGradient(
        colors: [Color(0xFF00F0FF), Color(0xFFFF0055)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (pack == 'glassmorphic_dark') {
      return const LinearGradient(
        colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (pack == 'sakura_blossom') {
      return const LinearGradient(
        colors: [Color(0xFFFFB7B2), Color(0xFFFFC6FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (pack == 'midnight_abyss') {
      return const LinearGradient(
        colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (pack == 'retro_forest') {
      return const LinearGradient(
        colors: [Color(0xFF134E5E), Color(0xFF71B280)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [lavender, mauve],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // ── 60-30-10 Rule: Dark Theme ──
  // 60% Dominant Base Canvas (bland, matte, neutral dark)
  static const Color darkBg = Color(0xFF0C0E14);
  // 30% Secondary Structures (surfaces, cards, borders, typography)
  static const Color darkSurface = Color(0xFF141720);
  static const Color darkCard = Color(0xFF1A1E29);
  static const Color darkCardBorder = Color(0xFF262C3D);
  static const Color darkTextPrimary = Color(0xFFEFF1F7);
  static const Color darkTextSecondary = Color(0xFF8E95A5);
  static const Color darkTextHint = Color(0xFF5B6172);
  static const Color darkNavBar = Color(0xFF10121A);

  // ── 60-30-10 Rule: Light Theme ──
  // 60% Dominant Base Canvas (bland, clean, neutral off-white)
  static const Color lightBg = Color(0xFFF7F8FA);
  // 30% Secondary Structures (surfaces, cards, borders, typography)
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE4E7ED);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextHint = Color(0xFF94A3B8);
  static const Color lightNavBar = Color(0xFFFFFFFF);

  // ── 10% Accent (Key CTAs, active states, indicators, focus) ──
  static Color get accent {
    if (!HiveService.isInitialized) return const Color(0xFF7C6AE6);
    final pack = HiveService.themePack;
    if (pack == 'cyberpunk_neon') return const Color(0xFF00F0FF);
    if (pack == 'glassmorphic_dark') return const Color(0xFFB8A8F0);
    if (pack == 'sakura_blossom') return const Color(0xFFFF7B90);
    if (pack == 'midnight_abyss') return const Color(0xFFB026FF);
    if (pack == 'retro_forest') return const Color(0xFF2E7D32);
    return const Color(0xFF7C6AE6);
  }
  static Color get accentLight {
    if (!HiveService.isInitialized) return const Color(0xFF9B8CF0);
    final pack = HiveService.themePack;
    if (pack == 'cyberpunk_neon') return const Color(0xFFFF0055);
    if (pack == 'glassmorphic_dark') return const Color(0xFFD4A0D0);
    if (pack == 'sakura_blossom') return const Color(0xFFFFB7B2);
    if (pack == 'midnight_abyss') return const Color(0xFFE100FF);
    if (pack == 'retro_forest') return const Color(0xFFC0CA33);
    return const Color(0xFF9B8CF0);
  }
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color starYellow = Color(0xFFF59E0B);

  // ── Category Colors ───
  static const Color watching = Color(0xFF60A5FA);      // blue
  static const Color completed = Color(0xFF4ADE80);     // green
  static const Color planned = Color(0xFFA78BFA);       // purple
  static const Color ignored = Color(0xFF9CA3AF);       // gray
}
