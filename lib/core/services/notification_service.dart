import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'hive_service.dart';
import '../models/anime_list_item.dart';
import 'airing_schedule_service.dart';

class NotificationService {
  static FirebaseMessaging? get _firebaseMessaging {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        return FirebaseMessaging.instance;
      } catch (_) {}
    }
    return null;
  }

  static Future<void> init() async {
    // Check release day episodes for watching list
    await checkAndNotifyReleaseDays();

    if (_firebaseMessaging == null) return;
    // Just sync subscriptions if already enabled. Don't prompt yet.
    if (HiveService.enableNotifications) {
      await syncSubscriptions();
    }
  }

  /// Checks if any anime in the user's watching list airs today,
  /// and automatically logs an in-app notification to the notifications center.
  static Future<void> checkAndNotifyReleaseDays() async {
    if (!HiveService.enableNotifications || !HiveService.airingNotifications) {
      return;
    }

    try {
      final watchingList = HiveService.getByCategory(AnimeCategory.watching);
      if (watchingList.isEmpty) return;

      final existingNotifs = HiveService.getNotifications();
      final now = DateTime.now();
      final dateKey = '${now.year}-${now.month}-${now.day}';
      bool addedAny = false;
      final updatedNotifs = List<Map<String, dynamic>>.from(existingNotifs);

      for (final item in watchingList) {
        final info = AiringScheduleService.getCountdown(
          item.animeId,
          episodeProgress: item.episodeProgress,
        );

        if (info.isAiringToday) {
          final notifId = 'airing_${item.animeId}_$dateKey';
          final alreadyLogged = existingNotifs.any((n) => n['id'] == notifId);

          if (!alreadyLogged) {
            final epText = info.nextEpisode != null ? 'Episode ${info.nextEpisode}' : 'New episode';
            updatedNotifs.insert(0, {
              'id': notifId,
              'title': item.title,
              'body': '$epText is broadcasting today!',
              'type': 'airing',
              'animeId': item.animeId,
              'timestamp': now.millisecondsSinceEpoch,
              'read': false,
            });
            addedAny = true;
          }
        }
      }

      if (addedAny) {
        await HiveService.saveNotifications(updatedNotifs);
      }
    } catch (_) {}
  }

  static Future<bool> requestPermissionAndSync() async {
    final messaging = _firebaseMessaging;
    if (messaging == null) return false;

    try {
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await syncSubscriptions();
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> syncSubscriptions() async {
    final messaging = _firebaseMessaging;
    if (messaging == null) return;

    try {
      if (!HiveService.enableNotifications) {
        // Unsubscribe from everything if totally disabled
        await messaging.unsubscribeFromTopic('airing');
        await messaging.unsubscribeFromTopic('new_season');
        return;
      }

      if (HiveService.airingNotifications) {
        await messaging.subscribeToTopic('airing');
      } else {
        await messaging.unsubscribeFromTopic('airing');
      }

      if (HiveService.newSeasonNotifications) {
        await messaging.subscribeToTopic('new_season');
      } else {
        await messaging.unsubscribeFromTopic('new_season');
      }
    } catch (_) {}
  }

  /// Called when adding an anime to "watching" or "planned" list to get specific alerts
  static Future<void> subscribeToAnime(int animeId) async {
    final messaging = _firebaseMessaging;
    if (messaging == null) return;

    try {
      if (HiveService.enableNotifications && HiveService.airingNotifications) {
        await messaging.subscribeToTopic('anime_$animeId');
      }
    } catch (_) {}
  }

  static Future<void> unsubscribeFromAnime(int animeId) async {
    final messaging = _firebaseMessaging;
    if (messaging == null) return;

    try {
      await messaging.unsubscribeFromTopic('anime_$animeId');
    } catch (_) {}
  }

  static Future<void> subscribeToManga(int mangaId) async {
    final messaging = _firebaseMessaging;
    if (messaging == null) return;

    try {
      if (HiveService.enableNotifications) {
        await messaging.subscribeToTopic('manga_$mangaId');
      }
    } catch (_) {}
  }

  static Future<void> unsubscribeFromManga(int mangaId) async {
    final messaging = _firebaseMessaging;
    if (messaging == null) return;

    try {
      await messaging.unsubscribeFromTopic('manga_$mangaId');
    } catch (_) {}
  }
}
