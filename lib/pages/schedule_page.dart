import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_model.dart';
import '../core/models/anime_list_item.dart';
import '../core/services/jikan_service.dart';
import '../core/services/hive_service.dart';
import '../core/localization/app_text.dart';
import '../widgets/anime_card.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/error_state.dart';
import '../widgets/category_picker.dart';
import '../widgets/api_status_banner.dart';
import '../core/services/notification_service.dart';
import '../core/services/airing_schedule_service.dart';

class SchedulePage extends StatefulWidget {
  final void Function(int animeId) onSelectAnime;

  const SchedulePage({super.key, required this.onSelectAnime});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  bool _loading = false;
  String? _error;
  
  Map<int, List<AnimeModel>> _groupedSchedule = {};
  List<Map<String, dynamic>> _upcomingAnimes = [];
  String _sortMode = 'time'; // 'time' or 'score'

  // Saved Seasons & Active View State
  String? _activeSeasonKey; // e.g. '2026_summer' or null for current season
  List<String> _savedSeasonKeys = [];
  bool _hideFinished = false;
  List<AnimeModel> _currentSeasonAllAnime = [];
  String _scheduleViewMode = 'weekly'; // 'weekly' or 'grid'

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _savedSeasonKeys = HiveService.getAllSavedSeasonKeys();
    _fetchSeason();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTimer() {
    setState(() {
      _cooldownSeconds = 30;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds > 0) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  bool _isAnimeFinishedAiring(AnimeModel anime) {
    final status = anime.status.toLowerCase().trim();
    if (status.contains('finished') || status.contains('complete') || status.contains('ended')) {
      return true;
    }
    final countdown = AiringScheduleService.getCountdown(anime.id, status: anime.status);
    if (countdown.isFinished) {
      return true;
    }
    final totalEps = int.tryParse(anime.episodes);
    if (totalEps != null && totalEps > 0 && countdown.latestAiredEpisode != null && countdown.latestAiredEpisode! >= totalEps) {
      return true;
    }
    return false;
  }

  String _formatSeasonKey(String key) {
    if (!key.contains('_')) return key;
    final parts = key.split('_');
    final year = parts[0];
    final season = parts.length > 1 ? parts[1].toUpperCase() : '';
    return '$season $year';
  }

  int? _weekdayFromDayString(String day) {
    final d = day.toLowerCase();
    if (d.contains('mon')) return DateTime.monday;
    if (d.contains('tue')) return DateTime.tuesday;
    if (d.contains('wed')) return DateTime.wednesday;
    if (d.contains('thu')) return DateTime.thursday;
    if (d.contains('fri')) return DateTime.friday;
    if (d.contains('sat')) return DateTime.saturday;
    if (d.contains('sun')) return DateTime.sunday;
    return null;
  }

  int? _determineWeekday(AnimeModel anime) {
    // 1. Precise JST next broadcast if day and time are present
    if (anime.broadcastDay != null && anime.broadcastTime != null) {
      final local = _parseJstNextBroadcast(anime.broadcastDay!, anime.broadcastTime!);
      if (local != null) return local.weekday;
    }

    // 2. Day name from broadcastDay directly (e.g. "Saturdays", "Fridays")
    if (anime.broadcastDay != null && anime.broadcastDay!.trim().isNotEmpty) {
      final wd = _weekdayFromDayString(anime.broadcastDay!);
      if (wd != null) return wd;
    }

    // 3. AiredFrom / Start date (e.g. "2026-08-14" -> Friday)
    if (anime.airedFrom != null && anime.airedFrom!.trim().isNotEmpty) {
      try {
        final dt = DateTime.parse(anime.airedFrom!);
        return dt.weekday;
      } catch (_) {}
    }

    // 4. Unknown / TBA / Movie without specific day
    return null;
  }

  void _showFetchSeasonDialog() {
    final now = DateTime.now();
    int currentYear = now.year;
    String currentSeason;
    final m = now.month;
    if (m >= 1 && m <= 3) {
      currentSeason = 'winter';
    } else if (m >= 4 && m <= 6) {
      currentSeason = 'spring';
    } else if (m >= 7 && m <= 9) {
      currentSeason = 'summer';
    } else {
      currentSeason = 'fall';
    }

    final lastKey = _activeSeasonKey ?? HiveService.lastScheduleSeasonKey;
    if (lastKey != null && lastKey.contains('_')) {
      final parts = lastKey.split('_');
      final py = int.tryParse(parts[0]);
      if (py != null) currentYear = py;
      if (parts.length > 1) currentSeason = parts[1].toLowerCase();
    }

    int selectedYear = currentYear;
    String selectedSeason = currentSeason;
    bool saveToDataPage = true;
    bool isFetching = false;
    String? progressText;
    String? errorText;

    final yearController = TextEditingController(text: selectedYear.toString());
    final dropdownYears = List.generate(2030 - 1960 + 1, (i) => 2030 - i);

    showDialog(
      context: context,
      barrierDismissible: !isFetching,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: AppColors.accent, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppText.get('fetch_season_dialog_title'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Year section: Dropdown + Text Input from 1900s
                    Text(AppText.get('year'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int>(
                            value: dropdownYears.contains(selectedYear) ? selectedYear : null,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              hintText: 'Select Year',
                            ),
                            items: dropdownYears.map((y) {
                              return DropdownMenuItem<int>(
                                value: y,
                                child: Text(y.toString(), style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: isFetching
                                ? null
                                : (y) {
                                    if (y != null) {
                                      setDialogState(() {
                                        selectedYear = y;
                                        yearController.text = y.toString();
                                      });
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: yearController,
                            keyboardType: TextInputType.number,
                            enabled: !isFetching,
                            decoration: InputDecoration(
                              labelText: '1900+',
                              labelStyle: const TextStyle(fontSize: 11),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed != null && parsed >= 1900 && parsed <= 2100) {
                                setDialogState(() => selectedYear = parsed);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Season Chips
                    Text(AppText.get('season'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'id': 'winter', 'label': AppText.get('season_winter')},
                        {'id': 'spring', 'label': AppText.get('season_spring')},
                        {'id': 'summer', 'label': AppText.get('season_summer')},
                        {'id': 'fall', 'label': AppText.get('season_fall')},
                      ].map((s) {
                        final id = s['id']!;
                        final label = s['label']!;
                        final isSelected = selectedSeason == id;
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          selectedColor: AppColors.accent.withAlpha(50),
                          checkmarkColor: AppColors.accent,
                          onSelected: isFetching
                              ? null
                              : (_) {
                                  setDialogState(() => selectedSeason = id);
                                },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Save to Data Page switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppText.get('save_to_data_page'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(AppText.get('save_to_data_page_sub'), style: const TextStyle(fontSize: 11)),
                      value: saveToDataPage,
                      activeColor: AppColors.accent,
                      onChanged: isFetching ? null : (v) => setDialogState(() => saveToDataPage = v),
                    ),

                    if (isFetching) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(color: AppColors.accent),
                      const SizedBox(height: 8),
                      Text(
                        progressText ?? 'Gathering season data safely...',
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ],

                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isFetching ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isFetching
                      ? null
                      : () async {
                          setDialogState(() {
                            isFetching = true;
                            progressText = 'Starting safe seasonal fetch...';
                            errorText = null;
                          });

                          try {
                            final fetched = await JikanService.getSeasonByYearAndSeason(
                              year: selectedYear,
                              season: selectedSeason,
                              onProgress: (count, page) {
                                if (dialogCtx.mounted) {
                                  setDialogState(() {
                                    progressText = 'Gathering page $page... ($count anime loaded)';
                                  });
                                }
                              },
                            );

                            if (fetched.isNotEmpty) {
                              final seasonKey = '${selectedYear}_$selectedSeason';
                              final dataMapList = fetched.map((a) => a.toJson()).toList();

                              await HiveService.cacheSeasonAllPagesForSeason(seasonKey, dataMapList);
                              await HiveService.setLastScheduleSeasonKey(seasonKey);
                              _activeSeasonKey = seasonKey;

                              if (saveToDataPage) {
                                await HiveService.saveToAppData(fetched);
                              }

                              _applySeasonData(fetched);

                              if (dialogCtx.mounted) {
                                Navigator.of(dialogCtx).pop();
                              }

                              _startCooldownTimer();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${selectedSeason.toUpperCase()} $selectedYear - ${AppText.get('season_updated')} (${fetched.length} anime)'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            } else {
                              if (dialogCtx.mounted) {
                                setDialogState(() {
                                  isFetching = false;
                                  errorText = 'No anime found for ${selectedSeason.toUpperCase()} $selectedYear. Please verify the year/season or check your connection.';
                                });
                              }
                            }
                          } catch (e) {
                            if (dialogCtx.mounted) {
                              setDialogState(() {
                                isFetching = false;
                                errorText = 'Error: $e';
                              });
                            }
                          }
                        },
                  child: Text(AppText.get('fetch_button')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRefetchButton() {
    final hasCooldown = _cooldownSeconds > 0;
    return OutlinedButton.icon(
      onPressed: hasCooldown ? null : _showFetchSeasonDialog,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: hasCooldown ? Colors.grey : AppColors.accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(
        Icons.tune_rounded,
        size: 14,
        color: hasCooldown ? Colors.grey : AppColors.accent,
      ),
      label: Text(
        hasCooldown ? 'Fetch (${_cooldownSeconds}s)' : AppText.get('fetch_button'),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: hasCooldown ? Colors.grey : AppColors.accent,
        ),
      ),
    );
  }

  Future<void> _fetchSeason() async {
    setState(() { _loading = true; _error = null; });
    try {
      List<AnimeModel> data = [];

      // Check if user enabled saving last schedule fetch
      if (HiveService.saveLastScheduleFetch) {
        final lastKey = HiveService.lastScheduleSeasonKey;
        if (lastKey != null && lastKey.isNotEmpty) {
          final cached = HiveService.getCachedSeasonAllPagesForSeason(lastKey);
          if (cached != null && cached.isNotEmpty) {
            data = cached.map((m) => AnimeModel.fromJson(m)).toList();
            _activeSeasonKey = lastKey;
          }
        }
      }

      // If still empty, check default season cache
      if (data.isEmpty && HiveService.isSeasonAllPagesCacheValid()) {
        final cached = HiveService.getCachedSeasonAllPages();
        if (cached != null && cached.isNotEmpty) {
          data = cached.map((m) => AnimeModel.fromJson(m)).toList();
        }
      }

      // If still empty, fetch current season
      if (data.isEmpty) {
        data = await JikanService.getSeasonNow(limit: 25);
      }
      
      _applySeasonData(data);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadSavedSeason(String seasonKey) async {
    setState(() {
      _loading = true;
      _error = null;
      _activeSeasonKey = seasonKey;
    });

    final cached = HiveService.getCachedSeasonAllPagesForSeason(seasonKey);
    if (cached != null && cached.isNotEmpty) {
      final data = cached.map((m) => AnimeModel.fromJson(m)).toList();
      await HiveService.setLastScheduleSeasonKey(seasonKey);
      _applySeasonData(data);
    } else {
      setState(() {
        _loading = false;
        _error = "No saved data for $seasonKey";
      });
    }
  }

  Future<void> _loadCurrentLiveSeason() async {
    setState(() {
      _loading = true;
      _error = null;
      _activeSeasonKey = null;
    });
    try {
      final data = await JikanService.getSeasonNow(limit: 25);
      _applySeasonData(data);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applySeasonData(List<AnimeModel> data) {
    final now = DateTime.now();
    // Weekday buckets 1..7, plus 0 for Unscheduled / TBA / Other
    final Map<int, List<AnimeModel>> grouped = {
      1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: [], 0: [],
    };
    List<Map<String, dynamic>> upcoming = [];

    final Map<int, AnimeModel> uniqueDataMap = {};
    for (final a in data) {
      uniqueDataMap[a.id] = a;
    }
    final uniqueData = uniqueDataMap.values.toList();

    for (final anime in uniqueData) {
      // Only filter out finished airing if user explicitly enabled _hideFinished
      if (_hideFinished && _isAnimeFinishedAiring(anime)) {
        continue;
      }

      final weekday = _determineWeekday(anime);

      // Check upcoming for today's live countdown
      if (anime.broadcastDay != null && anime.broadcastTime != null) {
        final localTime = _parseJstNextBroadcast(anime.broadcastDay!, anime.broadcastTime!);
        if (localTime != null) {
          if (localTime.year == now.year && localTime.month == now.month && localTime.day == now.day) {
            if (localTime.isAfter(now) && !_isAnimeFinishedAiring(anime)) {
              upcoming.add({'anime': anime, 'time': localTime});
            }
          }
        }
      }

      if (weekday != null) {
        grouped[weekday]?.add(anime);
      } else {
        grouped[0]?.add(anime); // Put into Unscheduled / TBA
      }
    }

    _sortGroups(grouped, _sortMode);
    upcoming.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

    if (mounted) {
      setState(() {
        _groupedSchedule = grouped;
        _upcomingAnimes = upcoming;
        _currentSeasonAllAnime = uniqueData;
        _loading = false;
        _savedSeasonKeys = HiveService.getAllSavedSeasonKeys();
      });
    }
  }

  void _sortGroups(Map<int, List<AnimeModel>> grouped, String mode) {
     for (var key in grouped.keys) {
        grouped[key]!.sort((a, b) {
            if (mode == 'score') {
               final double sA = a.score ?? 0.0;
               final double sB = b.score ?? 0.0;
               return sB.compareTo(sA);
            } else {
               if (a.broadcastTime != null && b.broadcastTime != null) {
                 return a.broadcastTime!.compareTo(b.broadcastTime!);
               }
               if (a.broadcastTime != null) return -1;
               if (b.broadcastTime != null) return 1;
               // Fallback to score
               return (b.score ?? 0.0).compareTo(a.score ?? 0.0);
            }
        });
     }
  }

  DateTime? _parseJstNextBroadcast(String day, String time) {
     try {
       final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(time);
       if (timeMatch == null) return null; 
       
       int hour = int.parse(timeMatch.group(1)!);
       int minute = int.parse(timeMatch.group(2)!);
       
       int extraDays = 0;
       if (hour >= 24) {
         hour -= 24;
         extraDays = 1;
       }
       
       int targetWeekday;
       final lowerDay = day.toLowerCase();
       if (lowerDay.contains('monday')) targetWeekday = DateTime.monday;
       else if (lowerDay.contains('tuesday')) targetWeekday = DateTime.tuesday;
       else if (lowerDay.contains('wednesday')) targetWeekday = DateTime.wednesday;
       else if (lowerDay.contains('thursday')) targetWeekday = DateTime.thursday;
       else if (lowerDay.contains('friday')) targetWeekday = DateTime.friday;
       else if (lowerDay.contains('saturday')) targetWeekday = DateTime.saturday;
       else if (lowerDay.contains('sunday')) targetWeekday = DateTime.sunday;
       else return null; 
       
       final nowUtc = DateTime.now().toUtc();
       final nowJst = nowUtc.add(const Duration(hours: 9)); 
       
       DateTime nextJst = DateTime.utc(nowJst.year, nowJst.month, nowJst.day, hour, minute);
       nextJst = nextJst.add(Duration(days: extraDays));
       
       while (nextJst.weekday != targetWeekday) {
         nextJst = nextJst.add(const Duration(days: 1));
       }
       
       if (nextJst.isBefore(nowJst)) {
         nextJst = nextJst.add(const Duration(days: 7));
       }
       
       final nextUtc = nextJst.subtract(const Duration(hours: 9));
       return nextUtc.toLocal();
     } catch (_) {
       return null;
     }
  }

  String _getDayName(int day) {
    switch (day) {
      case DateTime.monday: return AppText.get('monday');
      case DateTime.tuesday: return AppText.get('tuesday');
      case DateTime.wednesday: return AppText.get('wednesday');
      case DateTime.thursday: return AppText.get('thursday');
      case DateTime.friday: return AppText.get('friday');
      case DateTime.saturday: return AppText.get('saturday');
      case DateTime.sunday: return AppText.get('sunday');
      case 0: return 'Other / TBA / Movies';
      default: return '';
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return "Air time reached!";
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return "${hours}h ${minutes}m left";
    }
    return "${minutes}m left";
  }

  Future<void> _handleAddToList(AnimeModel anime) async {
    final existing = HiveService.getListItem(anime.id);
    final result = await CategoryPickerSheet.show(context, current: existing?.category);
    if (result == null || !mounted) return;
    switch (result) {
      case CategorySelected(:final category):
        if (existing != null) {
          await HiveService.updateCategory(anime.id, category);
        } else {
          await HiveService.addToList(AnimeListItem.fromAnime(anime, category));
        }
      case DeleteFromList():
        final removedItem = existing;
        await HiveService.removeFromList(anime.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${anime.title} - ${AppText.get('item_removed')}'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              action: SnackBarAction(
                label: AppText.get('undo'),
                textColor: AppColors.accent,
                onPressed: () async {
                  if (removedItem != null) {
                    await HiveService.addToList(removedItem);
                    if (mounted) setState(() {});
                  }
                },
              ),
            ),
          );
        }
    }
    setState(() {});
  }
  Widget _buildNextAnimeSection() {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     final next = _upcomingAnimes.first;
     final AnimeModel anime = next['anime'];
     final DateTime time = next['time'];
     final diff = time.difference(DateTime.now());
     final hasAlert = HiveService.hasAlertEnabled(anime.id);

     final timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

     return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppColors.accent, size: 16),
                const SizedBox(width: 4),
                Text(
                  AppText.get('airing_next_today'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => widget.onSelectAnime(anime.id),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent.withAlpha(80)),
                ),
                child: Row(
                  children: [
                     ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                           anime.image,
                           width: 60,
                           height: 80,
                           fit: BoxFit.cover,
                           errorBuilder: (_, __, ___) => Container(width: 60, height: 80, color: Colors.grey),
                        ),
                     ),
                     const SizedBox(width: 12),
                     Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anime.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                 Icon(Icons.access_time_rounded, size: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                 const SizedBox(width: 4),
                                 Text(
                                   timeStr,
                                   style: TextStyle(
                                     fontSize: 12,
                                     color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                   ),
                                 ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                               decoration: BoxDecoration(
                                 color: AppColors.accent.withAlpha(30),
                                 borderRadius: BorderRadius.circular(6),
                               ),
                               child: Text(
                                 _formatDuration(diff),
                                 style: TextStyle(
                                   fontSize: 11,
                                   fontWeight: FontWeight.bold,
                                   color: AppColors.accent,
                                 ),
                               ),
                            ),
                          ],
                        ),
                     ),
                     IconButton(
                       icon: Icon(
                         hasAlert ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                         color: hasAlert ? AppColors.starYellow : (isDark ? Colors.white70 : Colors.black54),
                       ),
                       onPressed: () async {
                          final newStatus = !hasAlert;
                          await HiveService.setAlertEnabled(anime.id, newStatus);
                          if (newStatus) {
                            await NotificationService.subscribeToAnime(anime.id);
                          } else {
                            await NotificationService.unsubscribeFromAnime(anime.id);
                          }
                          setState(() {});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(newStatus ? 'Airing alerts enabled!' : 'Airing alerts disabled!'),
                                backgroundColor: newStatus ? Colors.green : Colors.black87,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                       },
                     ),
                  ],
                ),
              ),
            ),
          ],
        ),
     );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now().weekday;
    final orderedDays = [today];
    for (int i = 1; i < 7; i++) {
        int next = today + i;
        if (next > 7) next -= 7;
        orderedDays.add(next);
    }
    // Also include day 0 if there are unscheduled or TBA anime
    if (_groupedSchedule[0] != null && _groupedSchedule[0]!.isNotEmpty) {
      orderedDays.add(0);
    }

    final activeTitle = _activeSeasonKey != null
        ? _formatSeasonKey(_activeSeasonKey!)
        : 'Current Season';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Responsive Header (No Overflow!) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppText.get('weekly_schedule'), 
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        activeTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  )
                else
                  _buildRefetchButton(),
              ],
            ),
          ),
        ),

        // ── Seasonal Quick-Switcher Chips Bar ──
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ChoiceChip(
                  label: const Text("Current Season", style: TextStyle(fontSize: 12)),
                  selected: _activeSeasonKey == null,
                  onSelected: (_) => _loadCurrentLiveSeason(),
                  selectedColor: AppColors.accent.withAlpha(50),
                  checkmarkColor: AppColors.accent,
                ),
                const SizedBox(width: 8),
                ..._savedSeasonKeys.map((key) {
                  final isSelected = _activeSeasonKey == key;
                  final title = _formatSeasonKey(key);
                  final count = HiveService.getCachedSeasonAllPagesForSeason(key)?.length ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InputChip(
                      label: Text("$title ($count)", style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (_) => _loadSavedSeason(key),
                      selectedColor: AppColors.accent.withAlpha(50),
                      checkmarkColor: AppColors.accent,
                      onDeleted: () async {
                        await HiveService.deleteSavedSeason(key);
                        setState(() {
                          _savedSeasonKeys = HiveService.getAllSavedSeasonKeys();
                          if (_activeSeasonKey == key) {
                            _loadCurrentLiveSeason();
                          }
                        });
                      },
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      deleteIconColor: isSelected ? AppColors.accent : Colors.grey,
                    ),
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 14),
                  label: const Text("Fetch Season", style: TextStyle(fontSize: 12)),
                  onPressed: _showFetchSeasonDialog,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text("Hide Finished", style: TextStyle(fontSize: 12)),
                  selected: _hideFinished,
                  onSelected: (v) {
                    setState(() {
                      _hideFinished = v;
                      if (_activeSeasonKey != null) {
                        _loadSavedSeason(_activeSeasonKey!);
                      } else {
                        _fetchSeason();
                      }
                    });
                  },
                  selectedColor: AppColors.accent.withAlpha(40),
                  checkmarkColor: AppColors.accent,
                ),
              ],
            ),
          ),
        ),

