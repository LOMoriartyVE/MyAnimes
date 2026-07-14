import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../core/models/anime_list_item.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/localization/app_text.dart';
import 'video_player_screen.dart';

class LocalEpisodeFile {
  final File file;
  final String name;
  final int? episodeNumber;

  LocalEpisodeFile({
    required this.file,
    required this.name,
    this.episodeNumber,
  });
}

class QuickTrackerCard extends StatefulWidget {
  final AnimeListItem item;
  final void Function(int animeId) onSelectAnime;
  final VoidCallback onStateChanged;

  const QuickTrackerCard({
    super.key,
    required this.item,
    required this.onSelectAnime,
    required this.onStateChanged,
  });

  @override
  State<QuickTrackerCard> createState() => _QuickTrackerCardState();
}

class _QuickTrackerCardState extends State<QuickTrackerCard> {
  List<LocalEpisodeFile> _unwatchedFiles = [];
  bool _loadingFiles = true;

  @override
  void initState() {
    super.initState();
    _loadLocalFiles();
  }

  @override
  void didUpdateWidget(covariant QuickTrackerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.episodeProgress != widget.item.episodeProgress ||
        oldWidget.item.title != widget.item.title) {
      _loadLocalFiles();
    }
  }

  Future<void> _loadLocalFiles() async {
    if (!mounted) return;
    setState(() => _loadingFiles = true);
    try {
      final rootPath = HiveService.localAnimeFolder;
      if (rootPath == null) {
        if (mounted) setState(() { _unwatchedFiles = []; _loadingFiles = false; });
        return;
      }
      final cleanTitle = widget.item.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
      final watchingDirPath = '$rootPath${Platform.pathSeparator}Watching Animes';
      final animeDir = Directory('$watchingDirPath${Platform.pathSeparator}$cleanTitle');
      
      if (await animeDir.exists()) {
        final entities = await animeDir.list().toList();
        final videoFiles = entities.whereType<File>().where((f) {
          final p = f.path.toLowerCase();
          return p.endsWith('.mp4') || p.endsWith('.mkv') || p.endsWith('.avi') || p.endsWith('.webm');
        }).toList();

        final parsedFiles = videoFiles.map((f) {
          final name = f.path.split(Platform.pathSeparator).last;
          final epNum = _parseEpisodeNumber(name);
          return LocalEpisodeFile(file: f, name: name, episodeNumber: epNum);
        }).toList();

        // Sort by episode number (nulls last)
        parsedFiles.sort((a, b) {
          if (a.episodeNumber != null && b.episodeNumber != null) {
            return a.episodeNumber!.compareTo(b.episodeNumber!);
          }
          if (a.episodeNumber != null) return -1;
          if (b.episodeNumber != null) return 1;
          return a.name.compareTo(b.name);
        });

        // Filter only those episodes that are unwatched (epNum > widget.item.episodeProgress)
        final unwatched = parsedFiles.where((f) {
          if (f.episodeNumber == null) return true; // Show unparsed files anyway
          return f.episodeNumber! > widget.item.episodeProgress;
        }).toList();

        if (mounted) {
          setState(() {
            _unwatchedFiles = unwatched;
            _loadingFiles = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _unwatchedFiles = [];
            _loadingFiles = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading quick tracker files: $e');
      if (mounted) {
        setState(() {
          _unwatchedFiles = [];
          _loadingFiles = false;
        });
      }
    }
  }

  int? _parseEpisodeNumber(String fileName) {
    final lower = fileName.toLowerCase();
    
    final regexes = [
      RegExp(r'(?:episode|ep|e)\s*#?(\d+)', caseSensitive: false),
      RegExp(r'\b(\d+)\s*(?:v\d+)?\s*(?:[fF][hH][dD]|[hH][dD])?\.(?:mp4|mkv|avi|webm)\b'),
      RegExp(r'-\s*(\d+)\b'),
      RegExp(r'\[(\d+)\]'),
    ];

    for (final regex in regexes) {
      final match = regex.firstMatch(lower);
      if (match != null && match.groupCount >= 1) {
        final val = match.group(1);
        if (val != null) {
          final parsed = int.tryParse(val);
          if (parsed != null) return parsed;
        }
      }
    }
    
    final dotIndex = fileName.lastIndexOf('.');
    final nameWithoutExt = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;
    final allMatches = RegExp(r'\d+').allMatches(nameWithoutExt).toList();
    if (allMatches.isNotEmpty) {
      for (int i = allMatches.length - 1; i >= 0; i--) {
        final numStr = allMatches[i].group(0)!;
        if (numStr != '1080' && numStr != '720' && numStr != '480' && numStr != '2160') {
          final parsed = int.tryParse(numStr);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalEp = int.tryParse(widget.item.episodes) ?? 0;
    final progress = widget.item.episodeProgress;
    final percent = totalEp > 0 ? progress / totalEp : 0.0;

    return Container(
      width: 295,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Poster
          GestureDetector(
            onTap: () => widget.onSelectAnime(widget.item.animeId),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: widget.item.image,
                width: 70,
                height: 105,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 70,
                  height: 105,
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                ),
                errorListener: (_) {},
                errorWidget: (_, __, ___) => Container(
                  width: 70,
                  height: 105,
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => widget.onSelectAnime(widget.item.animeId),
                  child: Text(
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Episode $progress / ${totalEp > 0 ? totalEp.toString() : "?"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent > 0.0 ? percent : null,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    color: AppColors.accent,
                    minHeight: 4,
                  ),
                ),
                if (!_loadingFiles && _unwatchedFiles.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ..._unwatchedFiles.take(2).map((f) {
                        final displayLabel = f.episodeNumber != null ? 'Ep ${f.episodeNumber}' : 'Play';
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoPlayerScreen(
                                  videoPath: f.file.path,
                                  videoTitle: f.name,
                                  relatedAnime: widget.item,
                                ),
                              ),
                            ).then((_) => widget.onStateChanged());
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withAlpha(isDark ? 50 : 30),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.accent.withAlpha(100), width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded, size: 10, color: AppColors.accent),
                                const SizedBox(width: 1),
                                Text(
                                  displayLabel,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      if (_unwatchedFiles.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(left: 2, top: 4),
                          child: Text(
                            '+${_unwatchedFiles.length - 2}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Quick +1 button
          GestureDetector(
            onTap: () async {
              final next = progress + 1;
              if (totalEp > 0 && next > totalEp) return;
              
              if (totalEp > 0 && next == totalEp) {
                await HiveService.updateEpisodeProgress(widget.item.animeId, next);
                if (context.mounted) {
                  final res = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      title: Text(AppText.get('completed')),
                      content: const Text(
                          "You've reached the final episode! Move this anime to Completed?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Keep"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Move"),
                        ),
                      ],
                    ),
                  );
                  if (res == true) {
                    await HiveService.updateCategory(widget.item.animeId, AnimeCategory.completed);
                  }
                }
              } else {
                await HiveService.updateEpisodeProgress(widget.item.animeId, next);
              }
              widget.onStateChanged();
            },
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
