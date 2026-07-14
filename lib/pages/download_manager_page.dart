import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/services/download_manager.dart';
import '../widgets/video_player_screen.dart';
import '../core/models/anime_list_item.dart';

class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _playVideo(DownloadTask task) {
    if (!File(task.savePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File does not exist or was deleted manually.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Try to find the related anime item to sync watch progression!
    AnimeListItem? relatedAnime;
    final allList = HiveService.getAllListItems();
    for (final item in allList) {
      if (task.title.toLowerCase().contains(item.title.toLowerCase()) ||
          item.title.toLowerCase().contains(task.title.toLowerCase())) {
        relatedAnime = item;
        break;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoPath: task.savePath,
          videoTitle: task.fileName,
          relatedAnime: relatedAnime,
        ),
      ),
    );
  }

  Widget _buildTabSwitcher(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(0, 'Downloading', Icons.downloading_rounded, isDark),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(1, 'Downloaded', Icons.download_done_rounded, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, bool isDark) {
    final active = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Download Manager',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link_rounded),
            tooltip: 'Add Download Link',
            onPressed: () => _showAddDownloadDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildTabSwitcher(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveTasksList(isDark),
                _buildCompletedTasksList(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTasksList(bool isDark) {
    return ValueListenableBuilder<List<DownloadTask>>(
      valueListenable: DownloadManager.instance.tasksNotifier,
      builder: (context, activeTasks, _) {
        if (activeTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_done_rounded, size: 64, color: isDark ? Colors.white30 : Colors.black26),
                const SizedBox(height: 16),
                Text(
                  'No active downloads',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start downloads on WitAnime to see them here.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeTasks.length,
          itemBuilder: (context, index) {
            final task = activeTasks[index];
            return _buildActiveTaskItem(task, isDark);
          },
        );
      },
    );
  }

  Widget _buildCompletedTasksList(bool isDark) {
    return ValueListenableBuilder<List<DownloadTask>>(
      valueListenable: DownloadManager.instance.completedTasksNotifier,
      builder: (context, completedTasks, _) {
        if (completedTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_outlined, size: 64, color: isDark ? Colors.white30 : Colors.black26),
                const SizedBox(height: 16),
                Text(
                  'No completed downloads',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completedTasks.length,
          itemBuilder: (context, index) {
            // Display in reverse order (newest completed first)
            final task = completedTasks[completedTasks.length - 1 - index];
            return _buildCompletedTaskItem(task, isDark);
          },
        );
      },
    );
  }

  Widget _buildActiveTaskItem(DownloadTask task, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Thumbnail
            _buildThumbnail(task.imageUrl, isDark),
            const SizedBox(width: 14),

            // Content details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (task.status == DownloadStatus.downloading && task.progress < 0) ? null : task.progress,
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                      color: _getStatusColor(task.status),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          task.status == DownloadStatus.failed
                              ? 'Failed: ${task.error ?? "Unknown error"}'
                              : (task.status == DownloadStatus.downloading
                                  ? '${task.speed}  •  ${task.fileSize}'
                                  : _getStatusText(task.status)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12, 
                            color: task.status == DownloadStatus.failed 
                                ? Colors.redAccent 
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        task.progress < 0 
                            ? '...' 
                            : '${(task.progress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Controls
            Column(
              children: [
                if (task.status == DownloadStatus.downloading)
                  IconButton(
                    icon: const Icon(Icons.pause_circle_filled_rounded, color: Colors.amber, size: 28),
                    onPressed: () => DownloadManager.instance.pauseDownload(task.id),
                  )
                else if (task.status == DownloadStatus.paused || task.status == DownloadStatus.failed)
                  IconButton(
                    icon: const Icon(Icons.play_circle_filled_rounded, color: Colors.green, size: 28),
                    onPressed: () => DownloadManager.instance.resumeDownload(task.id),
                  ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 22),
                  onPressed: () => DownloadManager.instance.cancelDownload(task.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTaskItem(DownloadTask task, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _playVideo(task),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Thumbnail
              _buildThumbnail(task.imageUrl, isDark),
              const SizedBox(width: 14),

              // Content details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Downloaded  •  ${task.fileSize}',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Play / Delete Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.play_circle_fill, color: AppColors.accent, size: 30),
                    onPressed: () => _playVideo(task),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                          title: const Text('Delete Downloaded Video?'),
                          content: Text('Are you sure you want to delete "${task.fileName}" and remove it from history? This cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () {
                                Navigator.pop(context);
                                DownloadManager.instance.deleteCompleted(task.id);
                              },
                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? imageUrl, bool isDark) {
    return Container(
      width: 50,
      height: 70,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Icon(Icons.movie, size: 24),
            )
          : const Icon(Icons.movie, size: 24),
    );
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return AppColors.accent;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.paused:
        return Colors.amber;
      case DownloadStatus.failed:
        return Colors.red;
    }
  }

  String _getStatusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.completed:
        return 'Finished';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.failed:
        return 'Failed';
    }
  }

  void _showAddDownloadDialog(BuildContext context) {
    final urlController = TextEditingController();
    final titleController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          title: const Text('Add Download URL', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Download URL',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Anime/File Title (Optional)',
                  hintText: 'e.g. One Piece Episode 1100',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final url = urlController.text.trim();
                final title = titleController.text.trim();
                if (url.isNotEmpty) {
                  final finalTitle = title.isNotEmpty ? title : 'Custom Download';
                  DownloadManager.instance.startDownload(url, finalTitle);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Started downloading: $finalTitle')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid URL'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Download'),
            ),
          ],
        );
      },
    );
  }
}
