import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_list_item.dart';
import '../core/localization/app_text.dart';
import '../core/services/hive_service.dart';
import '../core/services/mal_auth_service.dart';
import '../pages/anime_wrapped_page.dart';

class WrappedShareDialog extends StatefulWidget {
  final int year;
  final int totalEpisodes;
  final int totalHours;
  final double totalDays;
  final int completedCount;
  final double completionRate;
  final String personaTitle;
  final String personaDescription;
  final IconData personaIcon;
  final List<MapEntry<String, int>> topGenres;
  final List<StudioWrappedStat> topStudios;
  final List<AnimeListItem> topRated;

  const WrappedShareDialog({
    super.key,
    required this.year,
    required this.totalEpisodes,
    required this.totalHours,
    required this.totalDays,
    required this.completedCount,
    required this.completionRate,
    required this.personaTitle,
    required this.personaDescription,
    required this.personaIcon,
    required this.topGenres,
    required this.topStudios,
    required this.topRated,
  });

  static void show(
    BuildContext context, {
    required int year,
    required int totalEpisodes,
    required int totalHours,
    required double totalDays,
    required int completedCount,
    required double completionRate,
    required String personaTitle,
    required String personaDescription,
    required IconData personaIcon,
    required List<MapEntry<String, int>> topGenres,
    required List<StudioWrappedStat> topStudios,
    required List<AnimeListItem> topRated,
  }) {
    showDialog(
      context: context,
      builder: (_) => WrappedShareDialog(
        year: year,
        totalEpisodes: totalEpisodes,
        totalHours: totalHours,
        totalDays: totalDays,
        completedCount: completedCount,
        completionRate: completionRate,
        personaTitle: personaTitle,
        personaDescription: personaDescription,
        personaIcon: personaIcon,
        topGenres: topGenres,
        topStudios: topStudios,
        topRated: topRated,
      ),
    );
  }

  @override
  State<WrappedShareDialog> createState() => _WrappedShareDialogState();
}

