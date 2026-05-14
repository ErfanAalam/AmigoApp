import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/types/socket.types.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../models/community.model.dart';
import '../../models/group.model.dart';
import '../../providers/theme-color.provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MessageInputContainer extends ConsumerStatefulWidget {
  final TextEditingController messageController;
  final ValueNotifier<bool> isOtherTypingNotifier;
  final Widget? typingIndicator;
  final bool isReplying;
  final bool isSending;
  final MessageModel? replyToMessageData;
  final String? currentUserId;
  final Function(MessageType)? onSendMessage;
  final VoidCallback? onSendVoiceNote;
  final VoidCallback? onPickGallery;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickDocument;
  final VoidCallback? onPickContact;
  final ValueChanged<String>? onTyping;
  final VoidCallback? onCancelReply;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;

  // For community group restrictions
  final bool isCommunityGroup;
  final CommunityGroupMetadata? communityGroupMetadata;

  // For DM - to determine if replied message is mine
  final DmModel? dm;
  final GroupModel? group;

  // Message recommendations widget (shown between typing indicator and message input)
  final Widget? recommendations;

  const MessageInputContainer({
    super.key,
    required this.messageController,
    required this.isOtherTypingNotifier,
    this.typingIndicator,
    required this.isReplying,
    required this.isSending,
    this.replyToMessageData,
    this.currentUserId,
    this.onSendMessage,
    this.onSendVoiceNote,
    this.onPickGallery,
    this.onPickCamera,
    this.onPickDocument,
    this.onPickContact,
    this.onTyping,
    this.onCancelReply,
    this.focusNode,
    this.onFocusChange,
    this.isCommunityGroup = false,
    this.communityGroupMetadata,
    this.dm,
    this.group,
    this.recommendations,
  });

  @override
  ConsumerState<MessageInputContainer> createState() =>
      _MessageInputContainerState();
}

