import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../pages/notifications_settings_page.dart';
import '../pages/detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notifications = HiveService.getNotifications();
    });
  }

  void _clearAll() async {
    await HiveService.saveNotifications([]);
    _loadNotifications();
  }

  void _deleteNotification(String id) async {
    final updated = _notifications.where((n) => n['id'] != id).toList();
    await HiveService.saveNotifications(updated);
    _loadNotifications();
  }

  void _markAsRead(String id) async {
    final updated = _notifications.map((n) {
      if (n['id'] == id) {
        final copy = Map<String, dynamic>.from(n);
        copy['read'] = true;
        return copy;
      }
      return n;
    }).toList();
    await HiveService.saveNotifications(updated);
    _loadNotifications();
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'airing':
        return Icons.live_tv_rounded;
      case 'season':
        return Icons.campaign_rounded;
      case 'sync':
        return Icons.cloud_done_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'airing':
        return AppColors.watching;
      case 'season':
        return AppColors.mauve;
      case 'sync':
        return AppColors.completed;
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Notifications",
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text("Clear All", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
          IconButton(
            icon: Icon(Icons.tune_rounded, color: isDark ? Colors.white70 : Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsSettingsPage()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _notifications.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_off_outlined,
                        size: 72,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No notifications yet",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "We'll notify you when new episodes air.",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: _notifications.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notif = _notifications[index];
                  final isRead = notif['read'] as bool? ?? false;
                  final type = notif['type'] as String? ?? 'general';

                  return GestureDetector(
                    onTap: () {
                      _markAsRead(notif['id']);
                      if (notif['animeId'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailPage(
                              animeId: notif['animeId'] as int,
                              onBack: () => Navigator.pop(context),
                            ),
                          ),
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isRead
                            ? (isDark ? AppColors.darkCard.withOpacity(0.5) : AppColors.lightCard.withOpacity(0.5))
                            : (isDark ? AppColors.darkCard : AppColors.lightCard),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRead
                              ? Colors.transparent
                              : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status indicator bar
                          if (!isRead)
                            Container(
                              width: 3,
                              height: 38,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          // Type Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getIconColor(type).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getIcon(type),
                              color: _getIconColor(type),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notif['title'] as String? ?? 'Notification',
                                        style: TextStyle(
                                          fontWeight: isRead ? FontWeight.bold : FontWeight.w900,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTime(notif['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white30 : Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  notif['body'] as String? ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delete action button
                          IconButton(
                            icon: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white30 : Colors.black38),
                            onPressed: () => _deleteNotification(notif['id']),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
