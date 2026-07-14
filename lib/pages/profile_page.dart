
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme/app_colors.dart';
import '../core/localization/app_text.dart';
import '../core/services/hive_service.dart';
import '../core/services/mal_auth_service.dart';
import '../core/models/anime_list_item.dart';
import '../pages/mal_login_page.dart';
import '../pages/detail_page.dart';
import '../widgets/dna_radar_chart.dart';
import '../pages/merge_preview_page.dart';
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isSyncing = false;
  String? _syncMessage;
  bool _syncSuccess = false;

  // MAL profile metadata
  String? _username;
  bool _isLoggedIn = false;
  String? _pictureUrl;
  bool _bypassConnectionPrompt = false;

  // Visual Tabs
  String _activeTab = "overview"; // overview, metrics, favorites, raw
  bool _synopsisExpanded = false;
  bool _isEditingDNA = false;

  // DNA Ratings state
  double _dnaOverall = 8.8;
  double _dnaCompleteness = 8.5;
  double _dnaVariety = 8.0;
  double _dnaActivity = 9.2;
  double _dnaUniqueness = 7.5;
  double _dnaEngagement = 9.4;

  // Local Stats counters
  int _animeCount = 0;
  int _animeCompleted = 0;
  int _animeWatching = 0;
  int _animePlanned = 0;
  int _animeIgnored = 0;
  double _animeMeanScore = 0.0;
  int _animeEpsWatched = 0;

  int _mangaCount = 0;
  int _mangaCompleted = 0;
  int _mangaReading = 0;
  int _mangaPlanned = 0;
  int _mangaIgnored = 0;
  double _mangaMeanScore = 0.0;
  int _mangaChaptersRead = 0;

  List<AnimeListItem> _recentUpdates = [];
  List<AnimeListItem> _favorites = [];

  @override
  void initState() {
    super.initState();
    _isLoggedIn = MalAuthService.instance.isLoggedIn;
    _username = HiveService.malUsername;
    _pictureUrl = HiveService.malUserPicture;
    
    _syncActiveAccountToAccountsList();
    _loadStatsAndDetails();

    // Listen for login state changes
    MalAuthService.instance.isLoggedInNotifier.addListener(_onLoginStateChanged);
  }

  @override
  void dispose() {
    MalAuthService.instance.isLoggedInNotifier.removeListener(_onLoginStateChanged);
    super.dispose();
  }

  void _onLoginStateChanged() {
    if (mounted) {
      _syncActiveAccountToAccountsList();
      setState(() {
        _isLoggedIn = MalAuthService.instance.isLoggedIn;
        _username = HiveService.malUsername;
        _pictureUrl = HiveService.malUserPicture;
      });
      _loadStatsAndDetails();
    }
  }

  void _syncActiveAccountToAccountsList() {
    final activeUsername = HiveService.malUsername;
    final token = HiveService.malAccessToken;
    if (activeUsername == null || token == null) return;

    final accounts = HiveService.getMalAccounts();
    final index = accounts.indexWhere((a) => a['username'] == activeUsername);

    final accountMap = {
      'username': activeUsername,
      'pictureUrl': HiveService.malUserPicture,
      'accessToken': token,
      'refreshToken': HiveService.malRefreshToken,
      'tokenExpiry': HiveService.malTokenExpiry,
    };

    if (index >= 0) {
      accounts[index] = accountMap;
    } else {
      accounts.add(accountMap);
    }
    HiveService.saveMalAccounts(accounts);
  }

  Future<void> _handleLogout() async {
    final activeUsername = HiveService.malUsername;
    await MalAuthService.instance.logout();
    
    if (activeUsername != null) {
      final accounts = HiveService.getMalAccounts();
      accounts.removeWhere((a) => a['username'] == activeUsername);
      await HiveService.saveMalAccounts(accounts);
      
      if (accounts.isNotEmpty) {
        await _switchAccount(accounts.first);
        return;
      }
    }
    
    _onLoginStateChanged();
  }

  Future<void> _switchAccount(Map<String, dynamic> account) async {
    await HiveService.setMalUsername(account['username'] as String?);
    await HiveService.setMalUserPicture(account['pictureUrl'] as String?);
    await HiveService.setMalAccessToken(account['accessToken'] as String?);
    await HiveService.setMalRefreshToken(account['refreshToken'] as String?);
    await HiveService.setMalTokenExpiry(account['tokenExpiry'] as int?);

    // Notify auth service that state has changed
    MalAuthService.instance.isLoggedInNotifier.value = false;
    MalAuthService.instance.isLoggedInNotifier.value = true;
    _onLoginStateChanged();
  }

  Future<void> _removeAccount(Map<String, dynamic> account) async {
    final username = account['username'] as String?;
    if (username == null) return;
    
    final accounts = HiveService.getMalAccounts();
    accounts.removeWhere((a) => a['username'] == username);
    await HiveService.saveMalAccounts(accounts);
    
    setState(() {});
  }

  Widget _buildFirstTimeConnectPrompt(bool isDark, Color cardBg, Color cardBorder) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: const Icon(
                Icons.cloud_sync_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Sync with MyAnimeList",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Connect your MAL account to unlock full backup, automated tracking synchronization, and personalized DNA analysis.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            _buildBenefitRow(Icons.sync_rounded, "Automated Real-Time Syncing", isDark),
            const SizedBox(height: 12),
            _buildBenefitRow(Icons.analytics_outlined, "Detailed Profile DNA Profiling", isDark),
            const SizedBox(height: 12),
            _buildBenefitRow(Icons.cloud_done_outlined, "Secure Watchlist Backups", isDark),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: AppColors.brandGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MalLoginPage()),
                  ).then((_) {
                    _syncActiveAccountToAccountsList();
                    _onLoginStateChanged();
                  });
                },
                icon: const Icon(Icons.login_rounded, color: Colors.white),
                label: const Text(
                  "Connect Account",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMalAccountManagementPanel(bool isDark, Color cardBg, Color cardBorder) {
    final accounts = HiveService.getMalAccounts();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  const Text(
                    "MYANIMELIST ACCOUNTS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              if (_isLoggedIn)
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MalLoginPage()),
                    ).then((_) {
                      _syncActiveAccountToAccountsList();
                      _onLoginStateChanged();
                    });
                  },
                  icon: Icon(Icons.add_rounded, size: 14, color: AppColors.accent),
                  label: Text(
                    "Add Account",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
                  ),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (!_isLoggedIn) ...[
            Text(
              "Save, backup, and restore your collection automatically on MyAnimeList servers.",
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MalLoginPage()),
                  ).then((_) {
                    _syncActiveAccountToAccountsList();
                    _onLoginStateChanged();
                  });
                },
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text("Connect MyAnimeList", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: accounts.isEmpty ? 1 : accounts.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                if (accounts.isEmpty) {
                  return _buildAccountTile(
                    username: _username ?? "MAL User",
                    pictureUrl: _pictureUrl,
                    isActive: true,
                    isDark: isDark,
                    onSwitch: null,
                    onRemove: () => _handleLogout(),
                  );
                }
                
                final acc = accounts[index];
                final username = acc['username'] as String? ?? 'Unknown';
                final picUrl = acc['pictureUrl'] as String?;
                final isActive = username == _username;
                
                return _buildAccountTile(
                  username: username,
                  pictureUrl: picUrl,
                  isActive: isActive,
                  isDark: isDark,
                  onSwitch: isActive ? null : () => _switchAccount(acc),
                  onRemove: () => _removeAccount(acc),
                );
              },
            ),
            
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MergePreviewPage()),
                      );
                      if (result == true) {
                        _loadStatsAndDetails();
                      }
                    },
                    icon: const Icon(Icons.merge_rounded, size: 16),
                    label: const Text("Merge Lists", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : () => _handleSync(true),
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text("Replace Local", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildAccountTile({
    required String username,
    required String? pictureUrl,
    required bool isActive,
    required bool isDark,
    required VoidCallback? onSwitch,
    required VoidCallback onRemove,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: isDark ? Colors.white10 : Colors.black12,
          backgroundImage: pictureUrl != null ? NetworkImage(pictureUrl) : null,
          child: pictureUrl == null
              ? Icon(Icons.person_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (isActive)
                Text(
                  "Active Account",
                  style: TextStyle(color: AppColors.completed, fontSize: 11, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
        if (onSwitch != null)
          TextButton(
            onPressed: onSwitch,
            child: const Text("Switch", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        IconButton(
          icon: Icon(isActive ? Icons.logout_rounded : Icons.delete_outline_rounded, 
            color: AppColors.error.withOpacity(0.8), 
            size: 20
          ),
          onPressed: onRemove,
          tooltip: isActive ? 'Sign Out' : 'Remove Account',
        ),
      ],
    );
  }

  void _loadStatsAndDetails() {
    final allItems = HiveService.getAllListItems();

    // Reset counters
    int totalAnime = 0;
    int completedAnime = 0;
    int watchingAnime = 0;
    int plannedAnime = 0;
    int ignoredAnime = 0;
    double animeScoreSum = 0.0;
    int animeScoreCount = 0;
    int epsWatched = 0;

    int totalManga = 0;
    int completedManga = 0;
    int readingManga = 0;
    int plannedManga = 0;
    int ignoredManga = 0;
    double mangaScoreSum = 0.0;
    int mangaScoreCount = 0;
    int chaptersRead = 0;

    for (var item in allItems) {
      final isManga = item.type == 'MANGA';
      final rating = item.userRating?.overall ?? 0.0;

      if (!isManga) {
        totalAnime++;
        epsWatched += item.episodeProgress;
        if (rating > 0) {
          animeScoreSum += rating;
          animeScoreCount++;
        }
        switch (item.category) {
          case AnimeCategory.completed:
            completedAnime++;
            break;
          case AnimeCategory.watching:
            watchingAnime++;
            break;
          case AnimeCategory.planned:
            plannedAnime++;
            break;
          case AnimeCategory.ignored:
            ignoredAnime++;
            break;
        }
      } else {
        totalManga++;
        chaptersRead += item.episodeProgress;
        if (rating > 0) {
          mangaScoreSum += rating;
          mangaScoreCount++;
        }
        switch (item.category) {
          case AnimeCategory.completed:
            completedManga++;
            break;
          case AnimeCategory.watching:
            readingManga++;
            break;
          case AnimeCategory.planned:
            plannedManga++;
            break;
          case AnimeCategory.ignored:
            ignoredManga++;
            break;
        }
      }
    }

    // Sort allItems by key or ID to get recent updates
    final sortedUpdates = List<AnimeListItem>.from(allItems)
      ..sort((a, b) => b.animeId.compareTo(a.animeId));
    _recentUpdates = sortedUpdates.take(4).toList();

    // Favorites: items rated high
    _favorites = allItems.where((item) => (item.userRating?.overall ?? 0.0) >= 8.5).toList();

    setState(() {
      _animeCount = totalAnime;
      _animeCompleted = completedAnime;
      _animeWatching = watchingAnime;
      _animePlanned = plannedAnime;
      _animeIgnored = ignoredAnime;
      _animeMeanScore = animeScoreCount > 0 ? (animeScoreSum / animeScoreCount) : 0.0;
      _animeEpsWatched = epsWatched;

      _mangaCount = totalManga;
      _mangaCompleted = completedManga;
      _mangaReading = readingManga;
      _mangaPlanned = plannedManga;
      _mangaIgnored = ignoredManga;
      _mangaMeanScore = mangaScoreCount > 0 ? (mangaScoreSum / mangaScoreCount) : 0.0;
      _mangaChaptersRead = chaptersRead;

      // Calculate formula values
      _dnaCompleteness = _animeCount > 0 ? ((_animeCompleted / _animeCount) * 10).clamp(1.0, 10.0) : 6.0;
      _dnaVariety = (5.0 + (_mangaCount / 15.0)).clamp(1.0, 10.0);
      double watchDays = (_animeEpsWatched * 24.0) / (60.0 * 24.0); // 24 min per ep
      double readDays = (_mangaChaptersRead * 5.0) / (60.0 * 24.0); // 5 min per chap
      _dnaActivity = (5.0 + (watchDays + readDays) * 0.5).clamp(1.0, 10.0);
      _dnaUniqueness = _animeMeanScore > 0 ? (12.0 - _animeMeanScore).clamp(4.0, 10.0) : 7.5;
      _dnaEngagement = (5.0 + (_animeWatching + _mangaReading) * 0.6).clamp(1.0, 10.0);
      _dnaOverall = ((_dnaCompleteness + _dnaVariety + _dnaActivity + _dnaUniqueness + _dnaEngagement) / 5.0);

      // Clean doubles
      _dnaCompleteness = double.parse(_dnaCompleteness.toStringAsFixed(1));
      _dnaVariety = double.parse(_dnaVariety.toStringAsFixed(1));
      _dnaActivity = double.parse(_dnaActivity.toStringAsFixed(1));
      _dnaUniqueness = double.parse(_dnaUniqueness.toStringAsFixed(1));
      _dnaEngagement = double.parse(_dnaEngagement.toStringAsFixed(1));
      _dnaOverall = double.parse(_dnaOverall.toStringAsFixed(1));
    });
  }

  Future<void> _handleSync(bool replace) async {
    setState(() {
      _isSyncing = true;
      _syncMessage = replace ? "Replacing local database with MyAnimeList data..." : "Merging MyAnimeList data with local database...";
      _syncSuccess = false;
    });

    try {
      final animeList = await MalAuthService.instance.getUserAnimeList();
      final mangaList = await MalAuthService.instance.getUserMangaList();

      if (replace) {
        await HiveService.clearAllListItems();
      }

      int importCount = 0;

      for (final item in animeList) {
        final node = item['node'] as Map<String, dynamic>;
        final status = item['list_status'] as Map<String, dynamic>;

        final int animeId = node['id'] ?? 0;
        if (animeId == 0) continue;

        AnimeCategory cat = AnimeCategory.planned;
        final malStatus = status['status'] as String? ?? 'plan_to_watch';
        if (malStatus == 'watching') cat = AnimeCategory.watching;
        else if (malStatus == 'completed') cat = AnimeCategory.completed;
        else if (malStatus == 'dropped') cat = AnimeCategory.ignored;
        else if (malStatus == 'on_hold') cat = AnimeCategory.watching;

        final double score = (status['score'] as num?)?.toDouble() ?? 0.0;
        final int watched = status['num_episodes_watched'] as int? ?? 0;
        final totalEps = node['num_episodes']?.toString() ?? '?';

        final existing = HiveService.getListItem(animeId);
        if (existing != null && !replace) {
          existing.category = cat;
          existing.episodeProgress = watched;
          if (score > 0) {
            existing.userRating = UserRating(overall: score);
          }
          existing.isMalSynced = true;
          await existing.save();
        } else {
          final newItem = AnimeListItem(
            animeId: animeId,
            title: node['title'] ?? 'Unknown Anime',
            image: node['main_picture']?['large'] ?? node['main_picture']?['medium'] ?? '',
            score: (node['mean'] as num?)?.toDouble(),
            genres: (node['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? [],
            category: cat,
            episodeProgress: watched,
            episodes: totalEps,
            userRating: score > 0 ? UserRating(overall: score) : null,
            type: node['media_type']?.toString().toUpperCase(),
            studios: (node['studios'] as List?)?.map((s) => s['name'] as String).toList() ?? [],
            year: node['start_season']?['year']?.toString(),
            isMalSynced: true,
          );
          await HiveService.saveListItemDirectly(newItem);
        }
        importCount++;
      }

      for (final item in mangaList) {
        final node = item['node'] as Map<String, dynamic>;
        final status = item['list_status'] as Map<String, dynamic>;

        final int mangaId = node['id'] ?? 0;
        if (mangaId == 0) continue;

        AnimeCategory cat = AnimeCategory.planned;
        final malStatus = status['status'] as String? ?? 'plan_to_read';
        if (malStatus == 'reading' || malStatus == 'watching') cat = AnimeCategory.watching;
        else if (malStatus == 'completed') cat = AnimeCategory.completed;
        else if (malStatus == 'dropped') cat = AnimeCategory.ignored;
        else if (malStatus == 'on_hold') cat = AnimeCategory.watching;

        final double score = (status['score'] as num?)?.toDouble() ?? 0.0;
        final int read = status['num_chapters_read'] as int? ?? 0;
        final totalChapters = node['num_chapters']?.toString() ?? '?';

        final existing = HiveService.getListItem(mangaId);
        if (existing != null && !replace) {
          existing.category = cat;
          existing.episodeProgress = read;
          if (score > 0) {
            existing.userRating = UserRating(overall: score);
          }
          existing.isMalSynced = true;
          await existing.save();
        } else {
          final newItem = AnimeListItem(
            animeId: mangaId,
            title: node['title'] ?? 'Unknown Manga',
            image: node['main_picture']?['large'] ?? node['main_picture']?['medium'] ?? '',
            score: (node['mean'] as num?)?.toDouble(),
            genres: (node['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? [],
            category: cat,
            episodeProgress: read,
            episodes: totalChapters,
            userRating: score > 0 ? UserRating(overall: score) : null,
            type: 'MANGA',
            year: node['start_season']?['year']?.toString(),
            isMalSynced: true,
          );
          await HiveService.saveListItemDirectly(newItem);
        }
        importCount++;
      }

      setState(() {
        _isSyncing = false;
        _syncSuccess = true;
        _syncMessage = "Sync completed successfully! Imported $importCount items.";
      });
      _loadStatsAndDetails();
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _syncSuccess = false;
        _syncMessage = "Sync failed: $e";
      });
    }
  }

  Color _getDnaBadgeColor(double score) {
    if (score >= 9.0) return AppColors.completed;
    if (score >= 7.5) return AppColors.accent;
    if (score >= 6.0) return AppColors.starYellow;
    return AppColors.error;
  }


  Widget _buildDnaCard(String title, double value, Color color, ValueChanged<double> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          if (_isEditingDNA) ...[
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
              ),
              child: Slider(
                value: value,
                min: 1.0,
                max: 10.0,
                divisions: 90,
                activeColor: color,
                inactiveColor: isDark ? Colors.white10 : Colors.black12,
                onChanged: onChanged,
              ),
            ),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final cardBorder = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Profile Dashboard",
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: (!_isLoggedIn && !_bypassConnectionPrompt)
            ? Center(
                child: SingleChildScrollView(
                  child: _buildFirstTimeConnectPrompt(isDark, cardBg, cardBorder),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // ── Cover Banner Stack ──
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Backdrop Blur Container
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: AppColors.darkSurface,
                      image: (_pictureUrl != null)
                          ? DecorationImage(
                              image: NetworkImage(_pictureUrl!),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withOpacity(0.45),
                                BlendMode.darken,
                              ),
                            )
                          : null,
                    ),
                    child: (_pictureUrl == null)
                        ? Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accent.withOpacity(0.8),
                                  AppColors.mauve.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          )
                        : null,
                  ),
                  // Cover details stack
                  Positioned(
                    bottom: -40,
                    left: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Avatar Photo
                        Container(
                          width: 88,
                          height: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              )
                            ],
                            image: (_pictureUrl != null)
                                ? DecorationImage(
                                    image: NetworkImage(_pictureUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: (_pictureUrl == null)
                              ? Container(
                                  color: cardBg,
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 40,
                                    color: isDark ? Colors.white30 : Colors.black38,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        // Username, badges, connection status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Text(
                                      "MEMBER",
                                      style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _isLoggedIn
                                          ? AppColors.completed.withOpacity(0.2)
                                          : AppColors.starYellow.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _isLoggedIn
                                            ? AppColors.completed.withOpacity(0.4)
                                            : AppColors.starYellow.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      _isLoggedIn ? "SYNCED" : "DEMO MODE",
                                      style: TextStyle(
                                        color: _isLoggedIn ? AppColors.completed : AppColors.starYellow,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isLoggedIn ? (_username ?? "MAL User") : "MuhammadGoi",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isLoggedIn
                                    ? "myanimelist.net/profile/$_username"
                                    : "Guest profile view",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),

              const SizedBox(height: 56),

              // ── Cover Mini Counters box ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            "ANIME SCORE",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white30 : Colors.black38,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded, color: AppColors.starYellow, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                _animeMeanScore > 0 ? _animeMeanScore.toStringAsFixed(2) : "0.00",
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 24, color: cardBorder),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            "DAYS WATCHED",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white30 : Colors.black38,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ((_animeEpsWatched * 24) / (60 * 24)).toStringAsFixed(1),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 24, color: cardBorder),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            "COMPLETED ITEMS",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white30 : Colors.black38,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (_animeCompleted + _mangaCompleted).toString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Sync Operation Message Panel ──
              if (_syncMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isSyncing
                        ? AppColors.accent.withAlpha(20)
                        : (_syncSuccess ? AppColors.completed.withAlpha(20) : AppColors.error.withAlpha(20)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isSyncing
                          ? AppColors.accent.withAlpha(80)
                      : (_syncSuccess ? AppColors.completed.withAlpha(80) : AppColors.error.withAlpha(80)),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isSyncing)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                        )
                      else
                        Icon(
                          _syncSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: _syncSuccess ? AppColors.completed : AppColors.error,
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _syncMessage!,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!_isSyncing)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _syncMessage = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Profile DNA & Ratings Spec ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.accent.withOpacity(0.04), AppColors.mauve.withOpacity(0.02)]
                        : [AppColors.accent.withOpacity(0.02), AppColors.mauve.withOpacity(0.01)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withOpacity(0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
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
                              "PROFILE DNA & RATINGS",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accent,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => setState(() => _isEditingDNA = !_isEditingDNA),
                              icon: Icon(Icons.tune_rounded, size: 14, color: AppColors.accent),
                              label: Text(
                                _isEditingDNA ? "Done" : "Customize",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent),
                              ),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                            ),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              onPressed: () {
                                _loadStatsAndDetails();
                                setState(() => _isEditingDNA = false);
                              },
                              icon: Icon(Icons.replay_rounded, size: 14, color: AppColors.accent),
                              label: Text(
                                "Reset",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent),
                              ),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DnaRadarChart(
                      completeness: _dnaCompleteness,
                      variety: _dnaVariety,
                      activity: _dnaActivity,
                      uniqueness: _dnaUniqueness,
                      engagement: _dnaEngagement,
                    ),
                    const SizedBox(height: 16),
                    // Grid Layout
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: _isEditingDNA ? 0.72 : 1.15,
                      children: [
                        _buildDnaCard(
                          "Overall Tier",
                          _dnaOverall,
                          _getDnaBadgeColor(_dnaOverall),
                          (v) => setState(() => _dnaOverall = double.parse(v.toStringAsFixed(1))),
                        ),
                        _buildDnaCard(
                          "Completeness",
                          _dnaCompleteness,
                          AppColors.completed,
                          (v) => setState(() => _dnaCompleteness = double.parse(v.toStringAsFixed(1))),
                        ),
                        _buildDnaCard(
                          "Genre Variety",
                          _dnaVariety,
                          AppColors.mauve,
                          (v) => setState(() => _dnaVariety = double.parse(v.toStringAsFixed(1))),
                        ),
                        _buildDnaCard(
                          "Activity",
                          _dnaActivity,
                          AppColors.starYellow,
                          (v) => setState(() => _dnaActivity = double.parse(v.toStringAsFixed(1))),
                        ),
                        _buildDnaCard(
                          "Uniqueness",
                          _dnaUniqueness,
                          Colors.pinkAccent,
                          (v) => setState(() => _dnaUniqueness = double.parse(v.toStringAsFixed(1))),
                        ),
                        _buildDnaCard(
                          "Engagement",
                          _dnaEngagement,
                          Colors.lightBlueAccent,
                          (v) => setState(() => _dnaEngagement = double.parse(v.toStringAsFixed(1))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Tab Switcher Selector ──
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabButton("overview", "Overview & Story"),
                      _buildTabButton("metrics", "Metrics & Stats"),
                      _buildTabButton("favorites", "Favorites"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Tab Content Views ──
              _buildTabContent(),

              const SizedBox(height: 24),

              // ── Connection Account Settings Panel ──
              _buildMalAccountManagementPanel(isDark, cardBg, cardBorder),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabId, String label) {
    final isSelected = _activeTab == tabId;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.black38),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final cardBorder = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;

    if (_activeTab == "overview") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio Statement
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(1.5))),
                    const SizedBox(width: 8),
                    const Text("NARRATIVE STATEMENT / BIOGRAPHY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white54)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Anime collector, manga researcher, and visual novels enthusiast. Special interest in dark psychological thrillers, cyberpunk aesthetics, and futuristic sci-fi series. Ready to connect, exchange detailed reviews, and configure dynamic recommendation lists!",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.45,
                  ),
                  maxLines: _synopsisExpanded ? null : 3,
                  overflow: _synopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _synopsisExpanded = !_synopsisExpanded),
                  child: Row(
                    children: [
                      Icon(
                        _synopsisExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _synopsisExpanded ? "Collapse Narrative" : "Read Full Storyline",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Updates Feed
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(1.5))),
                    const SizedBox(width: 8),
                    const Text("RECENT DATABASE UPDATES & FEED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white54)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_recentUpdates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        "No list items recorded yet.",
                        style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentUpdates.length,
                    separatorBuilder: (context, index) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final item = _recentUpdates[index];
                      final isManga = item.type == 'MANGA';
                      return InkWell(
                        onTap: () {
                          if (!isManga) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailPage(
                                  animeId: item.animeId,
                                  onBack: () => Navigator.pop(context),
                                ),
                              ),
                            );
                          }
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.image,
                                width: 44,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 44,
                                  height: 56,
                                  color: isDark ? Colors.white10 : Colors.black12,
                                  child: const Icon(Icons.image_not_supported, size: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isManga ? Colors.pink.withOpacity(0.12) : AppColors.accent.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isManga ? "MANGA" : (item.type ?? "ANIME"),
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                            color: isManga ? Colors.pink : AppColors.accent,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        item.category.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "(${isManga ? 'Ch.' : 'Ep.'} ${item.episodeProgress})",
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                      ),
                                      if (item.userRating?.overall != null) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.star_rounded, color: AppColors.starYellow, size: 10),
                                        const SizedBox(width: 2),
                                        Text(
                                          item.userRating!.overall.toString(),
                                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          )
        ],
      );
    } else if (_activeTab == "metrics") {
      final totalAnime = _animeCount;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Anime stats card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(1.5))),
                    const SizedBox(width: 8),
                    const Text("ANIME STATISTICAL BREAKDOWN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white54)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMetricBar("Completed", _animeCompleted, totalAnime, AppColors.completed),
                const SizedBox(height: 12),
                _buildMetricBar("Watching", _animeWatching, totalAnime, AppColors.accent),
                const SizedBox(height: 12),
                _buildMetricBar("Planned", _animePlanned, totalAnime, AppColors.mauve),
                const SizedBox(height: 12),
                _buildMetricBar("Ignored / Dropped", _animeIgnored, totalAnime, AppColors.error),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Manga stats card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 12, decoration: BoxDecoration(color: Colors.pink, borderRadius: BorderRadius.circular(1.5))),
                    const SizedBox(width: 8),
                    const Text("MANGA STATISTICAL BREAKDOWN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white54)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildMangaStatBox("Chapters Read", _mangaChaptersRead.toString(), Colors.pinkAccent)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMangaStatBox("Total Entries", _mangaCount.toString(), Colors.pinkAccent)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMangaStatBox("Mean Score", _mangaMeanScore > 0 ? _mangaMeanScore.toStringAsFixed(2) : "0.00", Colors.pinkAccent)),
                  ],
                )
              ],
            ),
          ),
        ],
      );
    } else if (_activeTab == "favorites") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Favorite Shows
          Row(
            children: [
              Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(1.5))),
              const SizedBox(width: 8),
              const Text("FAVORITE SHOWS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 12),
          if (_favorites.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
              ),
              child: Center(
                child: Text(
                  "No highly rated shows added to favorites.",
                  style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 13),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _favorites.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final fav = _favorites[index];
                return GestureDetector(
                  onTap: () {
                    if (fav.type != 'MANGA') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailPage(
                            animeId: fav.animeId,
                            onBack: () => Navigator.pop(context),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                      image: DecorationImage(
                        image: NetworkImage(fav.image),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          fav.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // Favorite Characters (Mock grid from Jikan/Spec)
          Row(
            children: [
              Container(width: 3, height: 12, decoration: BoxDecoration(color: Colors.pink, borderRadius: BorderRadius.circular(1.5))),
              const SizedBox(width: 8),
              const Text("FAVORITE CHARACTERS & CAST", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.72,
            children: [
              _buildMockCharCard("Lelouch Lamperouge", "https://cdn.myanimelist.net/images/characters/8/406163.jpg", "Main"),
              _buildMockCharCard("Rintarou Okabe", "https://cdn.myanimelist.net/images/characters/6/122645.jpg", "Main"),
              _buildMockCharCard("Killua Zoldyck", "https://cdn.myanimelist.net/images/characters/2/208321.jpg", "Main"),
              _buildMockCharCard("Frieren", "https://cdn.myanimelist.net/images/characters/16/483669.jpg", "Main"),
            ],
          )
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMetricBar(String label, int value, int total, Color color) {
    final double percent = total > 0 ? (value / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Text(
              "$value (${(percent * 100).toStringAsFixed(1)}%)",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percent,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMangaStatBox(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white60,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockCharCard(String name, String imgUrl, String role) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final cardBorder = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        image: DecorationImage(
          image: NetworkImage(imgUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Colors.black87, Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.pink.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: const TextStyle(color: Colors.pink, fontSize: 8, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