class _MessageInputContainerState extends ConsumerState<MessageInputContainer>
    with TickerProviderStateMixin {
  late final AnimationController _replyAnim;
  late final Animation<double> _replyAnimation;

  late final AnimationController _attachAnim;
  late final Animation<double> _attachAnimation;
  bool _attachmentMenuVisible = false;

  bool _showEmojiPanel = false;

  // Keeps the last reply data alive so the exit animation has content to show.
  MessageModel? _lastReplyData;

  @override
  void initState() {
    super.initState();
    _replyAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _replyAnimation = CurvedAnimation(
      parent: _replyAnim,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _attachAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _attachAnimation = CurvedAnimation(
      parent: _attachAnim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    if (widget.isReplying && widget.replyToMessageData != null) {
      _lastReplyData = widget.replyToMessageData;
      _replyAnim.value = 1.0;
    }
  }

  void _toggleAttachmentMenu() {
    if (_attachmentMenuVisible) {
      _closeAttachmentMenu();
    } else {
      _openAttachmentMenu();
    }
  }

  void _openAttachmentMenu() {
    // If the emoji panel is visible, close it so they don't stack.
    if (_showEmojiPanel) {
      setState(() => _showEmojiPanel = false);
    }
    setState(() => _attachmentMenuVisible = true);
    _attachAnim.forward();
  }

  void _toggleEmojiPanel() {
    if (_showEmojiPanel) {
      // Currently showing emoji → switch back to the system keyboard
      setState(() => _showEmojiPanel = false);
      widget.focusNode?.requestFocus();
    } else {
      // Currently showing keyboard (or nothing) → swap to emoji
      // The keyboard is what we DO want to dismiss here — it's the whole
      // point of "switch to emoji mode". This is intentional and only
      // happens for the emoji button, not the attachment button.
      widget.focusNode?.unfocus();
      // Close attachment menu if open so the bottom area stays uncluttered.
      if (_attachmentMenuVisible) {
        _closeAttachmentMenu();
      }
      setState(() => _showEmojiPanel = true);
    }
  }

  void _insertEmoji(String emoji) {
    final controller = widget.messageController;
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    final newText = text.replaceRange(start, end, emoji);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    if (widget.onTyping != null) widget.onTyping!(newText);
  }

  void _emojiBackspace() {
    final controller = widget.messageController;
    final text = controller.text;
    final sel = controller.selection;
    if (text.isEmpty) return;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    if (start == end && start == 0) return;
    final removeStart = start == end ? start - 1 : start;
    final newText = text.replaceRange(removeStart, end, '');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: removeStart),
    );
    if (widget.onTyping != null) widget.onTyping!(newText);
  }

  void _closeAttachmentMenu() {
    _attachAnim.reverse().whenComplete(() {
      if (mounted) setState(() => _attachmentMenuVisible = false);
    });
  }

  void _onAttachmentOption(VoidCallback? callback) {
    _closeAttachmentMenu();
    if (callback == null) return;
    // Defer the action until the close animation has had a moment to play.
    Future.delayed(const Duration(milliseconds: 80), callback);
  }

  @override
  void didUpdateWidget(MessageInputContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasShowing =
        oldWidget.isReplying && oldWidget.replyToMessageData != null;
    final isShowing = widget.isReplying && widget.replyToMessageData != null;

    if (!wasShowing && isShowing) {
      // Opened — update data then animate in
      _lastReplyData = widget.replyToMessageData;
      _replyAnim.forward();
    } else if (wasShowing && !isShowing) {
      // Closed — animate out; keep _lastReplyData until animation finishes
      _replyAnim.reverse().whenComplete(() {
        if (mounted) setState(() => _lastReplyData = null);
      });
    } else if (isShowing &&
        widget.replyToMessageData != oldWidget.replyToMessageData) {
      // Changed reply target — swap content, no animation change needed
      setState(() => _lastReplyData = widget.replyToMessageData);
    }
  }

  @override
  void dispose() {
    _replyAnim.dispose();
    _attachAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final isCommunityGroupActive = _isCommunityGroupActive();
    final shouldDisableSending =
        widget.isCommunityGroup && !isCommunityGroupActive;

    return Column(
      children: [
        // Time restriction notice for community groups
        if (widget.isCommunityGroup && !isCommunityGroupActive)
          _buildTimeRestrictionNotice(),

        // Typing indicator
        ValueListenableBuilder<bool>(
          valueListenable: widget.isOtherTypingNotifier,
          builder: (context, isOtherTyping, child) {
            if (isOtherTyping && widget.typingIndicator != null) {
              return widget.typingIndicator!;
            }
            return const SizedBox.shrink();
          },
        ),

        // Message Recommendations
        if (widget.recommendations != null) widget.recommendations!,

        // Reply container — always in the tree (no conditional) so the TextField
        // never shifts position and keyboard focus is preserved.
        // Slides in from bottom on open, slides back down on close.
        AnimatedBuilder(
          animation: _replyAnimation,
          builder: (context, child) {
            final v = _replyAnimation.value;
            if (v == 0.0) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                heightFactor: v,
                child: FractionalTranslation(
                  translation: Offset(0.0, 1.0 - v),
                  child: child,
                ),
              ),
            );
          },
          child: _lastReplyData != null
              ? _buildReplyContainer(_lastReplyData!, themeColor)
              : const SizedBox.shrink(),
        ),

        // ── Attachment picker (sibling above the input pill so it tracks
        //     keyboard offset automatically) ──────────────────────────
        AnimatedBuilder(
          animation: _attachAnimation,
          builder: (context, child) {
            final v = _attachAnimation.value;
            if (v == 0.0) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                heightFactor: v,
                child: Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, (1.0 - v) * 24),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: _attachmentMenuVisible
              ? _buildAttachmentMenu(themeColor)
              : null,
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Input pill: emoji • text • attachment ───────────────
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: shouldDisableSending
                        ? Colors.grey[200]
                        : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 0.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Emoji ↔ keyboard toggle
                      IconButton(
                        icon: Icon(
                          _showEmojiPanel
                              ? Icons.keyboard_outlined
                              : Icons.sentiment_satisfied_alt_outlined,
                          color: shouldDisableSending
                              ? Colors.grey[400]
                              : (_showEmojiPanel
                                    ? themeColor.primary
                                    : Colors.grey[600]),
                        ),
                        onPressed: shouldDisableSending
                            ? null
                            : _toggleEmojiPanel,
                        splashRadius: 22,
                      ),
                      Expanded(
                        child: TextField(
                          controller: widget.messageController,
                          focusNode: widget.focusNode,
                          enabled: !shouldDisableSending,
                          decoration: InputDecoration(
                            hintText: shouldDisableSending
                                ? 'Messaging is disabled outside active hours'
                                : 'Message',
                            hintStyle: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1F2329),
                          ),
                          maxLines: 6,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: shouldDisableSending
                              ? null
                              : (value) {
                                  if (widget.onTyping != null) {
                                    widget.onTyping!(value);
                                  }
                                  if (widget.onFocusChange != null) {
                                    widget.onFocusChange!(
                                      widget.focusNode?.hasFocus ?? false,
                                    );
                                  }
                                },
                          onTap: () {
                            if (_showEmojiPanel) {
                              setState(() => _showEmojiPanel = false);
                            }
                            if (widget.onFocusChange != null) {
                              widget.onFocusChange!(true);
                            }
                          },
                        ),
                      ),
                      // Attachment (paperclip, slightly tilted like Telegram)
                      IconButton(
                        icon: Transform.rotate(
                          angle: -0.6,
                          child: Icon(
                            Icons.attach_file_rounded,
                            color: shouldDisableSending
                                ? Colors.grey[400]
                                : (_attachmentMenuVisible
                                      ? themeColor.primary
                                      : Colors.grey[700]),
                          ),
                        ),
                        onPressed: shouldDisableSending
                            ? null
                            : _toggleAttachmentMenu,
                        splashRadius: 22,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ── Standalone circular send / mic button ──────────────
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.messageController,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.primary.withAlpha(60),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: (shouldDisableSending || widget.isSending)
                          ? Colors.grey[400]
                          : themeColor.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: (shouldDisableSending || widget.isSending)
                            ? null
                            : (hasText
                                  ? () =>
                                        widget.onSendMessage!(MessageType.text)
                                  : () => widget.onSendVoiceNote!()),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            hasText
                                ? Icons.send_rounded
                                : Icons.mic_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // ── Emoji panel (sits where the keyboard would be) ────────────
        if (_showEmojiPanel)
          SizedBox(
            height: 300,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) => _insertEmoji(emoji.emoji),
              onBackspacePressed: _emojiBackspace,
              config: Config(
                emojiViewConfig: const EmojiViewConfig(
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
                  iconColorSelected: themeColor.primary,
                  indicatorColor: themeColor.primary,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentMenu(themeColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _AttachmentTile(
              icon: Icons.image_outlined,
              label: 'Gallery',
              color: const Color(0xFF3B82F6),
              onTap: () => _onAttachmentOption(widget.onPickGallery),
            ),
            _AttachmentTile(
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              color: const Color(0xFFE0457B),
              onTap: () => _onAttachmentOption(widget.onPickCamera),
            ),
            _AttachmentTile(
              icon: Icons.description_outlined,
              label: 'Document',
              color: const Color(0xFF7C3AED),
              onTap: () => _onAttachmentOption(widget.onPickDocument),
            ),
            _AttachmentTile(
              icon: Icons.person_outline_rounded,
              label: 'Contact',
              color: const Color(0xFF22C55E),
              onTap: () => _onAttachmentOption(widget.onPickContact),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyContainer(MessageModel replyMessage, themeColor) {
    final isRepliedMessageMine = replyMessage.senderId == widget.currentUserId;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: widget.dm != null
            ? const BorderRadius.only(topRight: Radius.circular(12))
            : const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: themeColor.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.reply, size: 16, color: themeColor.primary),
                    const SizedBox(width: 4),
                    Text(
                      isRepliedMessageMine ? 'You' : replyMessage.senderName!,
                      style: TextStyle(
                        color: themeColor.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (replyMessage.body?.isNotEmpty ?? false)
                  Text(
                    replyMessage.body!.length > 50
                        ? '${replyMessage.body!.substring(0, 50)}...'
                        : replyMessage.body!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    '📎 media',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onCancelReply,
            icon: Icon(Icons.close, size: 20, color: themeColor.primary),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  bool _isCommunityGroupActive() {
    if (!widget.isCommunityGroup || widget.communityGroupMetadata == null) {
      return true;
    }

    final metadata = widget.communityGroupMetadata!;
    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);

    for (final timeSlot in metadata.activeTimeSlots) {
      if (_isTimeInRange(currentTime, timeSlot.startTime, timeSlot.endTime)) {
        return true;
      }
    }

    return false;
  }

  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  Widget _buildTimeRestrictionNotice() {
    final metadata = widget.communityGroupMetadata;
    if (metadata == null || metadata.activeTimeSlots.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeTimeSlotsText = metadata.activeTimeSlots
        .map((slot) => slot.displayTime)
        .join(', ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: Colors.orange[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messaging restricted',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Active: $activeTimeSlotsText',
                  style: TextStyle(color: Colors.orange[700], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single labelled tile in the attachment picker grid.
class _AttachmentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
