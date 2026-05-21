import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/repositories/message.repo.dart';
import '../../models/message.model.dart';
import '../../providers/message.provider.dart';
import '../../providers/theme-color.provider.dart';
import '../../types/socket.types.dart';
import '../../utils/chat/chat-helpers.utils.dart';

/// Per-chat list of locally-starred messages, most-recently-starred first.
/// Pushed from chat-details. Star toggle is a SQLite write that all message
/// streams already observe — the bubble star icon in the messaging screen
/// flips in lock-step.
class StarredMessagesScreen extends ConsumerWidget {
  final String chatId;
  final String chatTitle;

  const StarredMessagesScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);
    final starredAsync = ref.watch(starredMessagesStreamProvider(chatId));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Starred Messages',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                letterSpacing: 0.1,
              ),
            ),
            Text(
              chatTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: starredAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            'Could not load starred messages',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        data: (messages) {
          if (messages.isEmpty) return _EmptyState(accent: themeColor.primary);
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _StarredMessageCard(
              message: messages[i],
              accent: themeColor.primary,
            ),
          );
        },
      ),
    );
  }
}

class _StarredMessageCard extends StatelessWidget {
  final MessageModel message;
  final Color accent;

  const _StarredMessageCard({required this.message, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 0.6),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.senderName?.trim().isNotEmpty == true
                            ? message.senderName!
                            : 'You',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: accent,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatStarredAt(message.starredAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _MessagePreview(message: message),
                const SizedBox(height: 6),
                Text(
                  ChatHelpers.formatMessageTime(message.sentAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          _UnstarButton(messageId: message.id),
        ],
      ),
    );
  }

  /// Compact relative-ish formatter for the "starred at" timestamp shown in
  /// the corner of each card. Keeps the row tight — most recently starred
  /// reads as "just now", older entries fall back to date.
  String _formatStarredAt(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }
}

class _MessagePreview extends StatelessWidget {
  final MessageModel message;
  const _MessagePreview({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Text(
        'this message was deleted',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final body = message.body?.trim() ?? '';
    if (body.isNotEmpty) {
      return Text(
        body,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14.5,
          color: Colors.black87,
          height: 1.35,
        ),
      );
    }

    final (icon, label) = _typeGlyph(message.type);
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  (IconData, String) _typeGlyph(MessageType t) {
    switch (t) {
      case MessageType.image:
        return (Icons.image_outlined, 'Photo');
      case MessageType.video:
        return (Icons.videocam_outlined, 'Video');
      case MessageType.audio:
        return (Icons.mic_none_rounded, 'Voice message');
      case MessageType.document:
        return (Icons.description_outlined, 'Document');
      case MessageType.contact:
        return (Icons.person_outline, 'Contact');
      case MessageType.forwarded:
        return (Icons.forward, 'Forwarded message');
      default:
        return (Icons.message_outlined, 'Message');
    }
  }
}

class _UnstarButton extends StatelessWidget {
  final String messageId;
  const _UnstarButton({required this.messageId});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Unstar',
      splashRadius: 22,
      icon: Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 22),
      onPressed: () => MessageRepository().unstarMessage(messageId),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color accent;
  const _EmptyState({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_outline_rounded,
                size: 38,
                color: accent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No starred messages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Long-press any message and tap Star to keep it handy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
