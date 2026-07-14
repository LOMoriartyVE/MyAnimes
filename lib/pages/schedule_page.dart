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

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
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

  Future<void> _refetchSchedule() async {
    if (_cooldownSeconds > 0) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await JikanService.getSeasonNowAllPages();
      
      if (data.isNotEmpty) {
        final dataMapList = data.map((a) => {
          'mal_id': a.id,
          'title': a.title,
          'title_japanese': a.japaneseTitle,
          'images': {'jpg': {'large_image_url': a.image}},
          'score': a.score,
          'synopsis': a.synopsis,
          'broadcast': {
            'day': a.broadcastDay,
            'time': a.broadcastTime,
          },
          'genres': a.genres.map((g) => {'name': g}).toList(),
          'status': a.status,
          'episodes': a.episodes != null ? int.tryParse(a.episodes!) : null,
        }).toList();
        await HiveService.cacheSeasonAllPages(dataMapList);
      }
      
      _startCooldownTimer();
      await _fetchSeason();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Refetch failed: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  Widget _buildRefetchButton() {
    final hasCooldown = _cooldownSeconds > 0;
    return TextButton.icon(
      onPressed: hasCooldown ? null : _refetchSchedule,
      icon: Icon(
        Icons.sync_rounded,
        size: 16,
        color: hasCooldown ? Colors.grey : AppColors.accent,
      ),
      label: Text(
        hasCooldown ? 'Refetch ($_cooldownSeconds s)' : 'Refetch',
        style: TextStyle(
          fontSize: 13,
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

      // 1. Try to load from cache first
      if (HiveService.isSeasonAllPagesCacheValid()) {
        final cached = HiveService.getCachedSeasonAllPages();
        if (cached != null && cached.isNotEmpty) {
          
          data = cached.map((m) => AnimeModel.fromJson(m)).toList();
        }
      }

      // 2. If cache is empty/invalid, fetch from API
      if (data.isEmpty) {
        data = await JikanService.getSeasonNow(limit: 25);
      }
      
      final now = DateTime.now();
      final Map<int, List<AnimeModel>> grouped = {};
      List<Map<String, dynamic>> upcoming = [];
      
      final Map<int, AnimeModel> uniqueDataMap = {};
      for (final a in data) { uniqueDataMap[a.id] = a; }
      final uniqueData = uniqueDataMap.values.toList();
      
      for (final anime in uniqueData) {
        int? weekday; // FIX: Start as null, no longer defaulting to 7
        DateTime? localTime;
        
        if (anime.broadcastDay != null && anime.broadcastTime != null) {
          localTime = _parseJstNextBroadcast(anime.broadcastDay!, anime.broadcastTime!);
          
          if (localTime != null) {
             weekday = localTime.weekday;
             
             // FIX: Check if it airs TODAY in the user's local time
             if (localTime.year == now.year && localTime.month == now.month && localTime.day == now.day) {
               // Make sure it hasn't aired yet today
               if (localTime.isAfter(now)) {
                   upcoming.add({'anime': anime, 'time': localTime});
               }
             }
          }
        }
        
        // FIX: Only add to the schedule if we successfully found a valid day
        if (weekday != null) {
          grouped.putIfAbsent(weekday, () => []).add(anime);
        }
      }
      
      _sortGroups(grouped, _sortMode);
      upcoming.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

      if (mounted) {
        setState(() { 
          _groupedSchedule = grouped;
          _upcomingAnimes = upcoming;
          _loading = false; 
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _sortGroups(Map<int, List<AnimeModel>> grouped, String mode) {
    for (final list in grouped.values) {
       list.sort((a, b) {
           if (mode == 'score') {
              return (b.score ?? 0).compareTo(a.score ?? 0);
           } else {
              if (a.broadcastTime == null || b.broadcastTime == null) return 0;
              return a.broadcastTime!.compareTo(b.broadcastTime!);
           }
       });
    }
  }

  DateTime? _parseJstNextBroadcast(String day, String time) {
     try {
       // 1. BULLETPROOF PARSING: Hunt for HH:mm format anywhere in the string
       final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(time);
       
       // If we can't find any numbers formatted like time, fail safely.
       if (timeMatch == null) {
         debugPrint("Could not find time format in string: $time");
         return null; 
       }
       
       // 2. Safely extract exact integers
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
       
       return nextJst.subtract(const Duration(hours: 9)).toLocal();
       
     } catch (e) {
       // Print the exact error so we can see what is breaking it in the terminal
       debugPrint("Date parse error for day: $day, time: $time -> Error: $e");
       return null;
     }
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
        await HiveService.removeFromList(anime.id);
    }
    setState(() {});
  }

  String _getDayName(int num) {
    switch(num) {
       case 1: return AppText.get('monday');
       case 2: return AppText.get('tuesday');
       case 3: return AppText.get('wednesday');
       case 4: return AppText.get('thursday');
       case 5: return AppText.get('friday');
       case 6: return AppText.get('saturday');
       case 7: return AppText.get('sunday');
    }
    return '';
  }

  String _getCountdownString(DateTime time) {
    final now = DateTime.now();
    final diff = time.difference(now);
    if (diff.isNegative) {
      return "Aired";
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    
    if (days > 0) {
      return "${days}d ${hours}h left";
    } else if (hours > 0) {
      return "${hours}h ${minutes}m left";
    } else {
      return "${minutes}m left";
    }
  }

  Widget _buildAlertToggle(int animeId) {
    final hasAlert = HiveService.hasAlertEnabled(animeId);
    return IconButton(
      icon: Icon(
        hasAlert ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
        color: hasAlert ? AppColors.starYellow : Colors.grey,
        size: 20,
      ),
      tooltip: hasAlert ? 'Disable alerts' : 'Enable airing alerts',
      onPressed: () async {
        final newStatus = !hasAlert;
        await HiveService.setAlertEnabled(animeId, newStatus);
        
        if (newStatus) {
          await NotificationService.subscribeToAnime(animeId);
        } else {
          await NotificationService.unsubscribeFromAnime(animeId);
        }
        
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus ? 'Airing alerts enabled!' : 'Airing alerts disabled!'),
              backgroundColor: newStatus ? Colors.green : Colors.black87,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
    );
  }

  Widget _buildNextAnimeSection() {
     if (_upcomingAnimes.isEmpty) return const SizedBox.shrink();
     
     final isDark = Theme.of(context).brightness == Brightness.dark;
       
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(Icons.flash_on, color: AppColors.accent, size: 16),
                const SizedBox(width: 4),
                Text("Airing Next Today", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _upcomingAnimes.length,
              itemBuilder: (context, index) {
                 final item = _upcomingAnimes[index];
                 final AnimeModel anime = item['anime'];
                 final DateTime time = item['time'];
                 final timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                 final countdown = _getCountdownString(time);
                 
                 return Container(
                    width: 270,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent.withAlpha(index == 0 ? 100 : 30), width: index == 0 ? 1.5 : 1.0),
                    ),
                    child: Row(
                      children: [
                         GestureDetector(
                           onTap: () => widget.onSelectAnime(anime.id),
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(8),
                             child: Image.network(anime.image, width: 70, height: 100, fit: BoxFit.cover),
                           ),
                         ),
                         const SizedBox(width: 12),
                         Expanded(
                            child: GestureDetector(
                              onTap: () => widget.onSelectAnime(anime.id),
                              child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                    Text(anime.title, style: Theme.of(context).textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 6),
                                    Row(
                                       children: [
                                          Icon(Icons.schedule, size: 12, color: isDark ? Colors.white70 : Colors.black54),
                                          const SizedBox(width: 4),
                                          Text(timeStr, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                                       ]
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withAlpha(20),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        countdown,
                                        style: TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                 ]
                              ),
                            ),
                         ),
                         _buildAlertToggle(anime.id),
                      ]
                    ),
                 );
              }
            )
          ),
          const SizedBox(height: 16),
       ],
     );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final orderedDays = [today];
    for (int i = 1; i < 7; i++) {
        int next = today + i;
        if (next > 7) next -= 7;
        orderedDays.add(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppText.get('weekly_schedule'), 
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
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

        if (!_loading && _upcomingAnimes.isNotEmpty) _buildNextAnimeSection(),

        // ── API Status Banner ──
        ValueListenableBuilder<bool>(
          valueListenable: JikanService.usingCachedData,
          builder: (context, usingCached, _) {
            if (!usingCached) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ApiStatusBanner(
                onRetry: _refetchSchedule,
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
                  : _groupedSchedule.isNotEmpty
                      ? ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: orderedDays.length,
                          itemBuilder: (context, index) {
                             final day = orderedDays[index];
                             final list = _groupedSchedule[day];
                             if (list == null || list.isEmpty) return const SizedBox.shrink();
                             
                             return Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Padding(
                                   padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                                   child: Row(
                                     children: [
                                       Container(
                                         width: 4,
                                         height: 18,
                                         decoration: BoxDecoration(
                                           color: AppColors.accent,
                                           borderRadius: BorderRadius.circular(2),
                                         ),
                                       ),
                                       const SizedBox(width: 8),
                                       Text(
                                         day == today ? "${AppText.get('today')} - ${_getDayName(day)}" : _getDayName(day),
                                         style: TextStyle(
                                           color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                           fontWeight: FontWeight.w900,
                                           fontSize: 15,
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
                        )
                      : Center(
                          child: Text(
                            AppText.get('no_schedule'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
        ),
      ],
    );
  }
}