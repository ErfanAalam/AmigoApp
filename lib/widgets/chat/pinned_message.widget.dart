import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../utils/chat/chat_helpers.dart';

/// Pinned Message Section Widget for both DM and group chats
/// Displays a pinned message with ability to scroll to it or unpin it
class PinnedMessageSection extends StatelessWidget {
  final MessageModel pinnedMessage;
  final int? currentUserId;
  final int? conversationUserId; // For DM fallback logic
  final bool isGroupChat;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  const PinnedMessageSection({
    super.key,
    required this.pinnedMessage,
    required this.currentUserId,
    this.conversationUserId,
    required this.isGroupChat,
    required this.onTap,
    required this.onUnpin,
  });

  /// Determine if pinned message is from current user
  bool get _isMyMessage {
    if (isGroupChat) {
      // Group chat: simple check
      return currentUserId != null && pinnedMessage.senderId == currentUserId;
    } else {
      // DM chat: more complex logic with fallback
      return currentUserId != null
          ? pinnedMessage.senderId == currentUserId
          : pinnedMessage.senderId != conversationUserId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageTime = ChatHelpers.formatMessageTime(pinnedMessage.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          border: Border.all(color: Colors.blue[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Pin icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue[400],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.push_pin, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 12),

            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name and time
                  Row(
                    children: [
                      Text(
                        _isMyMessage ? 'You' : pinnedMessage.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        messageTime,
                        style: TextStyle(color: Colors.blue[600], fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Message text
                  Text(
                    pinnedMessage.body,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Unpin button
            IconButton(
              onPressed: onUnpin,
              icon: Icon(Icons.close, size: 18, color: Colors.blue[600]),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
