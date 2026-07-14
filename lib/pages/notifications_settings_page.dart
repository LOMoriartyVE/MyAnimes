import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/services/notification_service.dart';

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
                  activeThumbColor: AppColors.accent,
                  activeTrackColor: AppColors.accent.withAlpha(80),
                  inactiveThumbColor: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                  inactiveTrackColor: isDark ? AppColors.darkCard : AppColors.lightCard,
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
                          activeThumbColor: AppColors.accent,
                          activeTrackColor: AppColors.accent.withAlpha(80),
                          inactiveThumbColor: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                          inactiveTrackColor: isDark ? AppColors.darkCard : AppColors.lightCard,
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
                          activeThumbColor: AppColors.accent,
                          activeTrackColor: AppColors.accent.withAlpha(80),
                          inactiveThumbColor: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                          inactiveTrackColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
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
