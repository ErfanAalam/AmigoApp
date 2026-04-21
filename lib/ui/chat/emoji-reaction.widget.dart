import 'dart:ui';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../db/repositories/user.repo.dart';

/// A horizontal pill bar with common quick-reaction emojis + a "+" button.
/// Shown as an overlay above the long-pressed message bubble.
class EmojiReactionPicker extends StatefulWidget {
  /// Called when the user picks an emoji (either quick or from the full picker).
  final void Function(String emoji) onEmojiSelected;

  /// Optional list of emojis the current user has already reacted with
  /// (used to show "already selected" state on the quick pills).
  final List<String> myReactions;

  const EmojiReactionPicker({
    super.key,
    required this.onEmojiSelected,
    this.myReactions = const [],
  });

  @override
  State<EmojiReactionPicker> createState() => _EmojiReactionPickerState();
}

class _EmojiReactionPickerState extends State<EmojiReactionPicker>
    with SingleTickerProviderStateMixin {
  static const List<String> _quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  bool _showFullPicker = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _pickEmoji(String emoji) {
    HapticFeedback.lightImpact();
    widget.onEmojiSelected(emoji);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick-emoji pill bar
        FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._quickEmojis.map((emoji) {
                    final isSelected = widget.myReactions.contains(emoji);
                    return _QuickEmojiButton(
                      emoji: emoji,
                      isSelected: isSelected,
                      onTap: () => _pickEmoji(emoji),
                    );
                  }),
                  const SizedBox(width: 4),
                  // "+" button to open full picker
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showFullPicker = !_showFullPicker),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _showFullPicker
                            ? Colors.grey[200]
                            : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _showFullPicker ? Icons.close : Icons.add,
                        size: 18,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Full emoji picker (expanded below the pill bar)
        if (_showFullPicker) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _pickEmoji(emoji.emoji);
                },
                config: Config(
                  emojiViewConfig: EmojiViewConfig(
                    columns: 8,
                    emojiSizeMax: 28,
                    backgroundColor: Colors.white,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: Colors.white,
                    buttonIconColor: Colors.grey[600]!,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: Colors.white,
                    iconColor: Colors.grey[400]!,
                    iconColorSelected: Theme.of(context).primaryColor,
                    indicatorColor: Theme.of(context).primaryColor,
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    enabled: false,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickEmojiButton extends StatefulWidget {
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickEmojiButton({
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_QuickEmojiButton> createState() => _QuickEmojiButtonState();
}

class _QuickEmojiButtonState extends State<_QuickEmojiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.8,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _bounce;
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _bounce.reverse();
    await _bounce.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.blue.withOpacity(0.15)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(widget.emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

/// Displays the reaction summary bubble attached to the bottom of a message.
///
/// - 0 reactors → invisible
/// - 1 total reactor OR only 1 unique emoji → small single pill
/// - 2+ reactors AND 2+ unique emojis → compact stacked-emoji bubble
///
/// A single tap always opens [AllReactorsSheet] listing every reactor.
class MessageReactionRow extends StatelessWidget {
  /// reactions map: { emoji: [{user_id, user_name, reacted_at}] }
  final Map<String, dynamic> reactions;
  final VoidCallback onTap;

  const MessageReactionRow({
    super.key,
    required this.reactions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Flatten total count and sort emojis by count descending.
    final sorted = reactions.entries.toList()
      ..sort(
        (a, b) => (b.value as List).length.compareTo((a.value as List).length),
      );

    final totalCount = sorted.fold<int>(
      0,
      (sum, e) => sum + (e.value as List).length,
    );
    if (totalCount == 0) return const SizedBox.shrink();

    final emoji1 = sorted[0].key;
    final emoji2 = sorted.length >= 2 ? sorted[1].key : null;

    // Show stacked bubble only when there are 2+ unique emojis
    if (emoji2 != null) {
      return _CompactReactionBubble(
        emoji1: emoji1,
        emoji2: emoji2,
        totalCount: totalCount,
        onTap: onTap,
      );
    }

    return _SingleReactionBubble(
      emoji: emoji1,
      count: totalCount,
      onTap: onTap,
    );
  }
}

/// Small pill for a single emoji type (any count).
class _SingleReactionBubble extends StatelessWidget {
  final String emoji;
  final int count;
  final VoidCallback onTap;

  const _SingleReactionBubble({
    required this.emoji,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            if (count > 1) ...[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact bubble: emoji1 stacked on top of emoji2 (half-covered) + total count.
class _CompactReactionBubble extends StatelessWidget {
  final String emoji1; // front / on top
  final String emoji2; // behind / half-covered
  final int totalCount;
  final VoidCallback onTap;

  const _CompactReactionBubble({
    required this.emoji1,
    required this.emoji2,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double circleSize = 22.0;
    const double overlap = circleSize * 0.5;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width:
                  circleSize + overlap, // emoji1 full + half of emoji2 visible
              height: circleSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // emoji2: shifted right, left half covered by emoji1
                  Positioned(
                    left: overlap,
                    child: _EmojiCircle(emoji: emoji2, size: circleSize),
                  ),
                  // emoji1: left side, on top
                  Positioned(
                    left: 0,
                    child: _EmojiCircle(emoji: emoji1, size: circleSize),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$totalCount',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiCircle extends StatelessWidget {
  final String emoji;
  final double size;

  const _EmojiCircle({required this.emoji, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: size * 0.65)),
    );
  }
}

/// Bottom sheet listing every person who reacted and their emoji.
class AllReactorsSheet extends StatefulWidget {
  /// reactions map: { emoji: [{user_id, user_name, reacted_at}] }
  final Map<String, dynamic> reactions;

  const AllReactorsSheet({super.key, required this.reactions});

  @override
  State<AllReactorsSheet> createState() => _AllReactorsSheetState();
}

class _AllReactorsSheetState extends State<AllReactorsSheet> {
  final _userRepo = UserRepository();
  late Future<List<({String emoji, String name})>> _rowsFuture;

  @override
  void initState() {
    super.initState();
    _rowsFuture = _buildRows();
  }

  Future<List<({String emoji, String name})>> _buildRows() async {
    final rows = <({String emoji, String name})>[];
    for (final entry in widget.reactions.entries) {
      for (final user in (entry.value as List)) {
        final map = user as Map;
        final rawName = map['user_name']?.toString() ?? '';
        String name;
        if (rawName.isNotEmpty) {
          name = rawName;
        } else {
          final userId = map['user_id'];
          if (userId != null) {
            final dbUser = await _userRepo.getUserById(userId.toString());
            name = dbUser?.name ?? 'Unknown User';
          } else {
            name = 'Unknown User';
          }
        }
        rows.add((emoji: entry.key, name: name));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<({String emoji, String name})>>(
      future: _rowsFuture,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        final totalCount = rows.length;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(210),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '$totalCount ${totalCount == 1 ? 'reaction' : 'reactions'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[100],
                            child: Text(
                              row.name.isNotEmpty
                                  ? row.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(row.name),
                          trailing: Text(
                            row.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shows the emoji reaction picker as a blurred overlay anchored to the message.
/// Returns the selected emoji string, or null if dismissed.
Future<String?> showEmojiReactionPicker({
  required BuildContext context,
  required List<String> myReactions,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    builder: (ctx) => _EmojiPickerDialog(myReactions: myReactions),
  );
}

class _EmojiPickerDialog extends StatelessWidget {
  final List<String> myReactions;
  const _EmojiPickerDialog({required this.myReactions});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
        ),
        child: EmojiReactionPicker(
          myReactions: myReactions,
          onEmojiSelected: (emoji) => Navigator.of(context).pop(emoji),
        ),
      ),
    );
  }
}
