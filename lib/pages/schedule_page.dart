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

  // Multi-Season Selection & Active View State
  Set<String> _selectedSeasonKeys = {'current'};
  String? get _activeSeasonKey => _selectedSeasonKeys.length == 1 && !_selectedSeasonKeys.contains('current') ? _selectedSeasonKeys.first : null;
  List<String> _savedSeasonKeys = [];
  List<AnimeModel> _rawCombinedSeasonAnime = [];
  List<AnimeModel> _currentSeasonAllAnime = [];

  // Hide Filters
  bool _hideFinished = false;
  bool _hideWatching = false;
  bool _hideIgnored = false;
  bool _hidePlanned = false;

  String _scheduleViewMode = 'weekly'; // 'weekly', 'grid', or 'list'
  final ScrollController _timelineScrollController = ScrollController();

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  Timer? _countdownTimer;

  int get _activeHideFilterCount {
    int count = 0;
    if (_hideFinished) count++;
    if (_hideWatching) count++;
    if (_hideIgnored) count++;
    if (_hidePlanned) count++;
    return count;
  }

  String _getSeasonSelectionLabel() {
    if (_selectedSeasonKeys.isEmpty) return 'Select Season';
    if (_selectedSeasonKeys.length == 1) {
      final key = _selectedSeasonKeys.first;
      if (key == 'current') return 'Current Season';
      return _formatSeasonKey(key);
    }
    return '${_selectedSeasonKeys.length} Seasons Selected';
  }

  @override
  void initState() {
    super.initState();
    _savedSeasonKeys = HiveService.getAllSavedSeasonKeys();
    if (HiveService.saveLastScheduleFetch) {
      final lastKey = HiveService.lastScheduleSeasonKey;
      if (lastKey != null && lastKey.isNotEmpty && _savedSeasonKeys.contains(lastKey)) {
        _selectedSeasonKeys = {lastKey};
      }
    }
    _reloadSelectedSeasons();
    HiveService.exclusionsRevision.addListener(_onExclusionsChanged);
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    HiveService.exclusionsRevision.removeListener(_onExclusionsChanged);
    _cooldownTimer?.cancel();
    _countdownTimer?.cancel();
    _timelineScrollController.dispose();
    super.dispose();
  }

  void _onExclusionsChanged() {
    if (mounted && _rawCombinedSeasonAnime.isNotEmpty) {
      _applySeasonData(_rawCombinedSeasonAnime);
    }
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
    String season = parts.length > 1 ? parts[1].toLowerCase() : '';
    if (season.isNotEmpty) {
      season = season[0].toUpperCase() + season.substring(1);
    }
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
              backgroundColor: isDark ? const Color(0xFF1E2230) : Colors.white,
              surfaceTintColor: Colors.transparent,
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
                      activeTrackColor: AppColors.accent,
                      activeThumbColor: Colors.white,
                      inactiveTrackColor: isDark ? const Color(0xFF282D3D) : const Color(0xFFCBD5E1),
                      inactiveThumbColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
                              _selectedSeasonKeys = {seasonKey};
                              _savedSeasonKeys = HiveService.getAllSavedSeasonKeys();

                              if (saveToDataPage) {
                                await HiveService.saveToAppData(fetched);
                              }

                              _rawCombinedSeasonAnime = fetched;
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

  void _showSeasonSelectionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Set<String> tempSelected = Set.from(_selectedSeasonKeys);
    List<String> currentSavedKeys = HiveService.getAllSavedSeasonKeys();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? const Color(0xFF1B1E2B) : Colors.white,
              surfaceTintColor: Colors.transparent,
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(isDark ? 40 : 25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.calendar_month_rounded, color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Select Seasons',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Select All / Clear action pills
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                tempSelected.add('current');
                                tempSelected.addAll(currentSavedKeys);
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withAlpha(isDark ? 30 : 20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.select_all_rounded, size: 14, color: AppColors.accent),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Select All',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                tempSelected.clear();
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.clear_all_rounded, size: 14, color: isDark ? Colors.white60 : Colors.black54),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Clear',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF2B3045) : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.42,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Current Season Item
                            _buildSeasonDialogTile(
                              title: 'Current Season',
                              subtitle: 'Live airing broadcast schedule',
                              isSelected: tempSelected.contains('current'),
                              isDark: isDark,
                              onToggle: () {
                                setDialogState(() {
                                  if (tempSelected.contains('current')) {
                                    tempSelected.remove('current');
                                  } else {
                                    tempSelected.add('current');
                                  }
                                });
                              },
                            ),
                            ...currentSavedKeys.map((key) {
                              final title = _formatSeasonKey(key);
                              final count = HiveService.getCachedSeasonAllPagesForSeason(key)?.length ?? 0;
                              return _buildSeasonDialogTile(
                                title: title,
                                subtitle: '$count anime cached',
                                isSelected: tempSelected.contains(key),
                                isDark: isDark,
                                onDelete: () async {
                                  await HiveService.deleteSavedSeason(key);
                                  final updated = HiveService.getAllSavedSeasonKeys();
                                  setDialogState(() {
                                    currentSavedKeys = updated;
                                    tempSelected.remove(key);
                                  });
                                  setState(() {
                                    _savedSeasonKeys = updated;
                                  });
                                },
                                onToggle: () {
                                  setDialogState(() {
                                    if (tempSelected.contains(key)) {
                                      tempSelected.remove(key);
                                    } else {
                                      tempSelected.add(key);
                                    }
                                  });
                                },
                              );
                            }),
                            if (currentSavedKeys.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                child: Text(
                                  'Use "Fetch Season" to download and save past or future seasons.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _cooldownSeconds > 0
                          ? null
                          : () {
                              Navigator.of(dialogCtx).pop();
                              _showFetchSeasonDialog();
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(
                          color: _cooldownSeconds > 0
                              ? (isDark ? Colors.white24 : Colors.black26)
                              : AppColors.accent,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(
                        Icons.cloud_download_outlined,
                        size: 15,
                        color: _cooldownSeconds > 0 ? Colors.grey : AppColors.accent,
                      ),
                      label: Text(
                        _cooldownSeconds > 0 ? 'Fetch (${_cooldownSeconds}s)' : 'Fetch Season',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _cooldownSeconds > 0 ? Colors.grey : AppColors.accent,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (tempSelected.isEmpty) {
                          tempSelected.add('current');
                        }
                        setState(() {
                          _selectedSeasonKeys = Set.from(tempSelected);
                        });
                        Navigator.of(dialogCtx).pop();
                        _reloadSelectedSeasons();
                      },
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSeasonDialogTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onToggle,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.accent.withAlpha(isDark ? 35 : 20)
            : (isDark ? const Color(0xFF222638) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.accent
              : (isDark ? const Color(0xFF2E344A) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.4 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggle(),
                    activeColor: AppColors.accent,
                    checkColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.accent
                          : (isDark ? Colors.white38 : Colors.black38),
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? (isDark ? Colors.white : AppColors.accent)
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: Colors.redAccent.withAlpha(200),
                    tooltip: 'Delete cached season',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showScheduleFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool tempHideFinished = _hideFinished;
    bool tempHideWatching = _hideWatching;
    bool tempHideIgnored = _hideIgnored;
    bool tempHidePlanned = _hidePlanned;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              backgroundColor: isDark ? const Color(0xFF1E2230) : Colors.white,
              surfaceTintColor: Colors.transparent,
              title: Row(
                children: [
                  Icon(Icons.tune_rounded, color: AppColors.accent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Schedule Filters',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: Text(
                        'Hide Finished Airing',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                      ),
                      subtitle: Text(
                        'Exclude anime that have ended broadcasting',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                      value: tempHideFinished,
                      activeColor: AppColors.accent,
                      checkColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setDialogState(() => tempHideFinished = v ?? false),
                    ),
                    CheckboxListTile(
                      title: Text(
                        'Hide Currently Watching',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                      ),
                      subtitle: Text(
                        'Exclude anime in your Watching list',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                      value: tempHideWatching,
                      activeColor: AppColors.accent,
                      checkColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setDialogState(() => tempHideWatching = v ?? false),
                    ),
                    CheckboxListTile(
                      title: Text(
                        'Hide Ignored',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                      ),
                      subtitle: Text(
                        'Exclude anime marked as Ignored / Dropped',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                      value: tempHideIgnored,
                      activeColor: AppColors.accent,
                      checkColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setDialogState(() => tempHideIgnored = v ?? false),
                    ),
                    CheckboxListTile(
                      title: Text(
                        'Hide Planned',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                      ),
                      subtitle: Text(
                        'Exclude anime marked as Plan to Watch',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                      value: tempHidePlanned,
                      activeColor: AppColors.accent,
                      checkColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setDialogState(() => tempHidePlanned = v ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      tempHideFinished = false;
                      tempHideWatching = false;
                      tempHideIgnored = false;
                      tempHidePlanned = false;
                    });
                  },
                  child: Text(
                    'Reset',
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    setState(() {
                      _hideFinished = tempHideFinished;
                      _hideWatching = tempHideWatching;
                      _hideIgnored = tempHideIgnored;
                      _hidePlanned = tempHidePlanned;
                    });
                    Navigator.of(dialogCtx).pop();
                    _applySeasonData(_rawCombinedSeasonAnime);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _fetchSeason() async {
    await _reloadSelectedSeasons();
  }


  Future<void> _reloadSelectedSeasons() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Map<int, AnimeModel> combined = {};

      if (_selectedSeasonKeys.contains('current')) {
        List<AnimeModel> currentData = [];
        if (HiveService.isSeasonAllPagesCacheValid()) {
          final cached = HiveService.getCachedSeasonAllPages();
          if (cached != null && cached.isNotEmpty) {
            currentData = cached.map((m) => AnimeModel.fromJson(m)).toList();
          }
        }
        if (currentData.isEmpty) {
          currentData = await JikanService.getSeasonNow(limit: 25);
        }
        for (final a in currentData) {
          combined[a.id] = a;
        }
      }

      for (final key in _selectedSeasonKeys) {
        if (key == 'current') continue;
        final cached = HiveService.getCachedSeasonAllPagesForSeason(key);
        if (cached != null) {
          for (final m in cached) {
            final a = AnimeModel.fromJson(m);
            combined[a.id] = a;
          }
        }
      }

      _rawCombinedSeasonAnime = combined.values.toList();
      _applySeasonData(_rawCombinedSeasonAnime);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _applySeasonData(List<AnimeModel> data) {
    final now = AiringScheduleService.nowInTargetTimezone();
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
    final List<AnimeModel> filteredData = [];

    for (final anime in uniqueData) {
      // 0. Excluded Categories Filter
      if (HiveService.isExcluded(genres: anime.genres, rating: anime.rating, type: anime.type)) {
        continue;
      }

      // 1. Hide Finished Airing
      if (_hideFinished && _isAnimeFinishedAiring(anime)) {
        continue;
      }

      // Check user list category
      final listItem = HiveService.getListItem(anime.id);
      if (listItem != null) {
        // 2. Hide Currently Watching
        if (_hideWatching && listItem.category == AnimeCategory.watching) {
          continue;
        }
        // 3. Hide Ignored
        if (_hideIgnored && listItem.category == AnimeCategory.ignored) {
          continue;
        }
        // 4. Hide Planned
        if (_hidePlanned && listItem.category == AnimeCategory.planned) {
          continue;
        }
      }

      filteredData.add(anime);

      final weekday = _determineWeekday(anime);

      // Check upcoming for today's live countdown and timeline
      if (anime.broadcastDay != null && anime.broadcastTime != null) {
        final localTime = _parseJstNextBroadcast(anime.broadcastDay!, anime.broadcastTime!);
        if (localTime != null) {
          if (localTime.year == now.year && localTime.month == now.month && localTime.day == now.day) {
            upcoming.add({
              'anime': anime,
              'time': localTime,
              'isPast': localTime.isBefore(now),
            });
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
        _currentSeasonAllAnime = filteredData;
        _loading = false;
        _savedSeasonKeys = HiveService.getAllSavedSeasonKeys();
      });
      _scrollToNextAiring();
    }
  }

  void _scrollToNextAiring() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_timelineScrollController.hasClients || _upcomingAnimes.isEmpty) return;
      final now = AiringScheduleService.nowInTargetTimezone();
      int targetIdx = _upcomingAnimes.indexWhere((item) => (item['time'] as DateTime).isAfter(now));
      if (targetIdx == -1) targetIdx = 0;

      const itemWidth = 240.0;
      const itemMargin = 10.0;
      final screenWidth = MediaQuery.of(context).size.width;
      final offset = (targetIdx * (itemWidth + itemMargin)) - (screenWidth / 2) + (itemWidth / 2) + 16.0;
      final maxScroll = _timelineScrollController.position.maxScrollExtent;
      final clamped = offset.clamp(0.0, maxScroll);

      _timelineScrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
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
    return AiringScheduleService.parseJstNextBroadcast(day, time);
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
    if (_upcomingAnimes.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = AiringScheduleService.nowInTargetTimezone();
    final nextIndex = _upcomingAnimes.indexWhere((item) => (item['time'] as DateTime).isAfter(now));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
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
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_upcomingAnimes.length} Today',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 108,
            child: ListView.builder(
              controller: _timelineScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _upcomingAnimes.length,
              itemBuilder: (context, index) {
                final item = _upcomingAnimes[index];
                final AnimeModel anime = item['anime'];
                final DateTime time = item['time'];
                final isPast = time.isBefore(now);
                final isNext = index == nextIndex;
                final diff = time.difference(now);
                final hasAlert = HiveService.hasAlertEnabled(anime.id);

                final timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

                return Container(
                  width: 240,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  child: Opacity(
                    opacity: isPast ? 0.52 : 1.0,
                    child: InkWell(
                      onTap: () => widget.onSelectAnime(anime.id),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isNext
                                ? AppColors.accent
                                : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                            width: isNext ? 1.6 : 1.0,
                          ),
                          boxShadow: isNext
                              ? [
                                  BoxShadow(
                                    color: AppColors.accent.withAlpha(35),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                anime.image,
                                width: 56,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 56, height: 90, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    anime.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 11,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPast
                                          ? (isDark ? Colors.white10 : Colors.black12)
                                          : (isNext ? AppColors.accent : AppColors.accent.withAlpha(35)),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      isPast
                                          ? 'Aired'
                                          : (isNext ? 'Next: ${_formatDuration(diff)}' : _formatDuration(diff)),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isPast
                                            ? (isDark ? Colors.white60 : Colors.black54)
                                            : (isNext ? Colors.white : AppColors.accent),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              iconSize: 18,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              icon: Icon(
                                hasAlert ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                                color: hasAlert ? AppColors.starYellow : (isDark ? Colors.white60 : Colors.black45),
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = AiringScheduleService.nowInTargetTimezone().weekday;
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

    final activeTitle = _getSeasonSelectionLabel();

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
                  _buildHeaderModeSwitcher(isDark),
              ],
            ),
          ),
        ),

        // ── Season Multi-Select & Filter Bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              // Season Multi-Select Button
              Expanded(
                child: InkWell(
                  onTap: _showSeasonSelectionDialog,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getSeasonSelectionLabel(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Filter Dialog Button
              InkWell(
                onTap: _showScheduleFilterDialog,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _activeHideFilterCount > 0
                        ? AppColors.accent.withAlpha(isDark ? 50 : 30)
                        : (isDark ? AppColors.darkCard : AppColors.lightCard),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _activeHideFilterCount > 0
                          ? AppColors.accent
                          : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: _activeHideFilterCount > 0 ? AppColors.accent : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _activeHideFilterCount > 0 ? AppColors.accent : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      if (_activeHideFilterCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_activeHideFilterCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (_activeHideFilterCount > 0) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  tooltip: 'Clear filters',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    setState(() {
                      _hideFinished = false;
                      _hideWatching = false;
                      _hideIgnored = false;
                      _hidePlanned = false;
                    });
                    _applySeasonData(_rawCombinedSeasonAnime);
                  },
                ),
              ],
            ],
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
                              : _scheduleViewMode == 'list'
                                  ? _buildListSchedule()
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
    final list = List<AnimeModel>.from(_currentSeasonAllAnime);

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

  Widget _buildHeaderModeSwitcher(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeIconBtn(
            icon: Icons.calendar_view_week_rounded,
            mode: 'weekly',
            tooltip: 'Schedule Mode',
            isDark: isDark,
          ),
          const SizedBox(width: 2),
          _buildModeIconBtn(
            icon: Icons.grid_view_rounded,
            mode: 'grid',
            tooltip: 'Grid Mode',
            isDark: isDark,
          ),
          const SizedBox(width: 2),
          _buildModeIconBtn(
            icon: Icons.format_list_bulleted_rounded,
            mode: 'list',
            tooltip: 'List Mode',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildModeIconBtn({
    required IconData icon,
    required String mode,
    required String tooltip,
    required bool isDark,
  }) {
    final isSelected = _scheduleViewMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          if (_scheduleViewMode != mode) {
            setState(() {
              _scheduleViewMode = mode;
            });
          }
        },
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildListSchedule() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = List<AnimeModel>.from(_currentSeasonAllAnime);

    if (_sortMode == 'score') {
      list.sort((a, b) => (b.score ?? 0.0).compareTo(a.score ?? 0.0));
    } else {
      list.sort((a, b) {
        if (a.broadcastTime != null && b.broadcastTime != null) {
          return a.broadcastTime!.compareTo(b.broadcastTime!);
        }
        if (a.broadcastTime != null) return -1;
        if (b.broadcastTime != null) return 1;
        return (b.score ?? 0.0).compareTo(a.score ?? 0.0);
      });
    }

    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 48,
                  color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                ),
                const SizedBox(height: 12),
                Text(
                  AppText.get('no_schedule'),
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final anime = list[index];
        final hasAlert = HiveService.hasAlertEnabled(anime.id);
        final inList = HiveService.isInList(anime.id);

        String? broadcastStr;
        if (anime.broadcastDay != null && anime.broadcastTime != null) {
          final local = AiringScheduleService.parseJstNextBroadcast(anime.broadcastDay!, anime.broadcastTime!);
          if (local != null) {
            final dayName = _getDayName(local.weekday);
            final timeStr = "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
            broadcastStr = "$dayName $timeStr";
          } else {
            broadcastStr = "${anime.broadcastDay} ${anime.broadcastTime}";
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () => widget.onSelectAnime(anime.id),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      anime.image,
                      width: 75,
                      height: 105,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 75,
                        height: 105,
                        color: Colors.grey,
                        child: const Icon(Icons.broken_image, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          anime.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            if (anime.score != null && anime.score! > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.starYellow.withAlpha(35),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 12, color: AppColors.starYellow),
                                    const SizedBox(width: 2),
                                    Text(
                                      anime.score!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.starYellow,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (anime.episodes.isNotEmpty && anime.episodes != '?') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black12,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '${anime.episodes} eps',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                        if (broadcastStr != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                broadcastStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (anime.synopsis.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            anime.synopsis,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Icon(
                          inList ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                          color: inList ? AppColors.accent : (isDark ? Colors.white60 : Colors.black45),
                        ),
                        onPressed: () => _handleAddToList(anime),
                      ),
                      IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Icon(
                          hasAlert ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                          color: hasAlert ? AppColors.starYellow : (isDark ? Colors.white60 : Colors.black45),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
