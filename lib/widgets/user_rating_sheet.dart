import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_list_item.dart';
import '../core/localization/app_text.dart';

/// Bottom sheet dialog for user ratings with two-way sync:
///   - Changing Overall → distributes value to ALL sub-ratings.
///   - Changing any sub-rating → recalculates Overall automatically.
///   - Animation is split into Drawing (art style) and Animation (motion quality).
class UserRatingSheet extends StatefulWidget {
  final UserRating? existingRating;

  const UserRatingSheet({super.key, this.existingRating});

  static Future<UserRating?> show(BuildContext context, {UserRating? existing}) {
    return showModalBottomSheet<UserRating>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UserRatingSheet(existingRating: existing),
    );
  }

  @override
  State<UserRatingSheet> createState() => _UserRatingSheetState();
}

class _UserRatingSheetState extends State<UserRatingSheet> {
  late double _overall;
  late double _story;
  late double _character;
  late double _dialogues;
  late double _mainIdea;
  late double _draw;
  late double _animation;
  late double _music;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final r = widget.existingRating;
    _overall = r?.overall ?? 0;
    _story = r?.story ?? 0;
    _character = r?.character ?? 0;
    _dialogues = r?.dialogues ?? 0;
    _mainIdea = r?.mainIdea ?? 0;
    _draw = r?.draw ?? 0;
    _animation = r?.animation ?? 0;
    _music = r?.music ?? 0;
    _notesController = TextEditingController(text: r?.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ── Sync Logic ──

  /// Called when user changes the Overall slider or text.
  void _onOverallChanged(double value) {
    HapticFeedback.selectionClick();
    setState(() {
      _overall = value;
    });
  }

  void _calculateOverallFromSubs() {
    // Only rates greater than 0 are included in the overall average calculation
    final subs = [
      _story,
      _character,
      _dialogues,
      _mainIdea,
      _draw,
      _animation,
      _music,
    ].where((v) => v > 0).toList();

    if (subs.isNotEmpty) {
      final avg = subs.reduce((a, b) => a + b) / subs.length;
      _overall = ((avg * 10).roundToDouble()) / 10;
    } else {
      _overall = 0.0;
    }
  }

  /// Called when any sub-rating slider changes.
  void _onSubChanged(String field, double value) {
    HapticFeedback.selectionClick();
    setState(() {
      switch (field) {
        case 'story':     _story = value; break;
        case 'character': _character = value; break;
        case 'dialogues': _dialogues = value; break;
        case 'mainIdea':  _mainIdea = value; break;
        case 'draw':      _draw = value; break;
        case 'animation': _animation = value; break;
        case 'music':     _music = value; break;
      }
      _calculateOverallFromSubs();
    });
  }

  void _recalculateOverall() {
    setState(() {
      _calculateOverallFromSubs();
    });
  }

  void _applyOverallToAll() {
    setState(() {
      _story = _overall;
      _character = _overall;
      _dialogues = _overall;
      _mainIdea = _overall;
      _draw = _overall;
      _animation = _overall;
      _music = _overall;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  AppText.get('your_rating'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _recalculateOverall,
                    icon: const Icon(Icons.calculate_outlined, size: 14),
                    label: Text(
                      AppText.isArabic ? 'حساب الكلي من الفرعي' : 'Average from details',
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _applyOverallToAll,
                    icon: const Icon(Icons.copy_all_rounded, size: 14),
                    label: Text(
                      AppText.isArabic ? 'تطبيق الكلي للكل' : 'Copy overall to all',
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Overall (leads all others when changed) ──
              _buildRatingRow(
                label: AppText.get('overall_rating'),
                value: _overall,
                color: AppColors.accent,
                isOverall: true,
                onChanged: _onOverallChanged,
              ),

              Divider(color: (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder).withAlpha(80)),
              const SizedBox(height: 8),

              // ── Sub-ratings ──
              _buildRatingRow(
                label: AppText.get('story_rating'),
                value: _story,
                color: AppColors.lavender,
                onChanged: (v) => _onSubChanged('story', v),
              ),
              _buildRatingRow(
                label: AppText.get('character_rating'),
                value: _character,
                color: AppColors.mauve,
                onChanged: (v) => _onSubChanged('character', v),
              ),
              _buildRatingRow(
                label: AppText.get('dialogues_rating'),
                value: _dialogues,
                color: const Color(0xFF38BDF8),   // sky blue
                onChanged: (v) => _onSubChanged('dialogues', v),
              ),
              _buildRatingRow(
                label: AppText.get('main_idea_rating'),
                value: _mainIdea,
                color: const Color(0xFFFB923C),   // warm coral/amber
                onChanged: (v) => _onSubChanged('mainIdea', v),
              ),
              _buildRatingRow(
                label: AppText.get('draw_rating'),
                value: _draw,
                color: const Color(0xFF60C8A0),   // teal-green for art/drawing
                onChanged: (v) => _onSubChanged('draw', v),
              ),
              _buildRatingRow(
                label: AppText.get('animation_rating'),
                value: _animation,
                color: AppColors.watching,
                onChanged: (v) => _onSubChanged('animation', v),
              ),
              _buildRatingRow(
                label: AppText.get('music_rating'),
                value: _music,
                color: AppColors.starYellow,
                onChanged: (v) => _onSubChanged('music', v),
              ),

              const SizedBox(height: 16),

              // Notes
              Text(AppText.get('notes'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: AppText.get('notes_hint'),
                  hintStyle: TextStyle(color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                ),
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(AppText.get('cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(UserRating(
                          overall: _overall,
                          story: _story,
                          character: _character,
                          dialogues: _dialogues,
                          mainIdea: _mainIdea,
                          draw: _draw,
                          animation: _animation,
                          music: _music,
                          notes: _notesController.text,
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(AppText.get('save'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showNumberInputDialog(String label, double currentValue, ValueChanged<double> onChanged) {
    final controller = TextEditingController(
      text: currentValue > 0 ? currentValue.toStringAsFixed(1) : '',
    );
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '${AppText.isArabic ? "أدخل تقييم" : "Enter Rating"} - $label',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              hintText: '0.0 - 10.0',
              hintStyle: TextStyle(color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
            style: TextStyle(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppText.get('cancel'),
                style: TextStyle(color: AppColors.accent),
              ),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  onChanged(0.0);
                } else {
                  final val = double.tryParse(text);
                  if (val != null && val >= 0 && val <= 10) {
                    final rounded = ((val * 10).roundToDouble()) / 10;
                    onChanged(rounded);
                  }
                }
                Navigator.pop(context);
              },
              child: Text(
                AppText.get('save'),
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRatingRow({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
    bool isOverall = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isOverall ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isOverall)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.auto_awesome, size: 14, color: color),
                    ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: isOverall ? 15 : 13,
                      fontWeight: isOverall ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showNumberInputDialog(label, value, onChanged),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withAlpha(60), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value > 0 ? value.toStringAsFixed(1) : '-',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: isOverall ? 18 : 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_outlined,
                        size: isOverall ? 14 : 12,
                        color: color.withAlpha(180),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withAlpha(40),
              thumbColor: color,
              overlayColor: color.withAlpha(30),
              trackHeight: isOverall ? 6 : 4,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: isOverall ? 10 : 8),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 10,
              divisions: 100,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
