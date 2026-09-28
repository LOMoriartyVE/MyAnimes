import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';

class StoragePermissionHelper {
  /// Checks whether storage access / all files management permission is currently granted.
  /// Does NOT trigger any system dialog or open system settings.
  static Future<bool> hasPermission() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return true;
    }
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
      return false;
    } else if (Platform.isIOS) {
      return await Permission.storage.isGranted;
    }
    return true;
  }

  /// Request permission from the system.
  /// On Android, this requests manageExternalStorage first, then standard storage.
  static Future<bool> requestPermission() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return true;
    }
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return true;
      status = await Permission.storage.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

  /// Shows an in-app explanation modal explaining WHY storage permission is needed
  /// BEFORE opening any system settings screen.
  /// If the user confirms, it then requests the system permission.
  /// Returns `true` if permission is granted, `false` otherwise.
  static Future<bool> requestWithRationale(
    BuildContext context, {
    String? title,
    String? message,
  }) async {
    if (await hasPermission()) return true;
    if (!context.mounted) return false;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.folder_shared_rounded, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title ?? 'Storage Access Required',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message ??
              'MyAnimes needs permission to manage local video files so you can organize your library, download episodes from WitAnime, and watch them locally on your device.\n\nYour files stay completely private on your device. Would you like to grant permission now?',
          style: const TextStyle(fontSize: 14, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Grant Access'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final granted = await requestPermission();
      return granted;
    }
    return false;
  }
}
