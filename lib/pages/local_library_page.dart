import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/models/anime_list_item.dart';
import '../widgets/video_player_screen.dart';

class LocalLibraryPage extends StatefulWidget {
  const LocalLibraryPage({super.key});

  @override
  State<LocalLibraryPage> createState() => _LocalLibraryPageState();
}

class _LocalLibraryPageState extends State<LocalLibraryPage> {
  String? _rootPath;
  String? _currentPath;
  List<FileSystemEntity> _currentItems = [];
  bool _isLoading = false;

  // Auto-Scanner State
  int _selectedViewTab = 0; // 0 = Auto-Linked, 1 = File Explorer
  Map<AnimeListItem, List<FileSystemEntity>> _autoMatchedAnimes = {};
  bool _isScanning = false;
  AnimeListItem? _selectedLinkedAnime;

  // Mobile Explorer state
  String? _mobileExplorerPath;
  String? _mobileExplorerRoot;
  List<FileSystemEntity> _mobileExplorerItems = [];
  bool _hasMobilePermission = false;
  String? _mobilePermissionError;

  // Skeleton loading state
  bool _showSkeleton = false;
  Timer? _skeletonTimer;

  void _startLoadingTimer() {
    _skeletonTimer?.cancel();
    setState(() {
      _showSkeleton = false;
    });
    _skeletonTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && (_isLoading || _isScanning)) {
        setState(() {
          _showSkeleton = true;
        });
      }
    });
  }

  void _stopLoading() {
    _skeletonTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isScanning = false;
        _showSkeleton = false;
      });
    }
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initPath();
    if (Platform.isAndroid || Platform.isIOS) {
      _initMobileExplorer();
    }
  }

  Future<bool> _requestMobileStoragePermission() async {
    if (Platform.isAndroid) {
      final statusManage = await Permission.manageExternalStorage.request();
      if (statusManage.isGranted) return true;
      final statusStorage = await Permission.storage.request();
      if (statusStorage.isGranted) return true;
      return false;
    } else if (Platform.isIOS) {
      final statusStorage = await Permission.storage.request();
      if (statusStorage.isGranted) return true;
      return false;
    }
    return true;
  }

  Future<void> _initMobileExplorer() async {
    final granted = await _requestMobileStoragePermission();
    setState(() {
      _hasMobilePermission = granted;
    });

    if (granted) {
      String root = '/storage/emulated/0';
      if (Platform.isIOS) {
        final docDir = await getApplicationDocumentsDirectory();
        root = docDir.path;
      }
      setState(() {
        _mobileExplorerRoot = root;
        _mobileExplorerPath = root;
      });
      await _loadMobileDirectory(root);
    } else {
      setState(() {
        _mobilePermissionError = "Storage permission denied. Please grant permission in your settings to explore files.";
      });
    }
  }

  Future<void> _loadMobileDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _startLoadingTimer();
    });
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        final items = await dir.list().toList();
        items.sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return a.path.compareTo(b.path);
        });
        if (mounted) {
          setState(() {
            _mobileExplorerItems = items;
            _mobileExplorerPath = path;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading mobile directory: $e');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _initPath() async {
    String? path = HiveService.localAnimeFolder;
    
    if (path == null && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final localFolder = '${docDir.path}${Platform.pathSeparator}MyAnimes';
        final dir = Directory(localFolder);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        await HiveService.setLocalAnimeFolder(localFolder);
        path = localFolder;
      } catch (e) {
        debugPrint("Error initializing automatic mobile folder: $e");
      }
    }

    if (mounted) {
      setState(() {
        _rootPath = path;
        _currentPath = path;
      });
      if (path != null) {
        _syncWatchingAnimesFolder().then((_) {
          _loadDirectory(path!);
          _runAutoScan();
        });
      }
    }
  }

  Future<void> _syncWatchingAnimesFolder() async {
    if (_rootPath == null) return;
    try {
      final watchingDir = Directory(
          '$_rootPath${Platform.pathSeparator}Watching Animes');
      if (!await watchingDir.exists()) {
        await watchingDir.create();
      }

      final allWatching = HiveService.getByCategory(AnimeCategory.watching);
      for (final anime in allWatching) {
        final cleanTitle = anime.title
            .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
            .trim();
        if (cleanTitle.isNotEmpty) {
          final animeDir = Directory(
              '${watchingDir.path}${Platform.pathSeparator}$cleanTitle');
          if (!await animeDir.exists()) {
            await animeDir.create();
          }
        }
      }
    } catch (e) {
      debugPrint('Sync Watching Animes error: $e');
    }
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _startLoadingTimer();
    });
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        final items = await dir.list().toList();
        // Sort folders first, then files
        items.sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return a.path.compareTo(b.path);
        });
        if (mounted) {
          setState(() {
            _currentItems = items;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading directory: $e');
    } finally {
      _stopLoading();
    }
  }

  bool _isVideoFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mkv') ||
        lower.endsWith('.avi') || lower.endsWith('.webm');
  }

  bool _isCompressedFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.zip') || lower.endsWith('.rar') ||
        lower.endsWith('.7z');
  }

  // Recursive Scanner Logic
  Future<void> _runAutoScan() async {
    if (_rootPath == null) return;
    setState(() {
      _isScanning = true;
      _startLoadingTimer();
    });

    final matched = await _scanAndLinkLocalVideos();

    if (mounted) {
      setState(() {
        _autoMatchedAnimes = matched;
      });
    }
    _stopLoading();
  }

  Future<Map<AnimeListItem, List<FileSystemEntity>>> _scanAndLinkLocalVideos() async {
    final Map<AnimeListItem, List<FileSystemEntity>> matched = {};
    if (_rootPath == null) return matched;

    final allItems = HiveService.getAllListItems();
    if (allItems.isEmpty) return matched;

    final dir = Directory(_rootPath!);
    if (!await dir.exists()) return matched;

    try {
      final List<FileSystemEntity> allFiles = [];
      await _findVideosRecursively(dir, allFiles);

      for (final file in allFiles) {
        final pathLower = file.path.toLowerCase();
        final fileNameLower = file.path.split(Platform.pathSeparator).last.toLowerCase();

        for (final anime in allItems) {
          final titleLower = anime.title.toLowerCase();
          // Clean title to match common formatting (no special characters)
          final cleanTitle = titleLower.replaceAll(RegExp(r'[^a-z0-9\s]+'), '').trim();
          final cleanPath = pathLower.replaceAll(RegExp(r'[^a-z0-9\s\\/]+'), ' ');

          // Match:
          // 1. Path contains clean anime title (e.g. inside a folder named after the anime)
          // 2. Filename contains clean anime title
          if (cleanPath.contains(cleanTitle) || fileNameLower.contains(cleanTitle)) {
            matched.putIfAbsent(anime, () => []).add(file);
            break; // Stop matching other animes for this file
          }
        }
      }
    } catch (e) {
      debugPrint('Scanning error: $e');
    }
    return matched;
  }

  Future<void> _findVideosRecursively(Directory dir, List<FileSystemEntity> results) async {
    try {
      final List<FileSystemEntity> entities = await dir.list(recursive: false).toList();
      for (final entity in entities) {
        if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          // Skip hidden folders
          if (!name.startsWith('.')) {
            await _findVideosRecursively(entity, results);
          }
        } else if (entity is File) {
          if (_isVideoFile(entity.path)) {
            results.add(entity);
          }
        }
      }
    } catch (e) {
      debugPrint('Skipping folder: ${dir.path} -> $e');
    }
  }

  int _extractEpisodeNumber(String fileName) {
    final nameLower = fileName.toLowerCase();
    
    // Pattern matches: "episode 5", "ep 5", "ep.5", "e5", "episode05", "ep05"
    final epMatch = RegExp(r'(?:episode|ep|e)\.?\s*(\d+)').firstMatch(nameLower);
    if (epMatch != null) {
      return int.tryParse(epMatch.group(1)!) ?? 1;
    }
    
    // Pattern matches: "- 05", " - 5", " 05 "
    final dashMatch = RegExp(r'-\s*(\d+)\b').firstMatch(nameLower);
    if (dashMatch != null) {
      return int.tryParse(dashMatch.group(1)!) ?? 1;
    }
    
    final cleanName = nameLower.split('.').first;
    final matches = RegExp(r'\d+').allMatches(cleanName);
    if (matches.isNotEmpty) {
      // Return the last digit that isn't a year/resolution
      for (int i = matches.length - 1; i >= 0; i--) {
        final val = matches.elementAt(i).group(0)!;
        if (val != '1080' && val != '720' && val != '480' && val != '2160') {
          return int.tryParse(val) ?? 1;
        }
      }
    }
    return 1;
  }

  Future<void> _extractCompressedFile(File archiveFile) async {
    setState(() => _isLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkCard
                  : AppColors.lightCard,
              title: const Text('Extracting...'),
              content: Row(
                children: [
                  CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(width: 24),
                  const Expanded(child: Text(
                      'Extracting video files in background... Please do not close the app.')),
                ],
              ),
            ),
          ),
    );

    try {
      final destDir = archiveFile.parent;

      await compute(_extractArchiveInIsolate, {
        'archivePath': archiveFile.path,
        'destDirPath': destDir.path,
      });

      if (mounted) Navigator.pop(context); // close dialog
      await _loadDirectory(destDir.path);
      _runAutoScan();
    } catch (e) {
      if (mounted) Navigator.pop(context); // close dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Extraction error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleItemTap(FileSystemEntity item, {AnimeListItem? relatedAnime}) {
    if (item is Directory) {
      setState(() {
        _currentPath = item.path;
      });
      _loadDirectory(item.path);
    } else if (item is File) {
      if (_isVideoFile(item.path)) {
        final title = item.path
            .split(Platform.pathSeparator)
            .last;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                VideoPlayerScreen(
                  videoPath: item.path,
                  videoTitle: title,
                  relatedAnime: relatedAnime,
                ),
          ),
        ).then((_) {
          // Re-scan when back to update episode progress indicator in list
          _runAutoScan();
        });
      } else if (_isCompressedFile(item.path)) {
        showDialog(
          context: context,
          builder: (context) =>
              AlertDialog(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkCard
                    : AppColors.lightCard,
                title: const Text('Extract Video Files?'),
                content: const Text(
                    'This will extract all video files from the archive directly into the current folder, and then delete the archive. Proceed?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent),
                    onPressed: () {
                      Navigator.pop(context);
                      _extractCompressedFile(item);
                    },
                    child: const Text(
                        'Extract', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_selectedLinkedAnime != null) {
      setState(() {
        _selectedLinkedAnime = null;
      });
      return false;
    }
    
    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (isMobile) {
      if (_selectedViewTab == 0 && _mobileExplorerPath != null && _mobileExplorerRoot != null) {
        if (_mobileExplorerPath != _mobileExplorerRoot) {
          final parent = Directory(_mobileExplorerPath!).parent.path;
          await _loadMobileDirectory(parent);
          return false;
        }
      }
    } else {
      if (_selectedViewTab == 1 && _currentPath != null && _currentPath != _rootPath) {
        final parent = Directory(_currentPath!).parent.path;
        if (parent.startsWith(_rootPath!) || parent == _rootPath) {
          setState(() {
            _currentPath = parent;
          });
          _loadDirectory(parent);
        } else {
          setState(() {
            _currentPath = _rootPath;
          });
          _loadDirectory(_rootPath!);
        }
        return false;
      }
    }
    return true; // Let system handle pop
  }

  bool get _shouldShowBackButton {
    if (_selectedLinkedAnime != null) return true;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (isMobile) {
      if (_selectedViewTab == 0 &&
          _mobileExplorerPath != null &&
          _mobileExplorerRoot != null &&
          _mobileExplorerPath != _mobileExplorerRoot) {
        return true;
      }
    } else {
      if (_selectedViewTab == 1 && _currentPath != null && _currentPath != _rootPath) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_rootPath == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Local Anime Folder is not set.'),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () async {
                try {
                  String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                  if (selectedDirectory != null) {
                    await HiveService.setLocalAnimeFolder(selectedDirectory);
                    setState(() {
                      _rootPath = selectedDirectory;
                      _currentPath = selectedDirectory;
                    });
                    _syncWatchingAnimesFolder().then((_) {
                      _loadDirectory(selectedDirectory);
                      _runAutoScan();
                    });
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error selecting folder: $e'))
                    );
                  }
                }
              },
              child: const Text('Select Anime Folder', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Breadcrumbs & Import Actions
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                if (_shouldShowBackButton) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: _onWillPop,
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    _selectedLinkedAnime != null 
                        ? _selectedLinkedAnime!.title 
                        : (Platform.isAndroid || Platform.isIOS
                            ? (_selectedViewTab == 0 ? (_mobileExplorerPath ?? 'Mobile Explorer') : 'Local Library')
                            : (_selectedViewTab == 0 ? 'Local Library' : (_currentPath ?? 'File Explorer'))),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _importVideosFromFilesystem,
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('Import Anime', style: TextStyle(color: Colors.white, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isScanning || _isLoading ? Icons.hourglass_empty : Icons.refresh, color: AppColors.accent),
                  tooltip: 'Sync & Scan Folder',
                  onPressed: () async {
                    setState(() {
                      _isLoading = true;
                      _isScanning = true;
                      _startLoadingTimer();
                    });
                    await _syncWatchingAnimesFolder();
                    if (_currentPath != null) {
                      await _loadDirectory(_currentPath!);
                    }
                    await _runAutoScan();
                    _stopLoading();
                  },
                ),
              ],
            ),
          ),

          // Custom Segmented Switcher for Tabs (only show if not inside anime detail)
          if (_selectedLinkedAnime == null) _buildTabSwitcher(isDark),

          Expanded(
            child: _showSkeleton
                ? (_isCurrentTabGridLayout() ? _buildSkeletonGrid(isDark) : _buildSkeletonList(isDark))
                : _selectedLinkedAnime != null 
                    ? _buildLinkedEpisodeList(isDark)
                    : (Platform.isAndroid || Platform.isIOS
                        ? (_selectedViewTab == 0 ? _buildMobileExplorerView() : _buildAutoLinkedGrid(isDark))
                        : (_selectedViewTab == 0 ? _buildAutoLinkedGrid(isDark) : _buildRealFolderView())),
          ),
        ],
      ),
    );
  }

  bool _isCurrentTabGridLayout() {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (isMobile) {
      return _selectedViewTab == 1;
    } else {
      return _selectedViewTab == 0;
    }
  }

  Widget _buildSkeletonGrid(bool isDark) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 160).floor().clamp(2, 8);
    final baseColor = isDark ? const Color(0xFF1E2230) : const Color(0xFFE0E0EA);
    final highlightColor = isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF0F0F8);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    final baseColor = isDark ? const Color(0xFF1E2230) : const Color(0xFFE0E0EA);
    final highlightColor = isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF0F0F8);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 12,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 150,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabSwitcher(bool isDark) {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(child: _buildTabButton(0, isMobile ? 'Mobile Explorer' : 'Auto-Linked', isMobile ? Icons.explore_rounded : Icons.auto_awesome, isDark)),
          const SizedBox(width: 4),
          Expanded(child: _buildTabButton(1, isMobile ? 'Local Library' : 'File Explorer', isMobile ? Icons.local_library_rounded : Icons.folder_open_rounded, isDark)),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, bool isDark) {
    final active = _selectedViewTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedViewTab = index;
        });
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

  // View 1: Auto Linked Library Grid
  Widget _buildAutoLinkedGrid(bool isDark) {
    if (_autoMatchedAnimes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 16),
              Text(
                'No matching local episodes found.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'To match episodes, ensure your local video file names contain the anime title (e.g. "Chainsaw Man - Ep 01.mp4" or reside inside folders named after the anime).',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final matchedList = _autoMatchedAnimes.entries.toList();

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 160).floor().clamp(2, 8);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: matchedList.length,
      itemBuilder: (context, index) {
        final entry = matchedList[index];
        final anime = entry.key;
        final count = entry.value.length;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedLinkedAnime = anime;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: anime.image,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: isDark ? Colors.white10 : Colors.black12),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black87, Colors.transparent],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                          child: Text(
                            '$count Ep${count > 1 ? 's' : ''} found',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  child: Text(
                    anime.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // View 1 Sub-View: Episode detail lists
  Widget _buildLinkedEpisodeList(bool isDark) {
    if (_selectedLinkedAnime == null) return const SizedBox.shrink();

    final files = _autoMatchedAnimes[_selectedLinkedAnime] ?? [];
    
    // Sort files based on parsed episode number
    files.sort((a, b) {
      final nameA = a.path.split(Platform.pathSeparator).last;
      final nameB = b.path.split(Platform.pathSeparator).last;
      return _extractEpisodeNumber(nameA).compareTo(_extractEpisodeNumber(nameB));
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final fileName = file.path.split(Platform.pathSeparator).last;
        final epNum = _extractEpisodeNumber(fileName);
        final isWatched = epNum <= _selectedLinkedAnime!.episodeProgress;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 10),
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.play_circle_fill, 
                  color: isWatched ? AppColors.completed.withAlpha(180) : AppColors.accent, 
                  size: 38
                ),
                if (isWatched)
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 7,
                      child: Icon(Icons.check, size: 10, color: Colors.green),
                    ),
                  ),
              ],
            ),
            title: Text(
              'Episode $epNum',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              fileName,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isWatched 
                ? Text('Watched', style: TextStyle(color: AppColors.completed, fontSize: 12, fontWeight: FontWeight.bold)) 
                : Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? Colors.white24 : Colors.black26),
            onTap: () => _handleItemTap(file, relatedAnime: _selectedLinkedAnime),
          ),
        );
      },
    );
  }

  // View 2: Raw Folder explorer
  Widget _buildRealFolderView() {
    if (_currentItems.isEmpty) {
      return const Center(child: Text('Empty folder.'));
    }

    return ListView.builder(
      itemCount: _currentItems.length,
      itemBuilder: (context, index) {
        final item = _currentItems[index];
        final isDir = item is Directory;
        final name = item.path
            .split(Platform.pathSeparator)
            .last;
        final isVid = !isDir && _isVideoFile(name);
        final isZip = !isDir && !isVid && _isCompressedFile(name);

        IconData iconData = Icons.insert_drive_file;
        Color iconColor = Colors.grey;

        if (isDir) {
          if (name == 'Watching Animes') {
            iconData = Icons.diamond;
            iconColor = AppColors.starYellow;
          } else {
            iconData = Icons.folder;
            iconColor = Theme.of(context).brightness == Brightness.dark ? Colors.blue[300]! : Colors.blue[600]!;
          }
        } else if (isVid) {
          iconData = Icons.play_circle_fill;
          iconColor = AppColors.accent;
        } else if (isZip) {
          iconData = Icons.folder_zip;
          iconColor = Colors.orange;
        }

        return ListTile(
          leading: Icon(iconData, color: iconColor, size: 36),
          title: Text(name, style: TextStyle(
            fontWeight: name == 'Watching Animes' ? FontWeight.bold : FontWeight.normal,
            color: name == 'Watching Animes' ? AppColors.starYellow : null,
          )),
          onTap: () => _handleItemTap(item),
        );
      },
    );
  }

  Future<void> _importVideosFromFilesystem() async {
    if (_rootPath == null) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mkv', 'avi', 'webm'],
        allowMultiple: true,
        dialogTitle: 'Select Anime Videos to Import (Cut)',
      );

      if (result == null || result.files.isEmpty) return;

      final nameController = TextEditingController();
      final animeName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkCard
              : AppColors.lightCard,
          title: const Text('Enter Anime Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Chainsaw Man',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () {
                final text = nameController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context, text);
                }
              },
              child: const Text('Import', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (animeName == null || animeName.trim().isEmpty) return;

      final cleanName = animeName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
      if (cleanName.isEmpty) return;

      setState(() => _isLoading = true);

      final watchingDirPath = '$_rootPath${Platform.pathSeparator}Watching Animes';
      final destDir = Directory('$watchingDirPath${Platform.pathSeparator}$cleanName');
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      for (final fileInfo in result.files) {
        if (fileInfo.path == null) continue;
        final srcFile = File(fileInfo.path!);
        final fileName = fileInfo.name;
        final destFile = File('${destDir.path}${Platform.pathSeparator}$fileName');

        final stream = srcFile.openRead();
        final sink = destFile.openWrite();
        await sink.addStream(stream);
        await sink.close();
        await srcFile.delete();
      }

      if (_currentPath != null) {
        await _loadDirectory(_currentPath!);
      }
      await _runAutoScan();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${result.files.length} video(s) into "$cleanName" directory!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildMobileExplorerView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (!_hasMobilePermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_shared_rounded, size: 64, color: AppColors.accent.withOpacity(0.5)),
              const SizedBox(height: 16),
              const Text(
                'Permission Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _mobilePermissionError ?? 'Please grant storage access permission to browse device folders.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _initMobileExplorer,
                icon: const Icon(Icons.security_rounded, color: Colors.white),
                label: const Text('Grant Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (_mobileExplorerItems.isEmpty) {
      return const Center(child: Text('Empty folder or no permissions.'));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _mobileExplorerPath ?? '',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: _mobileExplorerItems.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
            itemBuilder: (context, index) {
              final item = _mobileExplorerItems[index];
              final isDir = item is Directory;
              final name = item.path.split(Platform.pathSeparator).last;
              final isVid = !isDir && _isVideoFile(name);
              final isZip = !isDir && !isVid && _isCompressedFile(name);

              IconData iconData = Icons.insert_drive_file;
              Color iconColor = Colors.grey;

              if (isDir) {
                iconData = Icons.folder_rounded;
                iconColor = isDark ? Colors.blue[300]! : Colors.blue[600]!;
              } else if (isVid) {
                iconData = Icons.play_circle_fill_rounded;
                iconColor = AppColors.accent;
              } else if (isZip) {
                iconData = Icons.folder_zip_rounded;
                iconColor = Colors.orange;
              }

              return ListTile(
                leading: Icon(iconData, color: iconColor, size: 28),
                title: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isDir ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: isDir
                    ? null
                    : Text(
                        'File • ${name.split('.').last.toUpperCase()}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                trailing: isDir
                    ? const Icon(Icons.chevron_right_rounded, size: 20)
                    : null,
                onTap: () {
                  if (isDir) {
                    _loadMobileDirectory(item.path);
                  } else if (isVid) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          videoPath: item.path,
                          videoTitle: name,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<void> _extractArchiveInIsolate(Map<String, String> args) async {
  final archivePath = args['archivePath']!;
  final destDirPath = args['destDirPath']!;

  bool isVideoFile(String p) {
    final lower = p.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.webm');
  }

  final pathLower = archivePath.toLowerCase();
  if (pathLower.endsWith('.zip')) {
    final inputStream = InputFileStream(archivePath);
    final archive = ZipDecoder().decodeStream(inputStream);

    for (final file in archive) {
      if (file.isFile) {
        if (isVideoFile(file.name)) {
          final fileName = file.name.split('/').last;
          final outFile = File('$destDirPath${Platform.pathSeparator}$fileName');
          final outStream = OutputFileStream(outFile.path);
          file.writeContent(outStream);
          outStream.close();
        }
      }
    }
    inputStream.close();
    await File(archivePath).delete();
  } else {
    final tempDir = Directory('$destDirPath${Platform.pathSeparator}temp_extract');
    if (!await tempDir.exists()) await tempDir.create();

    final result = await Process.run('tar', ['-xf', archivePath, '-C', tempDir.path]);

    if (result.exitCode == 0) {
      await for (final entity in tempDir.list(recursive: true)) {
        if (entity is File && isVideoFile(entity.path)) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          await entity.rename('$destDirPath${Platform.pathSeparator}$fileName');
        }
      }
      await File(archivePath).delete();
    } else {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      throw Exception(result.stderr);
    }
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  }
}