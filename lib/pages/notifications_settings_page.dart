import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/services/notification_service.dart';
import '../core/localization/app_text.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() => _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  late bool _enableNotifications;
  late bool _airingNotifications;
  late bool _newSeasonNotifications;

  @override
  void initState() {
    super.initState();
    _enableNotifications = HiveService.enableNotifications;
    _airingNotifications = HiveService.airingNotifications;
    _newSeasonNotifications = HiveService.newSeasonNotifications;
  }

  void _updateSettings() {
    HiveService.setEnableNotifications(_enableNotifications);
    HiveService.setAiringNotifications(_airingNotifications);
    HiveService.setNewSeasonNotifications(_newSeasonNotifications);
    NotificationService.syncSubscriptions();
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
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSettingsTile(
                icon: Icons.notifications_active,
                iconBgColor: AppColors.accent.withAlpha(30),
                iconColor: AppColors.accent,
                title: "Enable Notifications",
                trailing: Switch(
                  value: _enableNotifications,
                  onChanged: (value) async {
                    if (value) {
                       bool granted = await NotificationService.requestPermissionAndSync();
                       if (granted) {
                         setState(() => _enableNotifications = true);
                         _updateSettings();
                       } else {
                         if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification permission denied')));
                         }
                       }
                    } else {
                       setState(() => _enableNotifications = false);
                       _updateSettings();
                    }
                  },
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.accent,
                  inactiveThumbColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  inactiveTrackColor: isDark ? const Color(0xFF282D3D) : const Color(0xFFCBD5E1),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                ),
              ),

              AnimatedOpacity(
                opacity: _enableNotifications ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 300),
                child: AbsorbPointer(
                  absorbing: !_enableNotifications,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildSettingsTile(
                        icon: Icons.live_tv,
                        iconBgColor: AppColors.watching.withAlpha(30),
                        iconColor: AppColors.watching,
                        title: "Airing Next",
                        subtitle: "Alert when a watched anime airs",
                        trailing: Switch(
                          value: _airingNotifications,
                          onChanged: (value) {
                            setState(() => _airingNotifications = value);
                            _updateSettings();
                          },
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.accent,
                          inactiveThumbColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          inactiveTrackColor: isDark ? const Color(0xFF282D3D) : const Color(0xFFCBD5E1),
                          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTile(
                        icon: Icons.new_releases,
                        iconBgColor: AppColors.planned.withAlpha(30),
                        iconColor: AppColors.planned,
                        title: "New Season",
                        subtitle: "Alert when new season starts",
                        trailing: Switch(
                          value: _newSeasonNotifications,
                          onChanged: (value) {
                            setState(() => _newSeasonNotifications = value);
                            _updateSettings();
                          },
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.accent,
                          inactiveThumbColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          inactiveTrackColor: isDark ? const Color(0xFF282D3D) : const Color(0xFFCBD5E1),
                          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Diagnostics & Google Services Connection Check
              _buildSettingsTile(
                icon: Icons.cloud_sync_rounded,
                iconBgColor: Colors.blue.withAlpha(30),
                iconColor: Colors.blueAccent,
                title: "Google Services Status",
                subtitle: "Check connection to Firebase & Push Services",
                trailing: TextButton.icon(
                  onPressed: _testGoogleServicesConnection,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text("Test", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    backgroundColor: AppColors.accent.withAlpha(25),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _testGoogleServicesConnection() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final status = await NotificationService.checkGoogleServicesStatus();
    if (mounted) Navigator.pop(context);

    if (!mounted) return;

    final connected = status['connected'] == true;
    final message = status['message']?.toString() ?? 'Unknown status';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2230) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              connected ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: connected ? Colors.green : Colors.orangeAccent,
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              connected ? "Connected" : "Services Info",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (status['authorizationStatus'] != null) ...[
              const SizedBox(height: 10),
              Text(
                "Permission: ${status['authorizationStatus']}",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
            if (status['token'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "FCM Token: ${(status['token'] as String).substring(0, 16)}...",
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppText.get('ok') ?? 'OK', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null)
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
