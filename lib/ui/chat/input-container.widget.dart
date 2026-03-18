import 'package:amigo/models/conversations.model.dart';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/types/socket.types.dart';
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
  final int? currentUserId;
  final Function(MessageType)? onSendMessage;
  final VoidCallback? onSendVoiceNote;
  final VoidCallback? onAttachmentTap;
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
    this.onAttachmentTap,
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _replyAnim;
  late final Animation<double> _replyAnimation;

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

    if (widget.isReplying && widget.replyToMessageData != null) {
      _lastReplyData = widget.replyToMessageData;
      _replyAnim.value = 1.0;
    }
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
    } else if (isShowing && widget.replyToMessageData != oldWidget.replyToMessageData) {
      // Changed reply target — swap content, no animation change needed
      setState(() => _lastReplyData = widget.replyToMessageData);
    }
  }

  @override
  void dispose() {
    _replyAnim.dispose();
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

        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(color: Colors.white),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  Icons.attach_file,
                  color: shouldDisableSending
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
                onPressed: shouldDisableSending ? null : widget.onAttachmentTap,
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: shouldDisableSending
                        ? Colors.grey[200]
                        : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
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
                    if (widget.onFocusChange != null) {
                      widget.onFocusChange!(true);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: (shouldDisableSending || widget.isSending)
                    ? null
                    : (widget.messageController.text.isNotEmpty
                          ? () => widget.onSendMessage!(MessageType.text)
                          : () => widget.onSendVoiceNote!()),
                backgroundColor: themeColor.primary,
                mini: true,
                child: widget.messageController.text.isNotEmpty
                    ? Icon(Icons.send, color: Colors.white)
                    : Icon(Icons.mic, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
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
                      isRepliedMessageMine
                          ? 'You'
                          : replyMessage.senderName!,
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
