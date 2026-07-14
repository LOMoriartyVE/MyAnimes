import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
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
  double _minRating = 7.0;
  double _maxRating = 9.0;
  String _customTitle = "My Rated Anime Spectrum";

  // Subnames for the 6 layers
  final List<TextEditingController> _subnameControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  late List<AnimeListItem> _allItems;

  @override
  void initState() {
    super.initState();
    _allItems = HiveService.getAllListItems();
    // Default subnames
    _subnameControllers[0].text = "Great";
    _subnameControllers[1].text = "Excellent";
    _subnameControllers[2].text = "Amazing";
    _subnameControllers[3].text = "Superb";
    _subnameControllers[4].text = "Masterpiece";
    _subnameControllers[5].text = "God Tier";
  }

  @override
  void dispose() {
    for (var controller in _subnameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Calculate layers dynamically
  List<double> _calculateLayerBoundaries() {
    final double step = (_maxRating - _minRating) / 5;
    return List.generate(6, (i) => double.parse((_minRating + i * step).toStringAsFixed(2)));
  }

  // Get color for each layer
  Color _getLayerColor(int index) {
    final colors = [
      const Color(0xFFF44336), // Red
      const Color(0xFFFF9800), // Orange
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFF4CAF50), // Green
      const Color(0xFF2196F3), // Blue
      const Color(0xFF9C27B0), // Purple
    ];
    return colors[index % colors.length];
  }

  // Group anime items into their respective layers
  Map<int, List<AnimeListItem>> _groupAnimeIntoLayers(List<double> boundaries) {
    final Map<int, List<AnimeListItem>> grouped = {
      0: [], 1: [], 2: [], 3: [], 4: [], 5: []
    };

    for (final item in _allItems) {
      double rating = 0.0;
      if (_ratingType == 'my_rating') {
        rating = item.userRating?.overall ?? 0.0;
      } else {
        rating = item.score ?? 0.0;
      }

      if (rating < _minRating || rating > 10.0) continue;

      // Decide which layer the item belongs to
      int targetLayer = 5;
      for (int i = 0; i < 5; i++) {
        if (rating >= boundaries[i] && rating < boundaries[i + 1]) {
          targetLayer = i;
          break;
        }
      }
      if (rating >= boundaries[5]) {
        targetLayer = 5;
      }

      grouped[targetLayer]!.add(item);
    }

    // Sort each layer's anime list from low to high by rating
    for (int key in grouped.keys) {
      grouped[key]!.sort((a, b) {
        double rA = _ratingType == 'my_rating' ? (a.userRating?.overall ?? 0.0) : (a.score ?? 0.0);
        double rB = _ratingType == 'my_rating' ? (b.userRating?.overall ?? 0.0) : (b.score ?? 0.0);
        return rA.compareTo(rB);
      });
    }

    return grouped;
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
        text: 'My Layered Anime Rating Spectrum!',
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
            SnackBar(
              content: const Text("Image saved to gallery successfully!"),
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
    final boundaries = _calculateLayerBoundaries();
    final groupedData = _groupAnimeIntoLayers(boundaries);

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
            // Settings Panel
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
                      const Text("Configure Spectrum", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 16),
                      // Rating Source Dropdown
                      Row(
                        children: [
                          const Text("Rating Source: ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButton<String>(
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
                      // Title Text Input
                      TextField(
                        decoration: const InputDecoration(
                          labelText: "Image Header Title",
                          labelStyle: TextStyle(fontSize: 12),
                        ),
                        onChanged: (val) => setState(() => _customTitle = val),
                        controller: TextEditingController(text: _customTitle)..selection = TextSelection.collapsed(offset: _customTitle.length),
                      ),
                      const SizedBox(height: 16),
                      // Min/Max Rating Slider
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Min Rating: ${_minRating.toStringAsFixed(1)}", style: const TextStyle(fontSize: 12)),
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
                                Text("Max Rating: ${_maxRating.toStringAsFixed(1)}", style: const TextStyle(fontSize: 12)),
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
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("Layer Subnames", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      // 6 Layer Custom Subname Fields
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          return TextField(
                            controller: _subnameControllers[index],
                            decoration: InputDecoration(
                              labelText: "Tier ${boundaries[index].toStringAsFixed(1)}",
                              labelStyle: TextStyle(fontSize: 10, color: _getLayerColor(index)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: const OutlineInputBorder(),
                            ),
                            style: const TextStyle(fontSize: 12),
                            onChanged: (val) => setState(() {}),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Preview & Actions Panel
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
            // The Target Widget to capture as RepaintBoundary (Fixed Width Container for Horizontal Tier-list layout)
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
                          // Brand Watermark Logo Header
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
                          // Header title block
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
                          // The 6 Horizontal Tier Rows
                          ...List.generate(6, (index) {
                            final tierRating = boundaries[index];
                            final tierSubname = _subnameControllers[index].text.trim();
                            final labelText = tierSubname.isNotEmpty
                                ? "${tierRating.toStringAsFixed(1)}\n($tierSubname)"
                                : tierRating.toStringAsFixed(1);
                            final tierAnimes = groupedData[index] ?? [];
                            final tierColor = _getLayerColor(index);

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
                                    // Row label block
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
                                    // Row contents block
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