        // ── Season Statistics & View Switcher Bar ──
        if (!_loading && _groupedSchedule.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.movie_filter_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_currentSeasonAllAnime.length} Anime'
                      '${_groupedSchedule[0]?.isNotEmpty == true ? ' (${_currentSeasonAllAnime.length - (_groupedSchedule[0]?.length ?? 0)} on schedule, ${_groupedSchedule[0]?.length} TBA/Other)' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _scheduleViewMode = _scheduleViewMode == 'weekly' ? 'grid' : 'weekly';
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _scheduleViewMode == 'weekly' ? Icons.grid_view_rounded : Icons.calendar_view_week_rounded,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _scheduleViewMode == 'weekly' ? 'View Grid' : 'View Schedule',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (!_loading && _upcomingAnimes.isNotEmpty) _buildNextAnimeSection(),

        // ── API Status Banner ──
        ValueListenableBuilder<bool>(
          valueListenable: JikanService.usingCachedData,
          builder: (context, usingCached, _) {
            if (!usingCached) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ApiStatusBanner(
                onRetry: _fetchSeason,
              ),
            );
          },
        ),

        Expanded(
          child: _loading
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: ShimmerLoading.cardGrid(count: 6, context: context),
                )
              : _error != null
                  ? ErrorStateWidget(message: _error, onRetry: _fetchSeason)
                  : RefreshIndicator(
                      color: AppColors.accent,
                      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : Colors.white,
                      onRefresh: () => _fetchSeason(),
                      child: _groupedSchedule.isNotEmpty
                          ? (_scheduleViewMode == 'grid'
                              ? _buildGridSchedule()
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 100),
                                  itemCount: orderedDays.length,
                                  itemBuilder: (context, index) {
                                     final day = orderedDays[index];
                                     final list = _groupedSchedule[day];
                                     if (list == null || list.isEmpty) return const SizedBox.shrink();

                                     final dayTitle = day == 0
                                         ? "Other / TBA / Movies"
                                         : (day == today ? "${AppText.get('today')} - ${_getDayName(day)}" : _getDayName(day));
                                     
                                     return Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Padding(
                                           padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                                           child: Row(
                                             children: [
                                               Container(
                                                 width: 4,
                                                 height: 18,
                                                 decoration: BoxDecoration(
                                                   color: day == 0 ? Colors.grey : AppColors.accent,
                                                   borderRadius: BorderRadius.circular(2),
                                                 ),
                                               ),
                                               const SizedBox(width: 8),
                                               Text(
                                                 dayTitle,
                                                 style: TextStyle(
                                                   color: isDark ? Colors.white : Colors.black87,
                                                   fontWeight: FontWeight.w900,
                                                   fontSize: 15,
                                                 ),
                                               ),
                                               const SizedBox(width: 8),
                                               Container(
                                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                 decoration: BoxDecoration(
                                                   color: (day == 0 ? Colors.grey : AppColors.accent).withAlpha(40),
                                                   borderRadius: BorderRadius.circular(10),
                                                 ),
                                                 child: Text(
                                                   '${list.length}',
                                                   style: TextStyle(
                                                     fontSize: 11,
                                                     fontWeight: FontWeight.bold,
                                                     color: day == 0 ? Colors.grey : AppColors.accent,
                                                   ),
                                                 ),
                                               ),
                                             ],
                                           ),
                                         ),
                                         SizedBox(
                                           height: 260, 
                                           child: ListView.builder(
                                             scrollDirection: Axis.horizontal,
                                             padding: const EdgeInsets.symmetric(horizontal: 16),
                                             itemCount: list.length,
                                             itemBuilder: (context, idx) {
                                               final anime = list[idx];
                                               final hasAlert = HiveService.hasAlertEnabled(anime.id);
                                               return Container(
                                                 width: 140,
                                                 margin: const EdgeInsets.symmetric(horizontal: 6),
                                                 child: Stack(
                                                   children: [
                                                     AnimeCard(
                                                       anime: anime,
                                                       onTap: () => widget.onSelectAnime(anime.id),
                                                       onAdd: () => _handleAddToList(anime),
                                                       isInList: HiveService.isInList(anime.id),
                                                     ),
                                                     Positioned(
                                                       top: 42,
                                                       left: 8,
                                                       child: GestureDetector(
                                                         onTap: () async {
                                                           final newStatus = !hasAlert;
                                                           await HiveService.setAlertEnabled(anime.id, newStatus);
                                                           if (newStatus) {
                                                             await NotificationService.subscribeToAnime(anime.id);
                                                           } else {
                                                             await NotificationService.unsubscribeFromAnime(anime.id);
                                                           }
                                                           setState(() {});
                                                           if (context.mounted) {
                                                             ScaffoldMessenger.of(context).showSnackBar(
                                                               SnackBar(
                                                                 content: Text(newStatus ? 'Airing alerts enabled!' : 'Airing alerts disabled!'),
                                                                 backgroundColor: newStatus ? Colors.green : Colors.black87,
                                                                 duration: const Duration(seconds: 1),
                                                               ),
                                                             );
                                                           }
                                                         },
                                                         child: Container(
                                                           padding: const EdgeInsets.all(6),
                                                           decoration: BoxDecoration(
                                                             color: Colors.black.withAlpha(120),
                                                             shape: BoxShape.circle,
                                                             border: Border.all(color: Colors.white.withAlpha(25)),
                                                           ),
                                                           child: Icon(
                                                             hasAlert ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                                                             color: hasAlert ? AppColors.starYellow : Colors.white,
                                                             size: 16,
                                                           ),
                                                         ),
                                                       ),
                                                     ),
                                                   ],
                                                 ),
                                               );
                                             },
                                           ),
                                         ),
                                         const SizedBox(height: 8),
                                       ],
                                     );
                                  },
                                ))
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 48, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                                      const SizedBox(height: 12),
                                      Text(
                                        AppText.get('no_schedule'),
                                        style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
        ),
      ],
    );
  }

  Widget _buildGridSchedule() {
    final list = _currentSeasonAllAnime.isNotEmpty
        ? (_hideFinished
            ? _currentSeasonAllAnime.where((a) => !_isAnimeFinishedAiring(a)).toList()
            : List<AnimeModel>.from(_currentSeasonAllAnime))
        : _groupedSchedule.values.expand((x) => x).toList();

    if (_sortMode == 'score') {
      list.sort((a, b) => (b.score ?? 0.0).compareTo(a.score ?? 0.0));
    }

    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Icon(Icons.calendar_today_outlined, size: 48, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextHint : AppColors.lightTextHint),
                const SizedBox(height: 12),
                Text(
                  AppText.get('no_schedule'),
                  style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.65,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final anime = list[index];
        final hasAlert = HiveService.hasAlertEnabled(anime.id);
        return Stack(
          children: [
            AnimeCard(
              anime: anime,
              onTap: () => widget.onSelectAnime(anime.id),
              onAdd: () => _handleAddToList(anime),
              isInList: HiveService.isInList(anime.id),
            ),
            Positioned(
              top: 42,
              left: 8,
              child: GestureDetector(
                onTap: () async {
                  final newStatus = !hasAlert;
                  await HiveService.setAlertEnabled(anime.id, newStatus);
                  if (newStatus) {
                    await NotificationService.subscribeToAnime(anime.id);
                  } else {
                    await NotificationService.unsubscribeFromAnime(anime.id);
                  }
                  setState(() {});
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(newStatus ? 'Airing alerts enabled!' : 'Airing alerts disabled!'),
                        backgroundColor: newStatus ? Colors.green : Colors.black87,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(120),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(25)),
                  ),
                  child: Icon(
                    hasAlert ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                    color: hasAlert ? AppColors.starYellow : Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