class _WrappedShareDialogState extends State<WrappedShareDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isProcessing = false;

  Future<Uint8List?> _capturePng() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Capture PNG failed: $e");
      return null;
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) throw Exception("Capture failed");

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/anime_wrapped_${widget.year}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '✨ My Anime Wrapped ${widget.year} ✨\nTracked with MyAnimes',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppText.isArabic ? "فشلت المشاركة: $e" : "Share failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _downloadImage() async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) throw Exception("Capture failed");

      if (Platform.isWindows) {
        final outputFile = await FilePicker.platform.saveFile(
          dialogTitle: AppText.isArabic ? 'حفظ بطاقة ملخص الأنمي' : 'Save Anime Wrapped Story Card',
          fileName: 'anime_wrapped_${widget.year}.png',
          type: FileType.custom,
          allowedExtensions: ['png'],
        );
        if (outputFile == null) return; // User cancelled
        String savePath = outputFile;
        if (!savePath.toLowerCase().endsWith('.png')) {
          savePath = '$savePath.png';
        }
        await File(savePath).writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppText.isArabic ? "تم حفظ الصورة بنجاح!" : "Image saved successfully!"),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: AppText.isArabic ? "فتح المجلد" : "Open Folder",
                textColor: Colors.white,
                onPressed: () {
                  final dir = File(savePath).parent.path;
                  Process.run('explorer.exe', [dir]);
                },
              ),
            ),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/anime_wrapped_${widget.year}.png');
      await file.writeAsBytes(bytes);

      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }

      if (hasAccess) {
        await Gal.putImage(file.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppText.isArabic ? "تم حفظ الصورة في المعرض!" : "Image saved to gallery!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Storage access denied");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppText.isArabic ? "فشل التنزيل: $e" : "Download failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = AppText.isArabic;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Captured Repaint Boundary Card ──
              RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  width: 340,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0E14),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.accent.withAlpha(120), width: 1.5),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF161926),
                        Color(0xFF0C0E14),
                        Color(0xFF121522),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent.withOpacity(0.35),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset('assets/MA_logo.png', fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'MY ANIMES',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                            ),
                            child: Text(
                              'WRAPPED ${widget.year}',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Profile Image & Persona Emblem
                      Builder(builder: (context) {
                        final malPic = HiveService.malUserPicture;
                        final malUsername = HiveService.malUsername;
                        final hasPic = (malPic != null && malPic.trim().isNotEmpty);

                        return Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.accent.withOpacity(0.4),
                                        Colors.transparent,
                                      ],
                                    ),
                                    border: Border.all(color: AppColors.accent, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent.withOpacity(0.35),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: hasPic
                                        ? CachedNetworkImage(
                                            imageUrl: malPic!,
                                            width: 76,
                                            height: 76,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(color: Colors.white10),
                                            errorWidget: (_, __, ___) => Icon(widget.personaIcon, size: 38, color: Colors.white),
                                          )
                                        : Icon(widget.personaIcon, size: 38, color: Colors.white),
                                  ),
                                ),
                                if (hasPic)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppColors.brandGradient,
                                        border: Border.all(color: const Color(0xFF0C0E14), width: 2),
                                      ),
                                      child: Icon(widget.personaIcon, size: 13, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (malUsername != null && malUsername.trim().isNotEmpty) ...[
                              Text(
                                malUsername,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            Text(
                              widget.personaTitle.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '"${widget.personaDescription}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            height: 1.3,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Stats 2x2 Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildShareStatTile(
                              icon: Icons.play_circle_filled_rounded,
                              color: AppColors.watching,
                              title: '${widget.totalEpisodes} eps',
                              subtitle: '${widget.totalHours}h / ${widget.totalDays.toStringAsFixed(0)}d',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildShareStatTile(
                              icon: Icons.check_circle_rounded,
                              color: AppColors.completed,
                              title: '${widget.completedCount} shows',
                              subtitle: '${widget.completionRate.toStringAsFixed(0)}% finish rate',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildShareStatTile(
                              icon: Icons.category_rounded,
                              color: AppColors.planned,
                              title: widget.topGenres.isNotEmpty ? widget.topGenres.first.key : 'Anime',
                              subtitle: 'Top Genre',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildShareStatTile(
                              icon: Icons.home_work_rounded,
                              color: AppColors.starYellow,
                              title: widget.topStudios.isNotEmpty ? widget.topStudios.first.name : 'Studio',
                              subtitle: widget.topStudios.isNotEmpty
                                  ? (widget.topStudios.first.titlesInYearCount > 0
                                      ? '${widget.topStudios.first.titlesInYearCount} in ${widget.year}'
                                      : '${widget.topStudios.first.totalTitlesCount} in collection')
                                  : 'Top Studio',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Top 5 Genres Bars
                      if (widget.topGenres.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.07)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOP 5 GENRES',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...widget.topGenres.take(5).toList().asMap().entries.map((entry) {
                                final idx = entry.key;
                                final g = entry.value;
                                final maxCount = widget.topGenres.first.value;
                                final ratio = maxCount > 0 ? (g.value / maxCount).clamp(0.08, 1.0) : 0.0;
                                final colors = [
                                  AppColors.accent,
                                  AppColors.watching,
                                  AppColors.mauve,
                                  AppColors.completed,
                                  AppColors.starYellow,
                                ];
                                final barColor = colors[idx % colors.length];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '#${idx + 1}  ${g.key}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${g.value} shows',
                                            style: TextStyle(
                                              color: barColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: ratio,
                                          minHeight: 4.5,
                                          backgroundColor: Colors.white10,
                                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Highest Rated Highlights
                      if (widget.topRated.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.07)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOP RATED PICKS',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...widget.topRated.take(3).map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 12, color: AppColors.starYellow),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      item.userRating?.overall.toStringAsFixed(1) ?? '',
                                      style: const TextStyle(
                                        color: AppColors.starYellow,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],



                      // Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.accent.withOpacity(0.8)),
                          const SizedBox(width: 5),
                          Text(
                            'Tracked with MyAnimes Vault',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Action Buttons Container ──
              Container(
                width: 340,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                child: Column(
                  children: [
                    if (_isProcessing)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10.0),
                        child: CircularProgressIndicator(),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _shareImage,
                            icon: const Icon(Icons.share_rounded, size: 17),
                            label: Text(isAr ? "مشاركة" : "Share"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isProcessing ? null : _downloadImage,
                            icon: const Icon(Icons.download_rounded, size: 17),
                            label: Text(isAr ? "تنزيل" : "Download"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black87,
                              side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        isAr ? "إغلاق" : "Close",
                        style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareStatTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
