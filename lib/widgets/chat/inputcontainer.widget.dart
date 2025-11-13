import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../models/community_model.dart';
import '../../models/conversation_model.dart';

class MessageInputContainer extends StatelessWidget {
  final TextEditingController messageController;
  final ValueNotifier<bool> isOtherTypingNotifier;
  final Widget? typingIndicator;
  final bool isReplying;
  final MessageModel? replyToMessageData;
  final int? currentUserId;
  final VoidCallback? onSendMessage;
  final VoidCallback? onSendVoiceNote;
  final VoidCallback? onAttachmentTap;
  final ValueChanged<String>? onTyping;
  final VoidCallback? onCancelReply;

  // For community group restrictions
  final bool isCommunityGroup;
  final CommunityGroupMetadata? communityGroupMetadata;

  // For DM - to determine if replied message is mine
  final ConversationModel? conversation;

  const MessageInputContainer({
    super.key,
    required this.messageController,
    required this.isOtherTypingNotifier,
    this.typingIndicator,
    required this.isReplying,
    this.replyToMessageData,
    this.currentUserId,
    this.onSendMessage,
    this.onSendVoiceNote,
    this.onAttachmentTap,
    this.onTyping,
    this.onCancelReply,
    this.isCommunityGroup = false,
    this.communityGroupMetadata,
    this.conversation,
  });

  @override
  Widget build(BuildContext context) {
    // Check if this is a community group and if sending is allowed
    final isCommunityGroupActive = _isCommunityGroupActive();
    final shouldDisableSending = isCommunityGroup && !isCommunityGroupActive;

    return Column(
      children: [
        // Time restriction notice for community groups
        if (isCommunityGroup && !isCommunityGroupActive)
          _buildTimeRestrictionNotice(),

        // Typing indicator
        ValueListenableBuilder<bool>(
          valueListenable: isOtherTypingNotifier,
          builder: (context, isOtherTyping, child) {
            if (isOtherTyping && typingIndicator != null) {
              return typingIndicator!;
            }
            return const SizedBox.shrink();
          },
        ),

        // Reply container
        if (isReplying && replyToMessageData != null) _buildReplyContainer(),

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
                onPressed: shouldDisableSending ? null : onAttachmentTap,
              ),
              Expanded(
                child: TextField(
                  controller: messageController,
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
                  onChanged: shouldDisableSending ? null : onTyping,
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: shouldDisableSending
                    ? null
                    : (messageController.text.isNotEmpty
                          ? onSendMessage
                          : onSendVoiceNote),
                backgroundColor: shouldDisableSending
                    ? Colors.grey[400]
                    : Colors.teal,
                mini: true,
                child: messageController.text.isNotEmpty
                    ? Icon(
                        Icons.send,
                        color: shouldDisableSending
                            ? Colors.grey[600]
                            : Colors.white,
                      )
                    : Icon(
                        Icons.mic,
                        color: shouldDisableSending
                            ? Colors.grey[600]
                            : Colors.white,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyContainer() {
    final replyMessage = replyToMessageData!;

    // Determine if replied message is from current user
    final isRepliedMessageMine = _determineIfRepliedMessageIsMine(replyMessage);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: conversation != null
          ? EdgeInsets
                .zero // DM doesn't have horizontal margin
          : const EdgeInsets.symmetric(horizontal: 16), // Group has margin
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: conversation != null
            ? const BorderRadius.only(
                // DM only has topRight
                topRight: Radius.circular(12),
              )
            : const BorderRadius.only(
                // Group has both
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Reply indicator line
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Reply content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.reply, size: 16, color: Colors.teal),
                    const SizedBox(width: 4),
                    Text(
                      isRepliedMessageMine ? 'You' : replyMessage.senderName,
                      style: const TextStyle(
                        color: Colors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (replyMessage.body.isNotEmpty) ...[
                  Text(
                    replyMessage.body.length > 50
                        ? '${replyMessage.body.substring(0, 50)}...'
                        : replyMessage.body,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  const Text(
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
              ],
            ),
          ),

          // Cancel reply button
          IconButton(
            onPressed: onCancelReply,
            icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  bool _determineIfRepliedMessageIsMine(MessageModel replyMessage) {
    if (currentUserId != null) {
      return replyMessage.senderId == currentUserId;
    }
    // For DM, if currentUserId is null, check against conversation.userId
    if (conversation != null) {
      return replyMessage.senderId != conversation!.userId;
    }
    // For group, if currentUserId is null, assume it's not mine
    return false;
  }

  // Helper method to check if community group is active
  bool _isCommunityGroupActive() {
    if (!isCommunityGroup || communityGroupMetadata == null) {
      return true; // Regular groups are always active
    }

    final metadata = communityGroupMetadata!;
    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);

    // Check if current time is within any active time slot
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
      // Same day range
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Crosses midnight
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  Widget _buildTimeRestrictionNotice() {
    final metadata = communityGroupMetadata;
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
