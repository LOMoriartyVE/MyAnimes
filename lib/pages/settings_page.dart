import 'package:flutter/material.dart';
import 'notifications_settings_page.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/services/google_drive_service.dart';
import '../core/services/mal_auth_service.dart';
import 'mal_login_page.dart';
import '../core/localization/app_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';


class SettingsPage extends StatefulWidget {
  final VoidCallback onThemeChanged;
  final VoidCallback onLanguageChanged;

  const SettingsPage({
    super.key,
    required this.onThemeChanged,
    required this.onLanguageChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _themePack;
  late String _language;

  @override
  void initState() {
    super.initState();
    _themePack = HiveService.themePack;
    _language = HiveService.language;
    _checkGoogleSignIn();
  }

  Future<void> _checkGoogleSignIn() async {
    final account = await GoogleDriveService.signInSilently();
    if (account != null && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppText.get('settings'),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 24),

            // ── Preferences Section ──
            _sectionHeader(AppText.get('preferences')),
            const SizedBox(height: 12),

            // Theme Pack
            GestureDetector(
              onTap: () => _showThemePackPicker(context),
              child: _buildSettingsTile(
                icon: Icons.palette_outlined,
                iconBgColor: AppColors.lavender.withAlpha(30),
                iconColor: AppColors.lavender,
                title: 'Theme Pack',
                subtitle: 'Change app look, feel, and colors',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getThemePackLabel(_themePack),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Notifications
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const NotificationsSettingsPage(),
                ));
              },
              child: _buildSettingsTile(
                icon: Icons.notifications_active_outlined,
                iconBgColor: AppColors.success.withAlpha(30),
                iconColor: AppColors.success,
                title: "Notifications",
                subtitle: 'Configure alerts and release reminders',
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white54 : Colors.black54),
              ),
            ),

            const SizedBox(height: 8),

