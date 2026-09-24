import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/services/hive_service.dart';
import '../core/models/anime_list_item.dart';

class ShareLayeredListPage extends StatefulWidget {
  const ShareLayeredListPage({super.key});

  @override
  State<ShareLayeredListPage> createState() => _ShareLayeredListPageState();
}

class _ShareLayeredListPageState extends State<ShareLayeredListPage> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isProcessing = false;

  // Configuration values
  String _ratingType = 'my_rating'; // 'my_rating' or 'overall_score'
  double _minRating = 6.0;
  double _maxRating = 10.0;
  String _customTitle = "My Anime Tier Spectrum";

  // Dynamic Layers (Default 5)
  int _layerCount = 5;
  late List<TextEditingController> _subnameControllers;
  List<double> _customBoundaries = [];

  // Filters & Sort
  Set<String> _selectedGenres = {};
  String _filterStudio = '';
  String _filterCategory = 'all'; // 'all', 'watching', 'completed', 'planned', 'ignored'
  String _sortBy = 'rating'; // 'rating', 'title'

  late List<AnimeListItem> _allItems;

  @override
  void initState() {
    super.initState();
    _allItems = HiveService.getAllListItems();
    HiveService.healListItemsMetadata();
    _initControllers(_layerCount);
    _recalculateBoundaries();
  }

  void _initControllers(int count) {
    _subnameControllers = List.generate(count, (_) => TextEditingController());
  }

  void _recalculateBoundaries() {
    final double step = (_maxRating - _minRating) / _layerCount;
    _customBoundaries = List.generate(
      _layerCount + 1,
      (i) => double.parse((_minRating + i * step).toStringAsFixed(1)),
    );
    // Pin boundaries
    _customBoundaries[0] = _minRating;
    _customBoundaries[_layerCount] = _maxRating;
  }

  @override
  void dispose() {
    for (var controller in _subnameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addLayer() {
    setState(() {
      _layerCount++;
      _subnameControllers.add(TextEditingController());
      _recalculateBoundaries();
    });
  }

  void _removeLayer() {
    if (_layerCount > 1) {
      setState(() {
        _layerCount--;
        final removed = _subnameControllers.removeLast();
        removed.dispose();
        _recalculateBoundaries();
      });
    }
  }

  // Get distinct colors for layers
  Color _getLayerColor(int index) {
    final colors = [
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFFFF9800), // Orange
      const Color(0xFFF44336), // Red
      const Color(0xFFE91E63), // Pink
      const Color(0xFF00BCD4), // Cyan
    ];
    return colors[index % colors.length];
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
    // Fetch studios primarily from completed items
    final completedItems = _allItems.where((i) => i.category == AnimeCategory.completed);
    for (final item in completedItems) {
      if (item.studios != null) {
        studios.addAll(item.studios!.where((s) => s.trim().isNotEmpty));
      }
    }
    // Fallback to all items if completed studios are empty
    if (studios.isEmpty) {
      for (final item in _allItems) {
        if (item.studios != null) {
          studios.addAll(item.studios!.where((s) => s.trim().isNotEmpty));
        }
      }
    }
    return studios;
  }

  // Group filtered anime items into their respective layers using custom ranges
  Map<int, List<AnimeListItem>> _groupAnimeIntoLayers() {
    final Map<int, List<AnimeListItem>> grouped = {
      for (int i = 0; i < _layerCount; i++) i: []
    };

    for (final item in _allItems) {
      // Apply filters
      if (_selectedGenres.isNotEmpty && !_selectedGenres.any((g) => item.genres.contains(g))) continue;
      if (_filterStudio.isNotEmpty && (item.studios == null || !item.studios!.contains(_filterStudio))) continue;
      if (_filterCategory != 'all') {
        if (_filterCategory == 'watching' && item.category != AnimeCategory.watching) continue;
        if (_filterCategory == 'completed' && item.category != AnimeCategory.completed) continue;
        if (_filterCategory == 'planned' && item.category != AnimeCategory.planned) continue;
        if (_filterCategory == 'ignored' && item.category != AnimeCategory.ignored) continue;
      }

      double rating = 0.0;
      if (_ratingType == 'my_rating') {
        rating = item.userRating?.overall ?? 0.0;
      } else {
        rating = item.score ?? 0.0;
      }

      if (rating < _minRating || rating > 10.0) continue;

      int targetLayer = _layerCount - 1;
      for (int i = 0; i < _layerCount; i++) {
        final bMin = _customBoundaries[i];
        final bMax = _customBoundaries[i + 1];
        if (rating >= bMin && rating <= bMax) {
          targetLayer = i;
          break;
        }
      }
      grouped[targetLayer]?.add(item);
    }

    // Sort items within each layer
    for (int key in grouped.keys) {
      grouped[key]!.sort((a, b) {
        if (_sortBy == 'title') {
          return a.title.compareTo(b.title);
        } else {
          double rA = _ratingType == 'my_rating' ? (a.userRating?.overall ?? 0.0) : (a.score ?? 0.0);
          double rB = _ratingType == 'my_rating' ? (b.userRating?.overall ?? 0.0) : (b.score ?? 0.0);
          return rB.compareTo(rA);
        }
      });
    }

    return grouped;
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
        if (outputFile == null) return; // Cancelled
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

    final allGenres = _getAllGenres().toList()..sort();
    final completedStudios = _getCompletedStudios().toList()..sort();

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
                      // Header Row using Wrap to prevent 48px right overflow!
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const Text("Configure Spectrum & Filters", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: _removeLayer,
                                icon: const Icon(Icons.remove_circle_outline, size: 15, color: Colors.red),
                                label: const Text("Remove Tier", style: TextStyle(fontSize: 11, color: Colors.red)),
                              ),
                              TextButton.icon(
                                onPressed: _addLayer,
                                icon: Icon(Icons.add_circle_outline, size: 15, color: AppColors.accent),
                                label: Text("Add Tier", style: TextStyle(fontSize: 11, color: AppColors.accent)),
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Rating Source Dropdown & Header Title
                      Row(
                        children: [
                          const Text("Rating Source: ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _ratingType,
                              onChanged: (val) {
                                if (val != null) setState(() => _ratingType = val);
                              },
                              items: const [
                                DropdownMenuItem(value: 'my_rating', child: Text("My Rating")),
                                DropdownMenuItem(value: 'overall_score', child: Text("MAL Score")),
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

                      // Overall Spectrum Bounds
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Spectrum Min: ${_minRating.toStringAsFixed(1)}", style: const TextStyle(fontSize: 12)),
                                Slider(
                                  value: _minRating,
                                  min: 1.0,
                                  max: 9.0,
                                  divisions: 80,
                                  activeColor: AppColors.accent,
                                  onChanged: (val) {
                                    setState(() {
                                      _minRating = val;
                                      if (_maxRating <= _minRating) {
                                        _maxRating = (_minRating + 1.0).clamp(1.0, 10.0);
                                      }
                                      _recalculateBoundaries();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Spectrum Max: ${_maxRating.toStringAsFixed(1)}", style: const TextStyle(fontSize: 12)),
                                Slider(
                                  value: _maxRating,
                                  min: 2.0,
                                  max: 10.0,
                                  divisions: 80,
                                  activeColor: AppColors.accent,
                                  onChanged: (val) {
                                    setState(() {
                                      _maxRating = val;
                                      if (_minRating >= _maxRating) {
                                        _minRating = (_maxRating - 1.0).clamp(1.0, 10.0);
                                      }
                                      _recalculateBoundaries();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Anime Filters Section
                      const Text("Filter Anime Items", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Multi-Select Genres Button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showMultiGenrePicker(allGenres),
                              icon: const Icon(Icons.category_outlined, size: 16),
                              label: Text(
                                _selectedGenres.isEmpty
                                    ? 'Genres (All)'
                                    : 'Genres (${_selectedGenres.length})',
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Category Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Category', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                              value: _filterCategory,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All Lists')),
                                DropdownMenuItem(value: 'watching', child: Text('Watching')),
                                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                                DropdownMenuItem(value: 'planned', child: Text('Planned')),
                                DropdownMenuItem(value: 'ignored', child: Text('Ignored')),
                              ],
                              onChanged: (v) => setState(() => _filterCategory = v ?? 'all'),
                            ),
                          ),
                        ],
                      ),
                      if (completedStudios.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Studio (Completed List)', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                          value: _filterStudio,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: '', child: Text('All Studios')),
                            ...completedStudios.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                          ],
                          onChanged: (v) => setState(() => _filterStudio = v ?? ''),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Layer Titles & Custom Rate Range Customization
                      Text("Layer Titles & Rating Ranges ($_layerCount Layers)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _layerCount,
                        itemBuilder: (context, index) {
                          // Top to bottom (highest tier is top index = _layerCount - 1)
                          final tierIndex = _layerCount - 1 - index;
                          
                          // Pinned limits
                          final isTopTier = tierIndex == _layerCount - 1;
                          final isBottomTier = tierIndex == 0;

                          // Upper bound fixed to maxRating for top tier, lower bound fixed to minRating for bottom tier
                          final double lower = _customBoundaries[tierIndex];
                          final double upper = _customBoundaries[tierIndex + 1];

                          final bMin = lower.toStringAsFixed(1);
                          final bMax = upper.toStringAsFixed(1);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 12, height: 12,
                                        decoration: BoxDecoration(color: _getLayerColor(tierIndex), shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          isTopTier
                                              ? "Tier ${tierIndex + 1} (Top Tier - Max Fixed: $bMax)"
                                              : isBottomTier
                                                  ? "Tier ${tierIndex + 1} (Bottom Tier - Min Fixed: $bMin)"
                                                  : "Tier ${tierIndex + 1} Range: $bMin - $bMax",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _getLayerColor(tierIndex)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _subnameControllers[tierIndex],
                                    decoration: InputDecoration(
                                      labelText: "Tier Title ($bMin - $bMax)",
                                      hintText: "Custom title (optional)",
                                      labelStyle: const TextStyle(fontSize: 11),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: const OutlineInputBorder(),
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  // Individual Range Adjustment Slider for intermediate boundary
                                  if (!isBottomTier) ...[
                                    const SizedBox(height: 6),
                                    Builder(
                                      builder: (context) {
                                        final double sliderMin = _minRating;
                                        final double sliderMax = upper > sliderMin + 0.1 ? upper - 0.1 : sliderMin + 0.2;
                                        final double sliderVal = lower.clamp(sliderMin, sliderMax);

                                        return Row(
                                          children: [
                                            Text("Min Rating Cutoff: ${sliderVal.toStringAsFixed(1)}", style: const TextStyle(fontSize: 11)),
                                            Expanded(
                                              child: Slider(
                                                value: sliderVal,
                                                min: sliderMin,
                                                max: sliderMax,
                                                divisions: ((sliderMax - sliderMin) * 10).round().clamp(1, 100),
                                                activeColor: _getLayerColor(tierIndex),
                                                onChanged: (val) {
                                                  setState(() {
                                                    _customBoundaries[tierIndex] = double.parse(val.toStringAsFixed(1));
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
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
            // Highest Tier is at TOP, Lowest Tier is at BOTTOM
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
                                  'MY ANIMES',
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
                                    "Spectrum: ${_minRating.toStringAsFixed(1)} - ${_maxRating.toStringAsFixed(1)}",
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Horizontal Tier Rows: REVERSED ORDER (Highest Tier at TOP, Lowest Tier at BOTTOM)
                          ...List.generate(_layerCount, (index) {
                            final tierIndex = _layerCount - 1 - index; // Reverse index!
                            final double lower = _customBoundaries[tierIndex];
                            final double upper = _customBoundaries[tierIndex + 1];

                            final bMin = lower.toStringAsFixed(1);
                            final bMax = upper.toStringAsFixed(1);
                            final customName = _subnameControllers[tierIndex].text.trim();

                            final labelText = customName.isNotEmpty
                                ? "$customName\n($bMin - $bMax)"
                                : "$bMin - $bMax";

                            final tierAnimes = groupedData[tierIndex] ?? [];
                            final tierColor = _getLayerColor(tierIndex);

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
                                                  final double score = _ratingType == 'my_rating'
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
