import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/models/anime_list_item.dart';
import '../core/services/hive_service.dart';

class PersonalNotesTagsSheet extends StatefulWidget {
  final AnimeListItem item;
  final VoidCallback onSaved;

  const PersonalNotesTagsSheet({
    super.key,
    required this.item,
    required this.onSaved,
  });

  static Future<void> show(BuildContext context, {required AnimeListItem item, required VoidCallback onSaved}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => PersonalNotesTagsSheet(item: item, onSaved: onSaved),
    );
  }

  @override
  State<PersonalNotesTagsSheet> createState() => _PersonalNotesTagsSheetState();
}

class _PersonalNotesTagsSheetState extends State<PersonalNotesTagsSheet> {
  late final TextEditingController _notesController;
  late final TextEditingController _newTagController;
  final List<String> _tags = [];
  bool _isSaving = false;

  static const List<String> _suggestedTags = [
    'Favorite',
    'Masterpiece',
    'Rewatch',
    'Comfort Show',
    'Recommended',
    'Guilty Pleasure',
    'Droppable',
    'High Hype',
  ];

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.item.personalNotes ?? '');
    _newTagController = TextEditingController();
    if (widget.item.tags != null) {
      _tags.addAll(widget.item.tags!);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final clean = tag.trim();
    if (clean.isEmpty) return;
    if (!_tags.contains(clean)) {
      HapticFeedback.selectionClick();
      setState(() {
        _tags.add(clean);
        _newTagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    await HiveService.updatePersonalNotes(widget.item.animeId, _notesController.text);
    await HiveService.updateTags(widget.item.animeId, _tags);

    widget.onSaved();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Notes & tags saved for ${widget.item.title}'),
            ],
          ),
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Notes & Tags',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Personal Notes Input
              Text(
                'Personal Notes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: TextField(
                  controller: _notesController,
                  maxLines: 4,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add private thoughts, favorite quotes, or watch reminders...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Custom Tags Section
              Text(
                'Custom Tags',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Current tags chips
              if (_tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accent.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.label_rounded, size: 13, color: AppColors.accent),
                          const SizedBox(width: 5),
                          Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _removeTag(tag),
                            child: Icon(Icons.close_rounded, size: 14, color: AppColors.accent),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              else
                Text(
                  'No tags yet. Pick from below or type a custom tag.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                  ),
                ),
              const SizedBox(height: 12),

              // Add Tag Input
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newTagController,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type new tag...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                          ),
                          prefixIcon: Icon(
                            Icons.add_circle_outline,
                            size: 18,
                            color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: _addTag,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_forward_rounded, color: AppColors.accent, size: 18),
                      onPressed: () => _addTag(_newTagController.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Suggested Tags
              Text(
                'Suggestions',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _suggestedTags.map((tag) {
                  final isAlreadyAdded = _tags.contains(tag);
                  return ActionChip(
                    label: Text(tag, style: TextStyle(fontSize: 11, color: isAlreadyAdded ? AppColors.accent : null)),
                    backgroundColor: isAlreadyAdded
                        ? AppColors.accent.withAlpha(25)
                        : (isDark ? AppColors.darkCard : AppColors.lightCard),
                    side: BorderSide(
                      color: isAlreadyAdded
                          ? AppColors.accent.withAlpha(80)
                          : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      if (isAlreadyAdded) {
                        _removeTag(tag);
                      } else {
                        _addTag(tag);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