            // Language
            GestureDetector(
              onTap: () => _showLanguagePicker(context),
              child: _buildSettingsTile(
                icon: Icons.language_rounded,
                iconBgColor: AppColors.mauve.withAlpha(30),
                iconColor: AppColors.mauve,
                title: AppText.get('language'),
                subtitle: 'Switch app between English & Arabic',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _language == 'ar' ? AppText.get('arabic') : AppText.get('english'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                  ],
                ),
              ),
            ),

            if (!Platform.isAndroid && !Platform.isIOS) ...[
              const SizedBox(height: 24),
              // ── Local Library ──
              _sectionHeader('Local Library'),
              const SizedBox(height: 12),
              _buildSettingsTile(
                icon: Icons.folder_special_outlined,
                iconBgColor: AppColors.starYellow.withAlpha(30),
                iconColor: AppColors.starYellow,
                title: 'Anime Folder',
                subtitle: 'Folder: ${HiveService.localAnimeFolder ?? 'Not set'}\nSelect folder to scan and play offline videos',
                trailing: IconButton(
                  icon: Icon(Icons.edit, color: isDark ? Colors.white70 : Colors.black87),
                  onPressed: () async {
                    try {
                      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                      if (selectedDirectory != null) {
                        await HiveService.setLocalAnimeFolder(selectedDirectory);
                        if (context.mounted) setState(() {});
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error selecting folder: $e')));
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],

            const SizedBox(height: 24),
            // ── Streaming & API Configuration ──
            _sectionHeader('Streaming & API Configuration'),
            const SizedBox(height: 12),
            _buildSettingsTile(
              icon: Icons.public_rounded,
              iconBgColor: AppColors.mauve.withAlpha(30),
              iconColor: AppColors.mauve,
              title: 'WitAnime Domain',
              subtitle: 'Domain: ${HiveService.witanimeDomain}\nChange the domain name if WitAnime changes it',
              trailing: IconButton(
                icon: Icon(Icons.edit_outlined, color: isDark ? Colors.white70 : Colors.black87),
                onPressed: () => _showWitanimeDomainDialog(context),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              icon: Icons.chrome_reader_mode_outlined,
              iconBgColor: AppColors.lavender.withAlpha(30),
              iconColor: AppColors.lavender,
              title: 'WitManga Domain',
              subtitle: 'Domain: ${HiveService.witmangaDomain}\nChange the domain name if WitManga changes it',
              trailing: IconButton(
                icon: Icon(Icons.edit_outlined, color: isDark ? Colors.white70 : Colors.black87),
                onPressed: () => _showWitmangaDomainDialog(context),
              ),
            ),
            const SizedBox(height: 24),

            // ── Data Management ──
            _sectionHeader(AppText.get('data')),
            const SizedBox(height: 12),

            // Export
            _buildSettingsTile(
              icon: Icons.upload_rounded,
              iconBgColor: AppColors.lavender.withAlpha(30),
              iconColor: AppColors.lavender,
              title: AppText.get('export_data'),
              subtitle: 'Export your local anime list, watch history, and ratings to a JSON file',
              trailing: IconButton(
                icon: Icon(Icons.share, color: isDark ? Colors.white70 : Colors.black87),
                onPressed: () async {
                  try {
                    final jsonStr = await HiveService.exportAsJson();
                    final dir = await getTemporaryDirectory();
                    final file = File('${dir.path}/MyAnimes_export.json');
                    await file.writeAsString(jsonStr);
                    await Share.shareXFiles([XFile(file.path)], text: 'MyAnimes Backup');
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                  }
                },
              ),
            ),
            const SizedBox(height: 8),

            // Import
            _buildSettingsTile(
              icon: Icons.download_rounded,
              iconBgColor: AppColors.accent.withAlpha(30),
              iconColor: AppColors.accent,
              title: AppText.get('import_data'),
              subtitle: 'Restore lists and settings from a previously saved JSON file',
              trailing: IconButton(
                icon: Icon(Icons.folder_open, color: isDark ? Colors.white70 : Colors.black87),
                onPressed: () async {
                  try {
                    final result = await FilePicker.platform.pickFiles(type: FileType.any);
                    if (result != null && result.files.single.path != null) {
                      final file = File(result.files.single.path!);
                      final jsonStr = await file.readAsString();
                      await HiveService.importFromJson(jsonStr);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import Successful!')));
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
                    }
                  }
                },
              ),
            ),

            const SizedBox(height: 8),

            // Cache Settings Card
            _buildCacheSettingsTile(isDark),

            const SizedBox(height: 8),

            // Google Drive Sync Card
            _buildGoogleDriveSyncTile(isDark),

            const SizedBox(height: 32),

            // App Info
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/MA_logo.png', width: 60, height: 60),
                  ),
                  const SizedBox(height: 12),
                  ShaderMask(
                    shaderCallback: (bounds) => AppColors.brandGradient.createShader(bounds),
                    child: const Text(
                      'My Animes',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v1.1.70',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWitanimeDomainDialog(BuildContext context) {
    final controller = TextEditingController(text: HiveService.witanimeDomain);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit WitAnime Domain'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the active domain (e.g. witanime.you):', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Domain',
                  hintText: 'witanime.you',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final input = controller.text.trim();
                if (input.isNotEmpty) {
                  var clean = input.replaceAll('https://', '').replaceAll('http://', '');
                  if (clean.endsWith('/')) {
                    clean = clean.substring(0, clean.length - 1);
                  }
                  await HiveService.setWitanimeDomain(clean);
                  if (context.mounted) {
                    setState(() {});
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('WitAnime domain updated to $clean'), backgroundColor: Colors.green),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showWitmangaDomainDialog(BuildContext context) {
    final controller = TextEditingController(text: HiveService.witmangaDomain);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit WitManga Domain'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the active domain (e.g. witmanga.xyz):', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Domain',
                  hintText: 'witmanga.xyz',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final input = controller.text.trim();
                if (input.isNotEmpty) {
                  var clean = input.replaceAll('https://', '').replaceAll('http://', '');
                  if (clean.endsWith('/')) {
                    clean = clean.substring(0, clean.length - 1);
                  }
                  await HiveService.setWitmangaDomain(clean);
                  if (context.mounted) {
                    setState(() {});
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('WitManga domain updated to $clean'), backgroundColor: Colors.green),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppColors.accent,
          ),
        ),
      ],
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
  Widget _buildGoogleDriveSyncTile(bool isDark) {
    final isSignedIn = GoogleDriveService.isSignedIn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF139C5A).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_queue_rounded, color: Color(0xFF139C5A), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppText.get('google_drive_sync'), style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      isSignedIn ? 'Linked: ${GoogleDriveService.userEmail ?? ""}' : 'Save and restore your backups automatically on Google Drive',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isSignedIn) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent.withAlpha(20),
                      foregroundColor: AppColors.accent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final success = await GoogleDriveService.uploadBackup();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? AppText.get('sync_success') : AppText.get('sync_failed')),
                            backgroundColor: success ? AppColors.success : Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.backup_outlined, size: 18),
                    label: Text(AppText.get('backup_now')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mauve.withAlpha(20),
                      foregroundColor: AppColors.mauve,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final success = await GoogleDriveService.downloadAndRestoreBackup();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? AppText.get('restore_success') : AppText.get('sync_failed')),
                            backgroundColor: success ? AppColors.success : Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
                    label: Text(AppText.get('restore_backup')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  await GoogleDriveService.signOut();
                  setState(() {});
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: Text(AppText.get('disconnect_drive')),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  final account = await GoogleDriveService.signIn();
                  if (account != null && mounted) {
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.login_rounded),
                label: Text(AppText.get('connect_drive')),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildCacheSettingsTile(bool isDark) {
    final cacheMode = HiveService.cacheMode;
    final customHours = HiveService.customCacheDurationHours;

    String getCustomDurationLabel(int hours) {
      if (hours < 24) {
        return '$hours ${AppText.get('hours_label').toLowerCase()}';
      } else {
        final days = hours ~/ 24;
        return '$days ${AppText.get('days_label').toLowerCase()}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.starYellow.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.storage_rounded, color: AppColors.starYellow, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppText.get('cache_settings'), style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      'Configure how long API data is saved locally for offline usage',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mode Dropdown Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppText.get('cache_mode'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: cacheMode,
                        isDense: true,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        dropdownColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        items: [
                      DropdownMenuItem(
                        value: 'never',
                        child: Text(AppText.get('cache_mode_never')),
                      ),
                      DropdownMenuItem(
                        value: 'default',
                        child: Text(AppText.get('cache_mode_default')),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text(AppText.get('cache_mode_custom')),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      await HiveService.setCacheMode(value);
                      setState(() {});
                    },
                  ),
                ),
              ),
                ),
              ),
            ],
          ),
          if (cacheMode == 'custom') ...[
            const SizedBox(height: 12),
            // Custom Duration dropdown row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppText.get('custom_duration'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: customHours,
                          isDense: true,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          dropdownColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          items: [2, 4, 8, 16, 24, 72, 168, 720].map((hours) {
                        return DropdownMenuItem<int>(
                          value: hours,
                          child: Text(getCustomDurationLabel(hours)),
                        );
                      }).toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            await HiveService.setCustomCacheDurationHours(value);
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showThemePackPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themes = [
      ('default_light', 'Default Light'),
      ('default_dark', 'Default Dark'),
      ('glassmorphic_dark', 'Glassmorphic Dark'),
      ('cyberpunk_neon', 'Cyberpunk Neon'),
      ('sakura_blossom', 'Sakura Blossom'),
      ('midnight_abyss', 'Midnight Abyss (OLED)'),
      ('retro_forest', 'Retro Forest'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Theme Pack',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: themes.map((theme) {
                    final isSelected = _themePack == theme.$1;
                    return ListTile(
                      title: Text(
                        theme.$2,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? AppColors.accent : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: AppColors.accent)
                          : null,
                      onTap: () async {
                        Navigator.pop(context);
                        setState(() => _themePack = theme.$1);
                        await HiveService.setThemePack(theme.$1);
                        widget.onThemeChanged();
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languages = [
      ('en', AppText.get('english')),
      ('ar', AppText.get('arabic')),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppText.get('language'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: languages.map((lang) {
                    final isSelected = _language == lang.$1;
                    return ListTile(
                      title: Text(
                        lang.$2,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? AppColors.accent : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: AppColors.accent)
                          : null,
                      onTap: () async {
                        Navigator.pop(context);
                        setState(() => _language = lang.$1);
                        await HiveService.setLanguage(lang.$1);
                        AppText.setLanguage(lang.$1);
                        widget.onLanguageChanged();
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  String _getThemePackLabel(String theme) {
    switch (theme) {
      case 'default_light':
        return 'Default Light';
      case 'default_dark':
        return 'Default Dark';
      case 'glassmorphic_dark':
        return 'Glassmorphic Dark';
      case 'cyberpunk_neon':
        return 'Cyberpunk Neon';
      case 'sakura_blossom':
        return 'Sakura Blossom';
      case 'midnight_abyss':
        return 'Midnight Abyss';
      case 'retro_forest':
        return 'Retro Forest';
      default:
        return theme;
    }
  }
}
