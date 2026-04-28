import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/message.model.dart';
import '../../../services/media-cache.service.dart';
import '../../../types/socket.types.dart';
import '../../../ui/chat/media-messages.widget.dart';
import '../../../utils/chat/audio-playback.utils.dart';
import '../../../utils/chat/chat-helpers.utils.dart';

/// Builds the [MediaMessageConfig] used by image / video / document / audio
/// bubble widgets in DM and group screens. Hosts pass in the per-conversation
/// callbacks and repos; everything else is wired identically.
///
/// [cacheCheckExisting] / [cacheDebugPrefix] mirror
/// [ChatHelpers.cacheMediaForMessage] — group passes
/// `cacheCheckExisting: false, cacheDebugPrefix: 'group message'`; DMs use the
/// defaults.
MediaMessageConfig buildMediaMessageConfig({
  required MessageModel message,
  required bool isMyMessage,
  required bool isStarred,
  required bool Function() mounted,
  required VoidCallback onSetState,
  required void Function(String) showErrorDialog,
  required Widget Function(MessageModel) buildMessageStatusTicks,
  required void Function(String url, String? caption) onImagePreview,
  required void Function(String url, String? caption, String? fileName)
  onVideoPreview,
  required void Function(
    String url,
    String? fileName,
    String? caption,
    int? fileSize,
  )
  onDocumentPreview,
  required Future<void> Function(File file, MessageType type)
  sendMediaMessageToServer,
  required Map<String, String?> videoThumbnailCache,
  required Map<String, Future<String?>> videoThumbnailFutures,
  required AudioPlaybackManager audioPlaybackManager,
  required MediaCacheService mediaCacheService,
  required void Function(String messageId) onResendFailedMessage,
  required Future<void> Function(String messageId) onDeleteFailedMessage,
  bool cacheCheckExisting = true,
  String? cacheDebugPrefix,
}) {
  return MediaMessageConfig(
    message: message,
    isMyMessage: isMyMessage,
    isStarred: isStarred,
    mounted: mounted,
    setState: onSetState,
    showErrorDialog: showErrorDialog,
    buildMessageStatusTicks: buildMessageStatusTicks,
    onImagePreview: onImagePreview,
    onRetryImage: (file, source, {MessageModel? failedMessage}) {
      sendMediaMessageToServer(file, MessageType.image);
    },
    onCacheImage: (url, id) {
      ChatHelpers.cacheMediaForMessage(
        url: url,
        messageId: id.toString(),
        mediaCacheService: mediaCacheService,
        checkExistingCache: cacheCheckExisting,
        debugPrefix: cacheDebugPrefix,
      );
    },
    onVideoPreview: onVideoPreview,
    onRetryVideo: (file, source, {MessageModel? failedMessage}) {
      sendMediaMessageToServer(file, MessageType.video);
    },
    videoThumbnailCache: videoThumbnailCache,
    videoThumbnailFutures: videoThumbnailFutures,
    onDocumentPreview: onDocumentPreview,
    onRetryDocument:
        (file, fileName, extension, {MessageModel? failedMessage}) {
          sendMediaMessageToServer(file, MessageType.document);
        },
    audioPlaybackManager: audioPlaybackManager,
    onRetryAudio: ({MessageModel? failedMessage}) {
      sendMediaMessageToServer(
        File(failedMessage?.attachments?['url'] ?? ''),
        MessageType.audio,
      );
    },
    onResendFailedMessage: onResendFailedMessage,
    onDeleteFailedMessage: onDeleteFailedMessage,
  );
}

/// Resolves the right media-bubble widget for [message]. Prefers the
/// `attachments.category` ("images" / "videos" / "docs" / "audios") and
/// falls back to [MessageType] for messages that lack an attachments map.
/// Returns `null` for non-media messages — callers render their text
/// fallback in that case.
Widget? buildMediaBubbleForMessage({
  required MessageModel message,
  required MediaMessageConfig config,
  required WidgetRef ref,
}) {
  final attachments = message.attachments;
  if (attachments is Map<String, dynamic>) {
    switch ((attachments['category'] as String?)?.toLowerCase()) {
      case 'images':
        return buildImageMessage(config, ref);
      case 'videos':
        return buildVideoMessage(config, ref);
      case 'docs':
        return buildDocumentMessage(config, ref);
      case 'audios':
        return buildAudioMessage(config, ref);
    }
  }
  switch (message.type) {
    case MessageType.image:
      return buildImageMessage(config, ref);
    case MessageType.video:
      return buildVideoMessage(config, ref);
    case MessageType.audio:
      return buildAudioMessage(config, ref);
    case MessageType.document:
      return buildDocumentMessage(config, ref);
    case MessageType.attachment:
      // Legacy: server used to send media with type="attachment".
      return buildImageMessage(config, ref);
    default:
      return null;
  }
}
