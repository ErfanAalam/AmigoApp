import 'dart:ui' as ui;

import 'package:amigo/models/message.model.dart';
import 'package:amigo/types/socket.types.dart';
import 'package:flutter/material.dart';

import '../../utils/chat/chat-helpers.utils.dart';

/// Pinned Message Section Widget for both DM and group chats
/// Displays a pinned message with ability to scroll to it or unpin it
class PinnedMessageSection extends StatelessWidget {
  final MessageModel? pinnedMessage;
  final String? currentUserId;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  const PinnedMessageSection({
    super.key,
    required this.pinnedMessage,
    required this.currentUserId,
    required this.onTap,
    required this.onUnpin,
  });

  /// Determine if pinned message is from current user
  bool get _isMyMessage {
    return currentUserId != null && pinnedMessage?.senderId == currentUserId;
  }

  String _mediaPlaceholder(MessageType? type) {
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎤 Voice message';
      case MessageType.document:
        return '📎 File';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageTime = ChatHelpers.formatMessageTime(
      pinnedMessage?.sentAt ?? '',
    );

    return Padding(
      // Outside spacing — keep the gap OUTSIDE the ClipRRect so the blur
      // doesn't extend into the gutter.
      padding: const EdgeInsets.all(5),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color.fromRGBO(220, 232, 245, 0.8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.25),
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(14),
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
                    child: const Icon(
                      Icons.push_pin,
                      size: 16,
                      color: Colors.white,
                    ),
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
                              _isMyMessage
                                  ? 'You'
                                  : pinnedMessage?.senderName ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              messageTime,
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Message text
                        Text(
                          pinnedMessage?.body?.isNotEmpty == true
                              ? pinnedMessage!.body!
                              : _mediaPlaceholder(pinnedMessage?.type),
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
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
