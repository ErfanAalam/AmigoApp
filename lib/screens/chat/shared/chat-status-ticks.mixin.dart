import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../models/message.model.dart';
import '../../../types/socket.types.dart';
import 'chat-bubble.mixin.dart' show buildUploadingStatusTick;

/// Renders the read / delivered / sent / unsent / uploading / failed ticks
/// next to a message bubble. Both DM and group used near-identical
/// implementations; the only behavioral difference was that group dropped
/// the `unsent` clock-icon to a single grey tick — which the unified
/// implementation here corrects.
///
/// Satisfies the `buildMessageStatusTicks` abstract on `ChatBubbleMixin`
/// directly: hosts no longer need a tear-off override.
mixin ChatStatusTicksMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Provided by `ChatSyncMixin`.
  Map<String, MessageStatusType> get deliveryStatusByMessage;

  Widget buildMessageStatusTicks(MessageModel message) {
    if (message.isFailed) {
      return const Icon(
        Icons.error_outline_rounded,
        size: 16,
        color: Colors.red,
      );
    }
    final status = deriveMessageStatus(message);
    switch (status) {
      case MessageStatusType.read:
        return const Icon(Icons.done_all_rounded, size: 16, color: Colors.blue);
      case MessageStatusType.delivered:
        return Icon(Icons.done_all_rounded, size: 16, color: Colors.grey[500]);
      case MessageStatusType.sent:
        return Icon(Icons.done_rounded, size: 16, color: Colors.grey[500]);
      case MessageStatusType.unsent:
        return Icon(
          Icons.access_time_rounded,
          size: 16,
          color: Colors.grey[500],
        );
      case MessageStatusType.uploading:
        return buildUploadingStatusTick(message);
      case MessageStatusType.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: Colors.red,
        );
    }
  }

  MessageStatusType deriveMessageStatus(MessageModel message) {
    if (message.isFailed) return MessageStatusType.failed;
    final atts = message.attachments;
    if (atts is Map<String, dynamic> && atts['is_uploading'] == true) {
      return MessageStatusType.uploading;
    }
    return deliveryStatusByMessage[message.id] ?? MessageStatusType.sent;
  }
}
