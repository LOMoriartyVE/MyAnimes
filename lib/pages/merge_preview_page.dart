import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_list_item.dart';
import '../core/services/hive_service.dart';
import '../core/services/mal_auth_service.dart';

class MergePreviewPage extends StatefulWidget {
  const MergePreviewPage({super.key});

  @override
  State<MergePreviewPage> createState() => _MergePreviewPageState();
}

class LocalMergeItem {
  final AnimeListItem localItem;
  LocalMergeItem(this.localItem);
}

class MalMergeItem {
  final Map<String, dynamic> malItem;
  MalMergeItem(this.malItem);
}

class ConflictMergeItem {
  final AnimeListItem localItem;
  final Map<String, dynamic> malItem;
  final String action; // 'upload' or 'download'
  final String description;

  ConflictMergeItem({
    required this.localItem,
    required this.malItem,
    required this.action,
    required this.description,
  });
}

class _MergePreviewPageState extends State<MergePreviewPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _loadingMessage = "Fetching and comparing list data...";
  String? _error;

  List<LocalMergeItem> _uploads = [];
  List<MalMergeItem> _downloads = [];
  List<ConflictMergeItem> _conflicts = [];

  final Set<int> _selectedUploadIds = {};
  final Set<int> _selectedDownloadIds = {};
  final Set<int> _selectedConflictIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAndCompare();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAndCompare() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final localList = HiveService.getAllListItems();
      final animeList = await MalAuthService.instance.getUserAnimeList();
      final mangaList = await MalAuthService.instance.getUserMangaList();

      final Map<int, Map<String, dynamic>> malMap = {};

      for (final item in animeList) {
        final node = item['node'] as Map<String, dynamic>?;
        if (node == null) continue;
        final int id = node['id'] ?? 0;
        if (id == 0) continue;
        final status = item['list_status'] as Map<String, dynamic>?;
        malMap[id] = {
          'id': id,
          'title': node['title'] ?? 'Unknown',
          'image': node['main_picture']?['large'] ?? node['main_picture']?['medium'] ?? '',
          'episodes': node['num_episodes']?.toString() ?? '?',
          'progress': status?['num_episodes_watched'] ?? 0,
          'status': status?['status'] as String? ?? 'plan_to_watch',
          'score': (status?['score'] as num?)?.toDouble() ?? 0.0,
          'type': node['media_type']?.toString().toUpperCase() ?? 'TV',
          'genres': (node['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? [],
          'studios': (node['studios'] as List?)?.map((s) => s['name'] as String).toList() ?? [],
          'year': node['start_season']?['year']?.toString(),
        };
      }

      for (final item in mangaList) {
        final node = item['node'] as Map<String, dynamic>?;
        if (node == null) continue;
        final int id = node['id'] ?? 0;
        if (id == 0) continue;
        final status = item['list_status'] as Map<String, dynamic>?;
        malMap[id] = {
          'id': id,
          'title': node['title'] ?? 'Unknown',
          'image': node['main_picture']?['large'] ?? node['main_picture']?['medium'] ?? '',
          'episodes': node['num_chapters']?.toString() ?? '?',
          'progress': status?['num_chapters_read'] ?? 0,
          'status': status?['status'] as String? ?? 'plan_to_read',
          'score': (status?['score'] as num?)?.toDouble() ?? 0.0,
          'type': 'MANGA',
          'genres': (node['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? [],
          'year': node['start_season']?['year']?.toString(),
        };
      }

      final localMap = {for (var item in localList) item.animeId: item};

      final uploadsList = <LocalMergeItem>[];
      final downloadsList = <MalMergeItem>[];
      final conflictsList = <ConflictMergeItem>[];

      for (final local in localList) {
        final mal = malMap[local.animeId];
        if (mal == null) {
          uploadsList.add(LocalMergeItem(local));
        } else {
          bool progressDiff = local.episodeProgress != mal['progress'];
          bool scoreDiff = (local.userRating?.overall.round() ?? 0) != (mal['score'] as double).round();

          String localMalStatus = 'plan_to_watch';
          if (local.category == AnimeCategory.watching) localMalStatus = 'watching';
          else if (local.category == AnimeCategory.completed) localMalStatus = 'completed';
          else if (local.category == AnimeCategory.planned) localMalStatus = 'plan_to_watch';
          else if (local.category == AnimeCategory.ignored) localMalStatus = 'dropped';

          String malStatus = mal['status'];
          if (malStatus == 'on_hold') malStatus = 'watching';
          bool statusDiff = localMalStatus != malStatus && !(localMalStatus == 'plan_to_watch' && malStatus == 'plan_to_read');

          if (progressDiff || scoreDiff || statusDiff || local.isMalSynced != true) {
            String action = 'upload';
            String desc = '';
            if (local.episodeProgress > mal['progress']) {
              action = 'upload';
              desc = 'Local is ahead (${local.episodeProgress} eps) vs MAL (${mal['progress']} eps).';
            } else if (local.episodeProgress < mal['progress']) {
              action = 'download';
              desc = 'MAL is ahead (${mal['progress']} eps) vs Local (${local.episodeProgress} eps).';
            } else {
              final localScore = local.userRating?.overall ?? 0.0;
              final malScore = mal['score'] as double;
              if (localScore > 0 && malScore == 0) {
                action = 'upload';
                desc = 'Local rating (${localScore.toStringAsFixed(1)}) is set, MAL has none.';
              } else if (malScore > 0 && localScore == 0) {
                action = 'download';
                desc = 'MAL rating (${malScore.toStringAsFixed(1)}) is set, Local has none.';
              } else {
                action = 'upload';
                desc = 'Ratings differ (Local: ${localScore.toStringAsFixed(1)}, MAL: ${malScore.toStringAsFixed(1)}). Will sync Local to MAL.';
              }
            }
            conflictsList.add(ConflictMergeItem(
              localItem: local,
              malItem: mal,
              action: action,
              description: desc,
            ));
          }
        }
      }

      for (final malId in malMap.keys) {
        if (!localMap.containsKey(malId)) {
          downloadsList.add(MalMergeItem(malMap[malId]!));
        }
      }

      setState(() {
        _uploads = uploadsList;
        _downloads = downloadsList;
        _conflicts = conflictsList;
        _selectedUploadIds.clear();
        _selectedUploadIds.addAll(uploadsList.map((e) => e.localItem.animeId));
        _selectedDownloadIds.clear();
        _selectedDownloadIds.addAll(downloadsList.map((e) => e.malItem['id'] as int));
        _selectedConflictIds.clear();
        _selectedConflictIds.addAll(conflictsList.map((e) => e.localItem.animeId));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _executeMerge() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = "Synchronizing database, please wait...";
    });

    try {
      int successCount = 0;
      int failCount = 0;

      final List<Future<bool>> uploadTasks = _uploads
          .where((item) => _selectedUploadIds.contains(item.localItem.animeId))
          .map((item) async {
        final local = item.localItem;
        String malStatus = 'plan_to_watch';
        if (local.category == AnimeCategory.watching) malStatus = 'watching';
        else if (local.category == AnimeCategory.completed) malStatus = 'completed';
        else if (local.category == AnimeCategory.planned) malStatus = 'plan_to_watch';
        else if (local.category == AnimeCategory.ignored) malStatus = 'dropped';

        final scoreVal = local.userRating?.overall.round();
        final score = (scoreVal != null && scoreVal > 0) ? scoreVal : null;

        bool ok;
        if (local.type == 'MANGA') {
          ok = await MalAuthService.instance.updateMangaProgress(
            local.animeId,
            status: malStatus,
            numChaptersRead: local.episodeProgress,
            score: score,
          );
        } else {
          ok = await MalAuthService.instance.updateAnimeProgress(
            local.animeId,
            status: malStatus,
            numWatchedEpisodes: local.episodeProgress,
            score: score,
          );
        }

        if (ok) {
          local.isMalSynced = true;
          await local.save();
          return true;
        } else {
          return false;
        }
      }).toList();

      final uploadResults = await Future.wait(uploadTasks);
      for (final res in uploadResults) {
        if (res) successCount++; else failCount++;
      }

      final downloadItems = _downloads.where((item) => _selectedDownloadIds.contains(item.malItem['id'] as int));
      for (final item in downloadItems) {
        final mal = item.malItem;
        AnimeCategory cat = AnimeCategory.planned;
        final malStatus = mal['status'] as String? ?? 'plan_to_watch';
        if (malStatus == 'watching' || malStatus == 'reading') cat = AnimeCategory.watching;
        else if (malStatus == 'completed') cat = AnimeCategory.completed;
        else if (malStatus == 'dropped') cat = AnimeCategory.ignored;
        else if (malStatus == 'on_hold') cat = AnimeCategory.watching;

        final double score = mal['score'] as double;
        final int progress = mal['progress'] as int;

        final newItem = AnimeListItem(
          animeId: mal['id'],
          title: mal['title'],
          image: mal['image'],
          category: cat,
          episodeProgress: progress,
          episodes: mal['episodes'],
          userRating: score > 0 ? UserRating(overall: score) : null,
          type: mal['type'],
          genres: mal['genres'],
          studios: mal['studios'],
          year: mal['year'],
          isMalSynced: true,
        );

        await HiveService.saveListItemDirectly(newItem);
        successCount++;
      }

      final List<Future<bool>> conflictTasks = _conflicts
          .where((item) => _selectedConflictIds.contains(item.localItem.animeId))
          .map((conflict) async {
        final local = conflict.localItem;
        final mal = conflict.malItem;

        if (conflict.action == 'upload') {
          String malStatus = 'plan_to_watch';
          if (local.category == AnimeCategory.watching) malStatus = 'watching';
          else if (local.category == AnimeCategory.completed) malStatus = 'completed';
          else if (local.category == AnimeCategory.planned) malStatus = 'plan_to_watch';
          else if (local.category == AnimeCategory.ignored) malStatus = 'dropped';

          final scoreVal = local.userRating?.overall.round();
          final score = (scoreVal != null && scoreVal > 0) ? scoreVal : null;

          bool ok;
          if (local.type == 'MANGA') {
            ok = await MalAuthService.instance.updateMangaProgress(
              local.animeId,
              status: malStatus,
              numChaptersRead: local.episodeProgress,
              score: score,
            );
          } else {
            ok = await MalAuthService.instance.updateAnimeProgress(
              local.animeId,
              status: malStatus,
              numWatchedEpisodes: local.episodeProgress,
              score: score,
          );
          }

          if (ok) {
            local.isMalSynced = true;
            await local.save();
            return true;
          } else {
            return false;
          }
        } else {
          AnimeCategory cat = AnimeCategory.planned;
          final malStatus = mal['status'] as String? ?? 'plan_to_watch';
          if (malStatus == 'watching' || malStatus == 'reading') cat = AnimeCategory.watching;
          else if (malStatus == 'completed') cat = AnimeCategory.completed;
          else if (malStatus == 'dropped') cat = AnimeCategory.ignored;
          else if (malStatus == 'on_hold') cat = AnimeCategory.watching;

          local.category = cat;
          local.episodeProgress = mal['progress'];
          final double score = mal['score'] as double;
          if (score > 0) {
            local.userRating = UserRating(overall: score);
          }
          local.isMalSynced = true;
          await local.save();
          return true;
        }
      }).toList();

      final conflictResults = await Future.wait(conflictTasks);
      for (final res in conflictResults) {
        if (res) successCount++; else failCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sync complete! Merged $successCount items successfully. ${failCount > 0 ? '$failCount failed.' : ''}"),
            backgroundColor: AppColors.completed,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Merge failed: $e"), backgroundColor: AppColors.error),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalChanges = _uploads.length + _downloads.length + _conflicts.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Merge Lists Preview", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text(_loadingMessage, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text("An error occurred:\n$_error", textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadAndCompare,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.accent, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                totalChanges == 0
                                    ? "Your local collection and MyAnimeList are perfectly in sync!"
                                    : "We found $totalChanges pending updates. Preview the compartments below before merging.",
                                style: const TextStyle(fontSize: 13, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.accent,
                      unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                      indicatorColor: AppColors.accent,
                      tabs: [
                        Tab(text: "Local Only (${_uploads.length})"),
                        Tab(text: "MAL Only (${_downloads.length})"),
                        Tab(text: "Conflicts (${_conflicts.length})"),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildLocalOnlyCompartment(),
                          _buildMalOnlyCompartment(),
                          _buildConflictsCompartment(),
                        ],
                      ),
                    ),
                    if (totalChanges > 0)
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: SafeArea(
                          top: false,
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _executeMerge,
                              icon: const Icon(Icons.merge_rounded, color: Colors.white),
                              label: const Text("Confirm & Sync Merge", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildLocalOnlyCompartment() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_uploads.isEmpty) {
      return _emptyCompartment("No local-only items. Everything here is synced to MAL.");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _uploads.length,
      itemBuilder: (context, index) {
        final item = _uploads[index].localItem;
        final isSelected = _selectedUploadIds.contains(item.animeId);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          child: ListTile(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedUploadIds.remove(item.animeId);
                } else {
                  _selectedUploadIds.add(item.animeId);
                }
              });
            },
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.accent,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedUploadIds.add(item.animeId);
                      } else {
                        _selectedUploadIds.remove(item.animeId);
                      }
                    });
                  },
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: item.image,
                    width: 40,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                  ),
                ),
              ],
            ),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    _badge("Local Only", Colors.orange),
                    const SizedBox(width: 6),
                    _badge(item.type ?? "TV", Colors.blueGrey),
                  ],
                ),
                const SizedBox(height: 4),
                Text("Will Upload -> Ep: ${item.episodeProgress} / ${item.episodes}", style: const TextStyle(fontSize: 11)),
              ],
            ),
            trailing: Icon(Icons.arrow_upward_rounded, color: AppColors.accent),
          ),
        );
      },
    );
  }

  Widget _buildMalOnlyCompartment() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_downloads.isEmpty) {
      return _emptyCompartment("No MAL-only items. Everything from MAL is present locally.");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _downloads.length,
      itemBuilder: (context, index) {
        final mal = _downloads[index].malItem;
        final malId = mal['id'] as int;
        final isSelected = _selectedDownloadIds.contains(malId);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          child: ListTile(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedDownloadIds.remove(malId);
                } else {
                  _selectedDownloadIds.add(malId);
                }
              });
            },
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.accent,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedDownloadIds.add(malId);
                      } else {
                        _selectedDownloadIds.remove(malId);
                      }
                    });
                  },
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: mal['image'],
                    width: 40,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                  ),
                ),
              ],
            ),
            title: Text(mal['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    _badge("MAL Only", Colors.blue),
                    const SizedBox(width: 6),
                    _badge(mal['type'] ?? "TV", Colors.blueGrey),
                  ],
                ),
                const SizedBox(height: 4),
                Text("Will Download -> Ep: ${mal['progress']} / ${mal['episodes']}", style: const TextStyle(fontSize: 11)),
              ],
            ),
            trailing: const Icon(Icons.arrow_downward_rounded, color: Colors.blue),
          ),
        );
      },
    );
  }

  Widget _buildConflictsCompartment() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_conflicts.isEmpty) {
      return _emptyCompartment("No conflicts or data differences found.");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _conflicts.length,
      itemBuilder: (context, index) {
        final conflict = _conflicts[index];
        final isUpload = conflict.action == 'upload';
        final isSelected = _selectedConflictIds.contains(conflict.localItem.animeId);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          child: InkWell(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedConflictIds.remove(conflict.localItem.animeId);
                } else {
                  _selectedConflictIds.add(conflict.localItem.animeId);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: AppColors.accent,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedConflictIds.add(conflict.localItem.animeId);
                        } else {
                          _selectedConflictIds.remove(conflict.localItem.animeId);
                        }
                      });
                    },
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: conflict.localItem.image,
                      width: 45,
                      height: 65,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(conflict.localItem.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text(
                          conflict.description,
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _badge(
                              isUpload ? "Sync to MAL" : "Sync to Local",
                              isUpload ? AppColors.accent : Colors.blue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isUpload ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    color: isUpload ? AppColors.accent : Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _emptyCompartment(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: AppColors.completed.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
