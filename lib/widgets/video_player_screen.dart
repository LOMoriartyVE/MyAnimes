import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../core/theme/app_colors.dart';
import 'dart:io';
import 'dart:async';
import '../core/models/anime_list_item.dart';
import '../core/services/hive_service.dart';
import '../core/services/mal_auth_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String videoTitle;
  final AnimeListItem? relatedAnime; // If launched from a known anime context

  const VideoPlayerScreen({
    super.key,
    required this.videoPath,
    required this.videoTitle,
    this.relatedAnime,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;
  
  List<File> _playlist = [];
  int _currentIndex = -1;
  AnimeListItem? _matchedAnime;
  String _currentTitle = '';

  bool _showControls = true;
  Timer? _hideTimer;

  // Trackers for automatic watch progression (>= 85%)
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _hasTrackedProgress = false;

  // Advanced Controls: Simulated Brightness, Volume, Gestures, Playback Speed
  double _simulatedBrightness = 1.0;
  double _simulatedVolume = 100.0;
  double _currentSpeed = 1.0;

  bool _showGestureIndicator = false;
  String _gestureIndicatorText = '';
  IconData _gestureIndicatorIcon = Icons.volume_up;
  Timer? _gestureIndicatorTimer;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    _currentTitle = widget.videoTitle;
    
    _initPlaylistAndAnime();
    _cancelAndRestartHideTimer();

    // Listen to video progress streams to track 85% completions
    _positionSub = player.stream.position.listen((pos) {
      _currentPosition = pos;
      _checkAndTriggerProgress();
    });
    _durationSub = player.stream.duration.listen((dur) {
      _totalDuration = dur;
      _checkAndTriggerProgress();
    });

    player.open(Media(widget.videoPath));
    player.play();
  }

  void _cancelAndRestartHideTimer() {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _showControls = true;
    });
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  Future<void> _initPlaylistAndAnime() async {
    try {
      final file = File(widget.videoPath);
      final dir = file.parent;
      final dirName = dir.path.split(Platform.pathSeparator).last;

      _matchedAnime = widget.relatedAnime;
      if (_matchedAnime == null) {
        final allWatching = HiveService.getByCategory(AnimeCategory.watching);
        for (final a in allWatching) {
          final cleanTitle = a.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
          if (cleanTitle == dirName) {
            _matchedAnime = a;
            break;
          }
        }
      }
      
      if (mounted) setState(() {}); 

      final items = await dir.list().toList();
      final videos = items.whereType<File>().where((f) {
        final lower = f.path.toLowerCase();
        return lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.avi') || lower.endsWith('.webm');
      }).toList();
      
      videos.sort((a, b) => a.path.compareTo(b.path));
      
      setState(() {
        _playlist = videos;
        _currentIndex = _playlist.indexWhere((f) => f.path == widget.videoPath);
      });
      
    } catch (e) {
      debugPrint('Video init error: $e');
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

  void _checkAndTriggerProgress() {
    if (_totalDuration > Duration.zero && !_hasTrackedProgress && _currentIndex >= 0 && _currentIndex < _playlist.length) {
      final percent = _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;
      if (percent >= 0.85) {
        _hasTrackedProgress = true;
        _updateProgressForFile(_playlist[_currentIndex]);
      }
    }
  }

  void _updateProgressForFile(File file) async {
    if (_matchedAnime != null) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final epNum = _parseEpisodeNumber(fileName);
      if (epNum != null) {
        // Only update if it represents progress forward
        if (epNum > _matchedAnime!.episodeProgress) {
          await HiveService.updateEpisodeProgress(_matchedAnime!.animeId, epNum);
          if (MalAuthService.instance.isLoggedIn) {
            await MalAuthService.instance.updateAnimeProgress(_matchedAnime!.animeId, numWatchedEpisodes: epNum);
          }
          final allItems = HiveService.getAllListItems();
          try {
             final updated = allItems.firstWhere((a) => a.animeId == _matchedAnime!.animeId);
             if (mounted) {
               setState(() {
                 _matchedAnime = updated;
               });
             }
          } catch (_) {}
        }
      }
    }
  }

  void _playIndex(int index) {
    if (index >= 0 && index < _playlist.length) {
      final file = _playlist[index];
      setState(() {
        _currentIndex = index;
        _currentTitle = file.path.split(Platform.pathSeparator).last;
        _hasTrackedProgress = false; // Reset progress track flag for new episode
      });
      player.open(Media(file.path));
      player.play();
      _updateProgressForFile(file);
    }
  }

  void _updateProgress(int delta) async {
    if (_matchedAnime != null) {
      final newProgress = _matchedAnime!.episodeProgress + delta;
      if (newProgress >= 0) {
        await HiveService.updateEpisodeProgress(_matchedAnime!.animeId, newProgress);
        if (MalAuthService.instance.isLoggedIn) {
          await MalAuthService.instance.updateAnimeProgress(_matchedAnime!.animeId, numWatchedEpisodes: newProgress);
        }
        final allItems = HiveService.getAllListItems();
        try {
           final updated = allItems.firstWhere((a) => a.animeId == _matchedAnime!.animeId);
           setState(() {
             _matchedAnime = updated;
           });
        } catch (_) {}
      }
    }
  }

  void _showGestureFeedback(String text, IconData icon) {
    _gestureIndicatorTimer?.cancel();
    setState(() {
      _showGestureIndicator = true;
      _gestureIndicatorText = text;
      _gestureIndicatorIcon = icon;
    });
    _gestureIndicatorTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _showGestureIndicator = false;
        });
      }
    });
  }

  void _toggleSpeed() {
    final speeds = [1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_currentSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    setState(() {
      _currentSpeed = speeds[nextIndex];
    });
    player.setRate(_currentSpeed);
    _showGestureFeedback('${_currentSpeed}x Speed', Icons.speed_rounded);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _gestureIndicatorTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onHover: (_) => _cancelAndRestartHideTimer(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video Player + GestureDetector Layer for Brightness, Volume, and Double Tap Seek
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _cancelAndRestartHideTimer,
                onDoubleTapDown: (details) {
                  final width = MediaQuery.of(context).size.width;
                  final x = details.globalPosition.dx;
                  if (x < width * 0.33) {
                    // Seek -10s
                    final target = player.state.position - const Duration(seconds: 10);
                    player.seek(target < Duration.zero ? Duration.zero : target);
                    _showGestureFeedback('-10s', Icons.replay_10_rounded);
                  } else if (x > width * 0.66) {
                    // Seek +10s
                    final target = player.state.position + const Duration(seconds: 10);
                    player.seek(target);
                    _showGestureFeedback('+10s', Icons.forward_10_rounded);
                  }
                },
                onVerticalDragUpdate: (details) {
                  final width = MediaQuery.of(context).size.width;
                  final isLeft = details.globalPosition.dx < width / 2;
                  final delta = -details.primaryDelta! / 200.0; // Sensitivity

                  if (isLeft) {
                    setState(() {
                      _simulatedBrightness = (_simulatedBrightness + delta).clamp(0.1, 1.0);
                    });
                    _showGestureFeedback(
                      'Brightness: ${(_simulatedBrightness * 100).round()}%',
                      Icons.brightness_6_rounded,
                    );
                  } else {
                    setState(() {
                      _simulatedVolume = (_simulatedVolume + delta * 100.0).clamp(0.0, 100.0);
                    });
                    player.setVolume(_simulatedVolume);
                    _showGestureFeedback(
                      'Volume: ${_simulatedVolume.round()}%',
                      _simulatedVolume == 0.0 ? Icons.volume_mute_rounded : Icons.volume_up_rounded,
                    );
                  }
                },
                child: Center(
                  child: Video(
                    controller: controller,
                    controls: AdaptiveVideoControls,
                  ),
                ),
              ),
            ),

            // Simulated Brightness Darkening Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  color: Colors.black.withOpacity((1.0 - _simulatedBrightness).clamp(0.0, 0.95)),
                ),
              ),
            ),

            // Top Bar Overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Container(
                    height: kToolbarHeight + MediaQuery.of(context).padding.top,
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                    color: Colors.black54,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentTitle,
                            style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_matchedAnime != null) ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text('Watched: ${_matchedAnime!.episodeProgress} eps', 
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                            tooltip: 'Decrease watched episodes',
                            onPressed: () {
                              _cancelAndRestartHideTimer();
                              _updateProgress(-1);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                            tooltip: 'Increase watched episodes',
                            onPressed: () {
                              _cancelAndRestartHideTimer();
                              _updateProgress(1);
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Playback Speed Selector
                        IconButton(
                          icon: const Icon(Icons.speed_rounded, color: Colors.white),
                          tooltip: 'Playback Speed (${_currentSpeed}x)',
                          onPressed: () {
                            _cancelAndRestartHideTimer();
                            _toggleSpeed();
                          },
                        ),
                        if (_playlist.isNotEmpty) ...[
                           IconButton(
                             icon: const Icon(Icons.skip_previous, color: Colors.white),
                             tooltip: 'Previous Video',
                             onPressed: _currentIndex > 0 ? () {
                               _cancelAndRestartHideTimer();
                               _playIndex(_currentIndex - 1);
                             } : null,
                           ),
                           IconButton(
                             icon: const Icon(Icons.skip_next, color: Colors.white),
                             tooltip: 'Next Video',
                             onPressed: _currentIndex < _playlist.length - 1 ? () {
                               _cancelAndRestartHideTimer();
                               _playIndex(_currentIndex + 1);
                             } : null,
                           ),
                           const SizedBox(width: 8),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Floating Overlay Skip Previous Button (Center-Left)
            if (_showControls && _currentIndex > 0)
              Positioned(
                left: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: IconButton(
                    iconSize: 44,
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: () {
                      _cancelAndRestartHideTimer();
                      _playIndex(_currentIndex - 1);
                    },
                  ),
                ),
              ),

            // Floating Overlay Skip Next Button (Center-Right)
            if (_showControls && _currentIndex < _playlist.length - 1)
              Positioned(
                right: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: IconButton(
                    iconSize: 44,
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: () {
                      _cancelAndRestartHideTimer();
                      _playIndex(_currentIndex + 1);
                    },
                  ),
                ),
              ),

            // Gestures UI feedback Overlay
            if (_showGestureIndicator)
              Center(
                child: AnimatedOpacity(
                  opacity: _showGestureIndicator ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_gestureIndicatorIcon, color: Colors.white, size: 44),
                        const SizedBox(height: 8),
                        Text(
                          _gestureIndicatorText,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
