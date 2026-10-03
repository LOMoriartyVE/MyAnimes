import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/app_text.dart';
import '../core/models/anime_model.dart';
import '../core/services/airing_schedule_service.dart';

class DailyTimeline extends StatelessWidget {
  final Map<int, List<AnimeModel>> scheduleMap;
  final void Function(int) onSelectAnime;
  final VoidCallback? onSeeAll;

  const DailyTimeline({
    super.key,
    required this.scheduleMap,
    required this.onSelectAnime,
    this.onSeeAll,
  });

  String _getDayName(int num) {
    switch(num) {
       case 1: return AppText.get('monday') ?? 'Monday';
       case 2: return AppText.get('tuesday') ?? 'Tuesday';
       case 3: return AppText.get('wednesday') ?? 'Wednesday';
       case 4: return AppText.get('thursday') ?? 'Thursday';
       case 5: return AppText.get('friday') ?? 'Friday';
       case 6: return AppText.get('saturday') ?? 'Saturday';
       case 7: return AppText.get('sunday') ?? 'Sunday';
    }
    return '';
  }

  DateTime? _parseJstNextBroadcast(String day, String time) {
    return AiringScheduleService.parseJstNextBroadcast(day, time);
  }

  String _getLocalTimeStr(AnimeModel anime) {
    if (anime.broadcastDay == null || anime.broadcastTime == null) {
      return anime.broadcastTime ?? '?';
    }
    final localTime = _parseJstNextBroadcast(anime.broadcastDay!, anime.broadcastTime!);
    if (localTime == null) return anime.broadcastTime ?? '?';
    return "${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (scheduleMap.isEmpty) return const SizedBox.shrink();

    final today = AiringScheduleService.nowInTargetTimezone().weekday;
    final orderedDays = [today];
    for (int i = 1; i < 7; i++) {
        int next = today + i;
        if (next > 7) next -= 7;
        orderedDays.add(next);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Daily Timeline',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text('See All', style: TextStyle(color: AppColors.accent)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: orderedDays.length,
            itemBuilder: (context, index) {
              final day = orderedDays[index];
              final list = scheduleMap[day];
              final anime = (list != null && list.isNotEmpty) ? list.first : null;

              return SizedBox(
                width: 180,
                child: Column(
                  children: [
                    // Top Node & Day label
                    Text(
                      _getDayName(day),
                      style: TextStyle(
                        fontWeight: day == today ? FontWeight.bold : FontWeight.normal,
                        color: day == today ? AppColors.accent : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // The Timeline Line & Dot
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 2,
                            color: index == 0 ? Colors.transparent : (isDark ? Colors.white24 : Colors.black12),
                          ),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: day == today ? AppColors.accent : (isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: index == orderedDays.length - 1 ? Colors.transparent : (isDark ? Colors.white24 : Colors.black12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // The Anime Card below the dot
                    if (anime != null)
                      GestureDetector(
                        onTap: () => onSelectAnime(anime.id),
                        child: Container(
                          width: 160,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: day == today ? AppColors.accent.withAlpha(100) : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  anime.image,
                                  width: 40,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      anime.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule, size: 10, color: Colors.grey),
                                        const SizedBox(width: 2),
                                        Text(
                                          _getLocalTimeStr(anime),
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
