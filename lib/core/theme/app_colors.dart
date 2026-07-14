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

  // ── Dark Theme ──
  static const Color darkBg = Color(0xFF0F1117);
  static const Color darkSurface = Color(0xFF1A1D27);
  static const Color darkCard = Color(0xFF1E2230);
  static const Color darkCardBorder = Color(0xFF2A2E3D);
  static const Color darkTextPrimary = Color(0xFFE8E9ED);
  static const Color darkTextSecondary = Color(0xFF8B8FA3);
  static const Color darkTextHint = Color(0xFF5A5E72);
  static const Color darkNavBar = Color(0xFF12141C);

  // ── Light Theme ──
  static const Color lightBg = Color(0xFFF5F5FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF0F0F8);
  static const Color lightCardBorder = Color(0xFFE0E0EA);
  static const Color lightTextPrimary = Color(0xFF1A1D27);
  static const Color lightTextSecondary = Color(0xFF6B6F83);
  static const Color lightTextHint = Color(0xFF9A9EB2);
  static const Color lightNavBar = Color(0xFFFFFFFF);

  // ── Accent / Semantic ──
  static Color get accent {
    if (!HiveService.isInitialized) return const Color(0xFF9B8CF0);
    final pack = HiveService.themePack;
    if (pack == 'cyberpunk_neon') return const Color(0xFF00F0FF);
    if (pack == 'glassmorphic_dark') return const Color(0xFFB8A8F0);
    if (pack == 'sakura_blossom') return const Color(0xFFFF7B90);
    if (pack == 'midnight_abyss') return const Color(0xFFB026FF);
    if (pack == 'retro_forest') return const Color(0xFF2E7D32);
    return const Color(0xFF9B8CF0);
  }
  static Color get accentLight {
    if (!HiveService.isInitialized) return const Color(0xFFB8A8F0);
    final pack = HiveService.themePack;
    if (pack == 'cyberpunk_neon') return const Color(0xFFFF0055);
    if (pack == 'glassmorphic_dark') return const Color(0xFFD4A0D0);
    if (pack == 'sakura_blossom') return const Color(0xFFFFB7B2);
    if (pack == 'midnight_abyss') return const Color(0xFFE100FF);
    if (pack == 'retro_forest') return const Color(0xFFC0CA33);
    return const Color(0xFFB8A8F0);
  }
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);
  static const Color starYellow = Color(0xFFFBBF24);

  // ── Category Colors ───
  static const Color watching = Color(0xFF60A5FA);      // blue
  static const Color completed = Color(0xFF4ADE80);     // green
  static const Color planned = Color(0xFFA78BFA);       // purple
  static const Color ignored = Color(0xFF9CA3AF);       // gray
}
