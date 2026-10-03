import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/models/anime_list_item.dart';

class TierConfig {
  String id;
  TextEditingController titleController;
  TextEditingController fromController;
  TextEditingController toController;
  Color color;
  List<AnimeListItem> freeAnimes;
  bool isExpanded;

  TierConfig({
    required this.id,
    required String title,
    required double from,
    required double to,
    required this.color,
    List<AnimeListItem>? freeAnimes,
    this.isExpanded = false,
  })  : titleController = TextEditingController(text: title),
        fromController = TextEditingController(text: from.toStringAsFixed(1)),
        toController = TextEditingController(text: to.toStringAsFixed(1)),
        freeAnimes = freeAnimes ?? [];

  double get from => double.tryParse(fromController.text.trim()) ?? 0.0;
  double get to => double.tryParse(toController.text.trim()) ?? 10.0;
  String get title => titleController.text.trim();

  void dispose() {
    titleController.dispose();
    fromController.dispose();
    toController.dispose();
  }
}

class ShareLayeredListPage extends StatefulWidget {
  const ShareLayeredListPage({super.key});

  @override
  State<ShareLayeredListPage> createState() => _ShareLayeredListPageState();
}

class _ShareLayeredListPageState extends State<ShareLayeredListPage> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isProcessing = false;

  // Source mode: 'my_rating', 'overall_score', or 'free'
  String _sourceMode = 'my_rating';
  String _customTitle = "My Anime Tier Spectrum";
  String _sortBy = 'rating'; // 'rating', 'title'

  // Dynamic Tiers
  late List<TierConfig> _tiers;

  // Filters (Multi-select like My List)
  Set<String> _selectedGenres = {};
  Set<String> _selectedStudios = {};
  Set<String> _selectedCategories = {}; // 'watching', 'completed', 'planned', 'ignored'
  Set<String> _selectedYears = {};
  Set<String> _selectedSeasons = {}; // 'winter', 'spring', 'summer', 'fall'
  Set<String> _selectedEpisodes = {}; // '1', '1-13', '14-26', '27+', 'custom'
  bool _includeUnknownEp = false;
  final TextEditingController _customEpFromController = TextEditingController(text: '1');
  final TextEditingController _customEpToController = TextEditingController(text: '12');

  int get _activeFilterCount =>
      _selectedCategories.length +
      _selectedEpisodes.length +
      (_includeUnknownEp ? 1 : 0) +
      _selectedSeasons.length +
      _selectedYears.length +
      _selectedGenres.length +
      _selectedStudios.length;

  String? get _customRangeWarning {
    final from = int.tryParse(_customEpFromController.text.trim());
    final to = int.tryParse(_customEpToController.text.trim());
    if (from == null || to == null) return "Enter valid whole numbers for episode range";
    if (from < 0 || to < 0) return "Negative values are not allowed";
    if (from > to) return "From ($from) cannot be greater than To ($to)";
    return null;
  }

  late List<AnimeListItem> _allItems;

  static const List<Color> _presetColors = [
    Color(0xFFFF7F7F), // Red
    Color(0xFFFFBF7F), // Orange-Red
    Color(0xFFFFDF7F), // Warm Yellow
    Color(0xFFFFFF7F), // Yellow
    Color(0xFFBFFF7F), // Light Green
    Color(0xFF7FFFFF), // Cyan
    Color(0xFF7FBFFF), // Blue
    Color(0xFFFF7FFF), // Pink
    Color(0xFFB388FF), // Purple
  ];

  @override
  void initState() {
    super.initState();
    _allItems = HiveService.getAllListItems();
    HiveService.healListItemsMetadata();
    _initDefaultTiers();
  }

  void _initDefaultTiers() {
    _tiers = [
      TierConfig(id: 'tier_1', title: 'S', from: 9.0, to: 10.0, color: _presetColors[0]),
      TierConfig(id: 'tier_2', title: 'A', from: 8.0, to: 8.9, color: _presetColors[1]),
      TierConfig(id: 'tier_3', title: 'B', from: 7.0, to: 7.9, color: _presetColors[2]),
      TierConfig(id: 'tier_4', title: 'C', from: 6.0, to: 6.9, color: _presetColors[3]),
      TierConfig(id: 'tier_5', title: 'D', from: 1.0, to: 5.9, color: _presetColors[4]),
    ];
  }

  @override
  void dispose() {
    _customEpFromController.dispose();
    _customEpToController.dispose();
    for (var tier in _tiers) {
      tier.dispose();
    }
    super.dispose();
  }

  void _addTier() {
    setState(() {
      final index = _tiers.length;
      final color = _presetColors[index % _presetColors.length];
      _tiers.add(
        TierConfig(
          id: 'tier_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Tier ${index + 1}',
          from: 0.0,
          to: 5.0,
          color: color,
        ),
      );
    });
  }

  void _removeTier(TierConfig tier) {
    if (_tiers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot remove the only remaining tier."), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() {
      _tiers.remove(tier);
      tier.dispose();
    });
  }

  void _pickTierColor(TierConfig tier) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Select Tier Color", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presetColors.map((color) {
              final isSelected = tier.color.value == color.value;
              return GestureDetector(
                onTap: () {
                  setState(() => tier.color = color);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.black26,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 20, color: Colors.black87) : null,
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ],
        );
      },
    );
  }

  List<String> _getValidationWarnings() {
    if (_sourceMode == 'free') return [];
    final warnings = <String>[];

    // Inverted bounds check
    for (int i = 0; i < _tiers.length; i++) {
      final t = _tiers[i];
      if (t.from > t.to) {
        final name = t.title.isNotEmpty ? t.title : "Tier ${i + 1}";
        warnings.add("'$name': 'From' (${t.from.toStringAsFixed(1)}) is greater than 'To' (${t.to.toStringAsFixed(1)})");
      }
    }

    // Pairwise overlap check
    for (int i = 0; i < _tiers.length; i++) {
      for (int j = i + 1; j < _tiers.length; j++) {
        final t1 = _tiers[i];
        final t2 = _tiers[j];
        if (t1.from > t1.to || t2.from > t2.to) continue;

        final overlapStart = t1.from > t2.from ? t1.from : t2.from;
        final overlapEnd = t1.to < t2.to ? t1.to : t2.to;

        if (overlapStart < overlapEnd) {
          final name1 = t1.title.isNotEmpty ? t1.title : "Tier ${i + 1}";
          final name2 = t2.title.isNotEmpty ? t2.title : "Tier ${j + 1}";
          warnings.add("Overlap: '$name1' & '$name2' (${overlapStart.toStringAsFixed(1)} - ${overlapEnd.toStringAsFixed(1)})");
        }
      }
    }
    return warnings;
  }

  Set<String> _getAllGenres() {
    final genres = <String>{};
    for (final item in _allItems) {
      genres.addAll(item.genres);
    }
    return genres;
  }

  Set<String> _getCompletedStudios() {
    final studios = <String>{};
    final completedItems = _allItems.where((i) => i.category == AnimeCategory.completed);
    for (final item in completedItems) {
      if (item.studios != null) {
        studios.addAll(item.studios!.where((s) => s.trim().isNotEmpty));
      }
    }
    if (studios.isEmpty) {
      for (final item in _allItems) {
        if (item.studios != null) {
          studios.addAll(item.studios!.where((s) => s.trim().isNotEmpty));
        }
      }
    }
    return studios;
  }

  List<String> _getAllYears() {
    final currentMaxYear = DateTime.now().year + 2;
    final years = <String>{};
    for (final item in _allItems) {
      if (item.year != null && item.year!.trim().isNotEmpty) {
        final yStr = item.year!.trim();
        final yNum = int.tryParse(yStr);
        if (yNum != null && yNum >= 1917 && yNum <= currentMaxYear) {
          years.add(yStr);
        }
      }
    }
    final sorted = years.toList();
    sorted.sort((a, b) => b.compareTo(a));
    return sorted;
  }

  bool _matchesFilters(AnimeListItem item) {
    if (_selectedGenres.isNotEmpty && !_selectedGenres.any((g) => item.genres.contains(g))) {
      return false;
    }
    if (_selectedStudios.isNotEmpty && (item.studios == null || !_selectedStudios.any((s) => item.studios!.contains(s)))) {
      return false;
    }
    if (_selectedCategories.isNotEmpty) {
      final catStr = item.category.name.toLowerCase();
      if (!_selectedCategories.contains(catStr)) {
        return false;
      }
    }
    if (_selectedYears.isNotEmpty && (item.year == null || !_selectedYears.contains(item.year!.trim()))) {
      return false;
    }
    if (_selectedSeasons.isNotEmpty && (item.season == null || !_selectedSeasons.contains(item.season!.toLowerCase()))) {
      return false;
    }

    final int? parsedEp = int.tryParse(item.episodes);
    final bool isUnknownEp = parsedEp == null || parsedEp <= 0 || item.episodes == '?' || item.episodes.isEmpty;

    if (isUnknownEp) {
      // If user selected episode filters, only keep unknown if _includeUnknownEp is checked
      if (_selectedEpisodes.isNotEmpty && !_includeUnknownEp) {
        return false;
      }
    } else {
      if (_selectedEpisodes.isNotEmpty) {
        final ep = parsedEp;
        bool matchesEp = false;
        for (final opt in _selectedEpisodes) {
          if (opt == '1' && ep == 1) matchesEp = true;
          if (opt == '1-13' && ep >= 1 && ep <= 13) matchesEp = true;
          if (opt == '14-26' && ep >= 14 && ep <= 26) matchesEp = true;
          if (opt == '27+' && ep >= 27) matchesEp = true;
          if (opt == 'custom') {
            final from = int.tryParse(_customEpFromController.text.trim()) ?? 0;
            final to = int.tryParse(_customEpToController.text.trim()) ?? 9999;
            final validFrom = from < 0 ? 0 : from;
            final validTo = to < validFrom ? validFrom : to;
            if (ep >= validFrom && ep <= validTo) {
              matchesEp = true;
            }
          }
        }
        if (!matchesEp) {
          return false;
        }
      }
    }

    return true;
  }

  Map<TierConfig, List<AnimeListItem>> _groupAnimeIntoLayers() {
    final Map<TierConfig, List<AnimeListItem>> grouped = {
      for (final tier in _tiers) tier: []
    };

    if (_sourceMode == 'free') {
      for (final tier in _tiers) {
        final list = tier.freeAnimes.where(_matchesFilters).toList();
        list.sort((a, b) {
          if (_sortBy == 'title') {
            return a.title.compareTo(b.title);
          } else {
            final double rA = a.userRating?.overall ?? a.score ?? 0.0;
            final double rB = b.userRating?.overall ?? b.score ?? 0.0;
            return rB.compareTo(rA);
          }
        });
        grouped[tier] = list;
      }
      return grouped;
    }

    for (final item in _allItems) {
      if (!_matchesFilters(item)) continue;

      double rating = 0.0;
      if (_sourceMode == 'my_rating') {
        rating = item.userRating?.overall ?? 0.0;
      } else {
        rating = item.score ?? 0.0;
      }

      if (rating <= 0.0 || rating > 10.0) continue;

      for (final tier in _tiers) {
        if (rating >= tier.from && rating <= tier.to) {
          grouped[tier]?.add(item);
          break; // Place in first matching tier
        }
      }
    }

    // Sort items within each tier
    for (final tier in grouped.keys) {
      grouped[tier]!.sort((a, b) {
        if (_sortBy == 'title') {
          return a.title.compareTo(b.title);
        } else {
          final double rA = _sourceMode == 'my_rating' ? (a.userRating?.overall ?? 0.0) : (a.score ?? 0.0);
          final double rB = _sourceMode == 'my_rating' ? (b.userRating?.overall ?? 0.0) : (b.score ?? 0.0);
          return rB.compareTo(rA);
        }
      });
    }

    return grouped;
  }

  void _showAddAnimePicker(TierConfig tier) {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = _allItems.where((anime) {
              if (searchQuery.isNotEmpty && !anime.title.toLowerCase().contains(searchQuery.toLowerCase())) {
                return false;
              }
              return _matchesFilters(anime);
            }).toList();

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Add Anime to ${tier.title.isNotEmpty ? tier.title : 'Tier'}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: "Search anime title...",
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) => setModalState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text("No anime matching search or filters"))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (ctx, index) {
                                final anime = filtered[index];
                                final isAdded = tier.freeAnimes.any((a) => a.animeId == anime.animeId);
                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: CachedNetworkImage(
                                      imageUrl: anime.image,
                                      width: 40,
                                      height: 55,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(color: Colors.grey[800], width: 40, height: 55),
                                    ),
                                  ),
                                  title: Text(anime.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  subtitle: Text("Score: ${anime.score ?? 0.0} | ${anime.category.name}", style: const TextStyle(fontSize: 11)),
                                  trailing: IconButton(
                                    icon: Icon(
                                      isAdded ? Icons.check_circle : Icons.add_circle_outline,
                                      color: isAdded ? AppColors.accent : Colors.grey,
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        if (isAdded) {
                                          tier.freeAnimes.removeWhere((a) => a.animeId == anime.animeId);
                                        } else {
                                          tier.freeAnimes.add(anime);
                                        }
                                      });
                                      setState(() {});
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("Done (${tier.freeAnimes.length} Selected)", style: const TextStyle(color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMultiGenrePicker(List<String> allGenres) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Select Filter Genres", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() => _selectedGenres.clear());
                                setState(() {});
                              },
                              child: const Text("Clear All", style: TextStyle(fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: () {
                                setModalState(() => _selectedGenres = Set.from(allGenres));
                                setState(() {});
                              },
                              child: const Text("Select All", style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        )
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: allGenres.length,
                        itemBuilder: (context, index) {
                          final genre = allGenres[index];
                          final isSelected = _selectedGenres.contains(genre);
                          return CheckboxListTile(
                            title: Text(genre, style: const TextStyle(fontSize: 13)),
                            value: isSelected,
                            activeColor: AppColors.accent,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  _selectedGenres.add(genre);
                                } else {
                                  _selectedGenres.remove(genre);
                                }
                              });
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Apply Filter", style: TextStyle(color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMultiStudioPicker(List<String> allStudios) {
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredStudios = query.isEmpty
                ? allStudios
                : allStudios.where((s) => s.toLowerCase().contains(query.toLowerCase())).toList();

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Select Studios / Producers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() => _selectedStudios.clear());
                                setState(() {});
                              },
                              child: const Text("Clear All", style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: "Search studios...",
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (v) => setModalState(() => query = v),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredStudios.isEmpty
                          ? const Center(child: Text("No studios found"))
                          : ListView.builder(
                              itemCount: filteredStudios.length,
                              itemBuilder: (context, index) {
                                final studio = filteredStudios[index];
                                final isSelected = _selectedStudios.contains(studio);
                                return CheckboxListTile(
                                  title: Text(studio, style: const TextStyle(fontSize: 13)),
                                  value: isSelected,
                                  activeColor: const Color(0xFFEC4899),
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        _selectedStudios.add(studio);
                                      } else {
                                        _selectedStudios.remove(studio);
                                      }
                                    });
                                    setState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                        onPressed: () => Navigator.pop(context),
                        child: Text("Apply (${_selectedStudios.length} Selected)", style: const TextStyle(color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMultiYearPicker(List<String> allYears) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Select Release Years", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() => _selectedYears.clear());
                                setState(() {});
                              },
                              child: const Text("Clear All", style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        )
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: allYears.length,
                        itemBuilder: (context, index) {
                          final year = allYears[index];
                          final isSelected = _selectedYears.contains(year);
                          return CheckboxListTile(
                            title: Text(year, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            value: isSelected,
                            activeColor: const Color(0xFF14B8A6),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  _selectedYears.add(year);
                                } else {
                                  _selectedYears.remove(year);
                                }
                              });
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                        onPressed: () => Navigator.pop(context),
                        child: Text("Apply (${_selectedYears.length} Selected)", style: const TextStyle(color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleFilterCategory(String cat) {
    setState(() {
      if (_selectedCategories.contains(cat)) {
        _selectedCategories.remove(cat);
      } else {
        _selectedCategories.add(cat);
      }
    });
  }

  void _toggleFilterEpisode(String ep) {
    setState(() {
      if (_selectedEpisodes.contains(ep)) {
        _selectedEpisodes.remove(ep);
      } else {
        _selectedEpisodes.add(ep);
      }
    });
  }

  void _toggleFilterSeason(String s) {
    setState(() {
      if (_selectedSeasons.contains(s)) {
        _selectedSeasons.remove(s);
      } else {
        _selectedSeasons.add(s);
      }
    });
  }

  Color _seasonColor(String s) {
    switch (s.toLowerCase()) {
      case 'spring': return const Color(0xFF10B981);
      case 'summer': return const Color(0xFFF59E0B);
      case 'fall': return const Color(0xFFEA580C);
      case 'winter': return const Color(0xFF0EA5E9);
      default: return AppColors.accent;
    }
  }

  IconData _seasonIcon(String s) {
    switch (s.toLowerCase()) {
      case 'spring': return Icons.local_florist_rounded;
      case 'summer': return Icons.wb_sunny_rounded;
      case 'fall': return Icons.park_rounded;
      case 'winter': return Icons.ac_unit_rounded;
      default: return Icons.wb_cloudy_rounded;
    }
  }

  Widget _buildFilterLabel(String label, IconData icon, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? color
                : (isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark ? const Color(0xFF2E344A) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _capturePng() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Capture PNG failed: $e");
      return null;
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) throw Exception("Capture failed");

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/shared_layered_spectrum.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My Layered Anime Tier Spectrum!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Share failed: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _downloadImage() async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) throw Exception("Capture failed");

      if (Platform.isWindows) {
        final outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Layered Spectrum Image',
          fileName: 'layered_spectrum.png',
          type: FileType.custom,
          allowedExtensions: ['png'],
        );
        if (outputFile == null) return;
        String savePath = outputFile;
        if (!savePath.toLowerCase().endsWith('.png')) {
          savePath = '$savePath.png';
        }
        await File(savePath).writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Image saved successfully!"),
              backgroundColor: AppColors.completed,
              action: SnackBarAction(
                label: "Open Folder",
                textColor: Colors.white,
                onPressed: () {
                  final dir = File(savePath).parent.path;
                  Process.run('explorer.exe', [dir]);
                },
              ),
            ),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/layered_spectrum.png');
      await file.writeAsBytes(bytes);

      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }

      if (hasAccess) {
        await Gal.putImage(file.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Image saved to gallery successfully!"),
              backgroundColor: AppColors.completed,
            ),
          );
        }
      } else {
        throw Exception("Storage access denied");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Download failed: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupedData = _groupAnimeIntoLayers();
    final warnings = _getValidationWarnings();

    final allGenres = _getAllGenres().toList()..sort();
    final completedStudios = _getCompletedStudios().toList()..sort();
    final allYears = _getAllYears();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Create Layered List Image", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Settings & Customization Panel
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      const Text(
                        "Configure Spectrum & Filters",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),

                      // Source Dropdown & Header Title
                      Row(
                        children: [
                          const Text("Source: ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _sourceMode,
                              onChanged: (val) {
                                if (val != null) setState(() => _sourceMode = val);
                              },
                              items: const [
                                DropdownMenuItem(value: 'my_rating', child: Text("My Rating")),
                                DropdownMenuItem(value: 'overall_score', child: Text("MAL Score")),
                                DropdownMenuItem(value: 'free', child: Text("Free Mode (Manual Selection)")),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: "Image Header Title",
                          labelStyle: TextStyle(fontSize: 12),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) => setState(() => _customTitle = val),
                        controller: TextEditingController(text: _customTitle)..selection = TextSelection.collapsed(offset: _customTitle.length),
                      ),
                      const SizedBox(height: 16),

                      // ── Anime Filters Section (Multi-select, My List Style) ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 18, color: AppColors.accent),
                              const SizedBox(width: 8),
                              const Text("Filter Anime Items", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              if (_activeFilterCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$_activeFilterCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_activeFilterCount > 0)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedCategories.clear();
                                  _selectedEpisodes.clear();
                                  _selectedGenres.clear();
                                  _selectedStudios.clear();
                                  _selectedYears.clear();
                                  _selectedSeasons.clear();
                                  _includeUnknownEp = false;
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 14),
                              label: const Text("Reset All", style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 1. Categories (Multi-select)
                      _buildFilterLabel("Categories", Icons.category_rounded, _selectedCategories.length),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterChip(
                            label: "Watching",
                            icon: Icons.play_circle_outline,
                            isSelected: _selectedCategories.contains('watching'),
                            color: const Color(0xFF10B981),
                            onTap: () => _toggleFilterCategory('watching'),
                            isDark: isDark,
                          ),
                          _buildFilterChip(
                            label: "Completed",
                            icon: Icons.check_circle_outline,
                            isSelected: _selectedCategories.contains('completed'),
                            color: const Color(0xFF3B82F6),
                            onTap: () => _toggleFilterCategory('completed'),
                            isDark: isDark,
                          ),
                          _buildFilterChip(
                            label: "Planned",
                            icon: Icons.bookmark_outline,
                            isSelected: _selectedCategories.contains('planned'),
                            color: const Color(0xFFF59E0B),
                            onTap: () => _toggleFilterCategory('planned'),
                            isDark: isDark,
                          ),
                          _buildFilterChip(
                            label: "Ignored",
                            icon: Icons.visibility_off_outlined,
                            isSelected: _selectedCategories.contains('ignored'),
                            color: const Color(0xFF64748B),
                            onTap: () => _toggleFilterCategory('ignored'),
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 2. Episodes (Multi-select + Custom range + Unknown checkbox)
                      _buildFilterLabel("Episodes", Icons.video_library_rounded, _selectedEpisodes.length + (_includeUnknownEp ? 1 : 0)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterChip(
                            label: "1 Ep (Movie)",
                            isSelected: _selectedEpisodes.contains('1'),
                            color: const Color(0xFF8B5CF6),
                            onTap: () => _toggleFilterEpisode('1'),
                            isDark: isDark,
                          ),
                          _buildFilterChip(
                            label: "1 - 13 eps (Short)",
                            isSelected: _selectedEpisodes.contains('1-13'),
                            color: const Color(0xFF06B6D4),
                            onTap: () => _toggleFilterEpisode('1-13'),
                            isDark: isDark,
                          ),
                          _buildFilterChip(
                            label: "14 - 26 eps (Standard)",
                            isSelected: _selectedEpisodes.contains('14-26'),
                            color: const Color(0xFF10B981),
                            onTap: () => _toggleFilterEpisode('14-26'),
                            isDark: isDark,
                          ),
                          _buildFilterChip(
                            label: "27+ eps (Long)",
                            isSelected: _selectedEpisodes.contains('27+'),
                            color: const Color(0xFFF97316),
                            onTap: () => _toggleFilterEpisode('27+'),
                            isDark: isDark,
                          ),
                          _buildFilterChip(
                            label: "Custom Range",
                            icon: Icons.tune_rounded,
                            isSelected: _selectedEpisodes.contains('custom'),
                            color: AppColors.accent,
                            onTap: () => _toggleFilterEpisode('custom'),
                            isDark: isDark,
                          ),
                        ],
                      ),

                      // Custom range inputs
                      if (_selectedEpisodes.contains('custom')) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _customEpFromController,
                                      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      decoration: const InputDecoration(
                                        labelText: "From (Ep)",
                                        hintText: "e.g. 1",
                                        labelStyle: TextStyle(fontSize: 11),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(),
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _customEpToController,
                                      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      decoration: const InputDecoration(
                                        labelText: "To (Ep)",
                                        hintText: "e.g. 24",
                                        labelStyle: TextStyle(fontSize: 11),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(),
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              if (_customRangeWarning != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    _customRangeWarning!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Unknown end episode checkbox
                      InkWell(
                        onTap: () => setState(() => _includeUnknownEp = !_includeUnknownEp),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _includeUnknownEp,
                                  activeColor: AppColors.accent,
                                  onChanged: (v) => setState(() => _includeUnknownEp = v ?? false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Include Unknown End Episodes",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      "e.g. One Piece, ongoing with '?' / no fixed final episode",
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. Season & Year (Multi-select)
                      _buildFilterLabel("Season & Year", Icons.calendar_month_rounded, _selectedSeasons.length + _selectedYears.length),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...['Spring', 'Summer', 'Fall', 'Winter'].map((s) {
                            final isSel = _selectedSeasons.contains(s.toLowerCase());
                            return _buildFilterChip(
                              label: s,
                              icon: _seasonIcon(s),
                              isSelected: isSel,
                              color: _seasonColor(s),
                              onTap: () => _toggleFilterSeason(s.toLowerCase()),
                              isDark: isDark,
                            );
                          }),
                          OutlinedButton.icon(
                            onPressed: () => _showMultiYearPicker(allYears),
                            icon: const Icon(Icons.calendar_today_rounded, size: 14),
                            label: Text(
                              _selectedYears.isEmpty ? "All Years" : "Years (${_selectedYears.length})",
                              style: const TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              side: BorderSide(
                                color: _selectedYears.isNotEmpty
                                    ? const Color(0xFF14B8A6)
                                    : (isDark ? const Color(0xFF2E344A) : const Color(0xFFE2E8F0)),
                              ),
                              foregroundColor: _selectedYears.isNotEmpty ? const Color(0xFF14B8A6) : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 4. Genres & Studios
                      _buildFilterLabel("Genres & Studios", Icons.local_movies_rounded, _selectedGenres.length + _selectedStudios.length),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showMultiGenrePicker(allGenres),
                              icon: const Icon(Icons.tag_rounded, size: 15),
                              label: Text(
                                _selectedGenres.isEmpty ? 'Genres (All)' : 'Genres (${_selectedGenres.length})',
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                side: BorderSide(
                                  color: _selectedGenres.isNotEmpty
                                      ? const Color(0xFF6366F1)
                                      : (isDark ? const Color(0xFF2E344A) : const Color(0xFFE2E8F0)),
                                ),
                                foregroundColor: _selectedGenres.isNotEmpty ? const Color(0xFF6366F1) : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showMultiStudioPicker(completedStudios.toList()..sort()),
                              icon: const Icon(Icons.movie_filter_rounded, size: 15),
                              label: Text(
                                _selectedStudios.isEmpty ? 'Studios (All)' : 'Studios (${_selectedStudios.length})',
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                side: BorderSide(
                                  color: _selectedStudios.isNotEmpty
                                      ? const Color(0xFFEC4899)
                                      : (isDark ? const Color(0xFF2E344A) : const Color(0xFFE2E8F0)),
                                ),
                                foregroundColor: _selectedStudios.isNotEmpty ? const Color(0xFFEC4899) : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Validation Warnings Banner
                      if (warnings.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                                  SizedBox(width: 6),
                                  Text("Range Overlap Warning", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ...warnings.map((w) => Text("• $w", style: const TextStyle(color: Colors.amber, fontSize: 11))),
                            ],
                          ),
                        ),

                      // Tiers List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Tiers Configuration (${_tiers.length} Tiers)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          // Sort By
                          Row(
                            children: [
                              const Text("Sort: ", style: TextStyle(fontSize: 11, color: Colors.grey)),
                              DropdownButton<String>(
                                value: _sortBy,
                                underline: const SizedBox(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                items: const [
                                  DropdownMenuItem(value: 'rating', child: Text("By Score")),
                                  DropdownMenuItem(value: 'title', child: Text("By Title")),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _sortBy = v);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tiers List Cards
                      ...List.generate(_tiers.length, (index) {
                        final tier = _tiers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tier Card Header
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _pickTierColor(tier),
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: tier.color,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white30),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tier.title.isNotEmpty ? "Tier ${index + 1}: ${tier.title}" : "Tier ${index + 1}",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: tier.color),
                                      ),
                                    ),
                                    // Tier Options Menu (Includes Remove Tier)
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 18),
                                      onSelected: (val) {
                                        if (val == 'color') {
                                          _pickTierColor(tier);
                                        } else if (val == 'clear') {
                                          setState(() => tier.freeAnimes.clear());
                                        } else if (val == 'remove') {
                                          _removeTier(tier);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'color',
                                          child: Row(
                                            children: [
                                              Icon(Icons.palette_outlined, size: 16),
                                              SizedBox(width: 8),
                                              Text("Change Color", style: TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        if (_sourceMode == 'free')
                                          const PopupMenuItem(
                                            value: 'clear',
                                            child: Row(
                                              children: [
                                                Icon(Icons.clear_all, size: 16),
                                                SizedBox(width: 8),
                                                Text("Clear Anime", style: TextStyle(fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, color: Colors.red, size: 16),
                                              SizedBox(width: 8),
                                              Text("Remove Tier", style: TextStyle(color: Colors.red, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Title and Range Inputs
                                TextField(
                                  controller: tier.titleController,
                                  decoration: InputDecoration(
                                    labelText: "Tier Title / Name",
                                    hintText: "e.g. S, Masterpiece, God Tier",
                                    labelStyle: const TextStyle(fontSize: 11),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: const OutlineInputBorder(),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                  onChanged: (_) => setState(() {}),
                                ),

                                // Double Number Inputs: From & To (Only in auto rating modes)
                                if (_sourceMode != 'free') ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: tier.fromController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            labelText: "From (Score)",
                                            hintText: "e.g. 8.0",
                                            labelStyle: TextStyle(fontSize: 11),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(),
                                          ),
                                          style: const TextStyle(fontSize: 12),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: tier.toController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            labelText: "To (Score)",
                                            hintText: "e.g. 8.9",
                                            labelStyle: TextStyle(fontSize: 11),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(),
                                          ),
                                          style: const TextStyle(fontSize: 12),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                // Free Mode Manual Anime Selection & Collapsible Preview
                                if (_sourceMode == 'free') ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Assigned Anime (${tier.freeAnimes.length})",
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _showAddAnimePicker(tier),
                                        icon: const Icon(Icons.add, size: 14),
                                        label: const Text("Add Anime", style: TextStyle(fontSize: 11)),
                                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                      ),
                                    ],
                                  ),
                                  if (tier.freeAnimes.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 4),
                                      child: Text("No anime assigned yet. Tap '+ Add Anime' to pick.", style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                                    )
                                  else ...[
                                    Builder(
                                      builder: (context) {
                                        final visibleAnimes = tier.isExpanded
                                            ? tier.freeAnimes
                                            : tier.freeAnimes.take(6).toList();

                                        return Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: visibleAnimes.map((anime) {
                                            return Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: CachedNetworkImage(
                                                    imageUrl: anime.image,
                                                    width: 44,
                                                    height: 62,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) => Container(color: Colors.grey[800], width: 44, height: 62),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 2,
                                                  right: 2,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        tier.freeAnimes.removeWhere((a) => a.animeId == anime.animeId);
                                                      });
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withOpacity(0.7),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      padding: const EdgeInsets.all(2),
                                                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),
                                    if (tier.freeAnimes.length > 6)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: () => setState(() => tier.isExpanded = !tier.isExpanded),
                                          icon: Icon(tier.isExpanded ? Icons.expand_less : Icons.expand_more, size: 16),
                                          label: Text(
                                            tier.isExpanded
                                                ? "Show Less"
                                                : "Show More (${tier.freeAnimes.length - 6} more)",
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                        ),
                                      ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      // Full-Width Add Tier Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _addTier,
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text("Add Tier", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: AppColors.accent),
                            foregroundColor: AppColors.accent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Share & Download Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _shareImage,
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text("Share Image", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _downloadImage,
                      icon: const Icon(Icons.download),
                      label: const Text("Download"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Tier List Image Widget (Captured by RepaintBoundary) ──
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: Container(
                      width: 900,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F1A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 2.0),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // App Branding
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => AppColors.brandGradient.createShader(bounds),
                                child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              ShaderMask(
                                shaderCallback: (bounds) => AppColors.brandGradient.createShader(bounds),
                                child: const Text(
                                  'MY ANIMES APPLICATION',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Header Title Block
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _customTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.auto_awesome, color: AppColors.starYellow, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    _sourceMode == 'free'
                                        ? "Manual Selection"
                                        : "Source: ${_sourceMode == 'my_rating' ? 'My Rating' : 'MAL Score'}",
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Horizontal Tier Rows
                          ..._tiers.map((tier) {
                            final tierAnimes = groupedData[tier] ?? [];
                            final tierColor = tier.color;

                            String labelText = tier.title.isNotEmpty ? tier.title : "Tier";
                            if (_sourceMode != 'free') {
                              final bMin = tier.from.toStringAsFixed(1);
                              final bMax = tier.to.toStringAsFixed(1);
                              labelText = tier.title.isNotEmpty
                                  ? "${tier.title}\n($bMin - $bMax)"
                                  : "$bMin - $bMax";
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Row Header Label Block
                                    Container(
                                      width: 140,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: tierColor,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(9),
                                          bottomLeft: Radius.circular(9),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        labelText,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: Colors.black87,
                                          height: 1.2,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    // Row Content Block (Anime Cards)
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        alignment: Alignment.centerLeft,
                                        child: tierAnimes.isEmpty
                                            ? const Text(
                                                "No items in this tier",
                                                style: TextStyle(color: Colors.white24, fontSize: 11, fontStyle: FontStyle.italic),
                                              )
                                            : Wrap(
                                                spacing: 10,
                                                runSpacing: 10,
                                                children: tierAnimes.map((anime) {
                                                  final double score = _sourceMode == 'my_rating'
                                                      ? (anime.userRating?.overall ?? 0.0)
                                                      : (anime.score ?? 0.0);

                                                  return Container(
                                                    width: 55,
                                                    height: 85,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(6),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withOpacity(0.4),
                                                          blurRadius: 4,
                                                          offset: const Offset(0, 2),
                                                        )
                                                      ],
                                                    ),
                                                    child: Stack(
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius: BorderRadius.circular(6),
                                                          child: CachedNetworkImage(
                                                            imageUrl: anime.image,
                                                            width: 55,
                                                            height: 85,
                                                            fit: BoxFit.cover,
                                                            errorWidget: (_, __, ___) => Container(
                                                              color: Colors.grey[900],
                                                              child: const Icon(Icons.broken_image, size: 20, color: Colors.white24),
                                                            ),
                                                          ),
                                                        ),
                                                        if (score > 0.0)
                                                          Positioned(
                                                            top: 4,
                                                            left: 4,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: Colors.black.withOpacity(0.75),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                score.toStringAsFixed(1),
                                                                style: const TextStyle(
                                                                  color: AppColors.starYellow,
                                                                  fontSize: 7,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
