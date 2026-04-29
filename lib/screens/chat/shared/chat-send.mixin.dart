import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_service.dart';
import '../../../db/repositories/message-status.repo.dart';
import '../../../db/repositories/message.repo.dart';
import '../../../models/message.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/draft.provider.dart';
import '../../../services/socket/transport.manager.dart';
import '../../../types/socket.types.dart';
import '../../../utils/id.utils.dart';

/// Send-pipeline plumbing shared by DM and group messaging screens.
///
/// **Stage A** (current): owns the resending-failed-messages map and the
/// four "simpler" methods — `isResendingFailedMessage`,
/// `resendFailedMessage`, `resendAllFailedMessages`, `markMessageAsFailed`.
///
/// Stages B and C will fold in `sendMediaMessageToServer` and the main
/// `sendMessage` once we have these stable.
mixin ChatSendMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Tracks which failed messages are currently being resent so concurrent
  /// taps on the retry button don't fire multiple resend attempts.
  final Map<String, bool> resendingFailedMessages = {};

  /// Exponential-backoff schedule for the in-screen periodic retry: starts
  /// at [_initialRetryInterval], doubles each tick until capped at
  /// [_maxRetryInterval]. The backoff resets to the initial value on the
  /// next user-initiated failure (one that didn't come from a retry pass),
  /// so persistent failures don't keep retrying every 2s forever.
  ///
  /// The global `MessageGarbageCollector` retries WS payloads on its own
  /// fixed cadence; this mixin's role is the screen-level path that
  /// actually re-uploads media from `attachments['local_path']`.
  static const Duration _initialRetryInterval = Duration(seconds: 2);
  static const Duration _maxRetryInterval = Duration(seconds: 20);

  Timer? _autoRetryTimer;
  Duration _currentRetryDelay = _initialRetryInterval;
  bool _retryPassInProgress = false;

  /// Hosts call this from `initState` after the transport / repos are wired.
  void startSendAutoRetry() {
    _autoRetryTimer?.cancel();
    _currentRetryDelay = _initialRetryInterval;
    _autoRetryTimer = Timer(_currentRetryDelay, _runRetryTick);
  }

  /// Hosts call this from `dispose`.
  void stopSendAutoRetry() {
    _autoRetryTimer?.cancel();
    _autoRetryTimer = null;
  }

  Future<void> _runRetryTick() async {
    if (!mounted) return;
    await resendAllFailedMessages();
    if (!mounted) return;
    // Back off for the next tick (cap at max).
    final nextSeconds = (_currentRetryDelay.inSeconds * 2).clamp(
      _initialRetryInterval.inSeconds,
      _maxRetryInterval.inSeconds,
    );
    _currentRetryDelay = Duration(seconds: nextSeconds);
    _autoRetryTimer = Timer(_currentRetryDelay, _runRetryTick);
  }

  void _resetRetryBackoff() {
    _autoRetryTimer?.cancel();
    _currentRetryDelay = _initialRetryInterval;
    _autoRetryTimer = Timer(_currentRetryDelay, _runRetryTick);
  }

  // ---- Inherited from sibling mixins ----
  bool get canSetState;
  void safeSetState(VoidCallback fn);
  List<MessageModel> get messages;

  /// The reply target — host has this on ChatActionsMixin.
  MessageModel? get replyToMessageData;
  set replyToMessageData(MessageModel? value);

  String? get currentUserId;
  String? get currentUserName;
  String? get currentUserProfilePic;
  String get conversationId;
  MessageRepository get messagesRepo;
  MessageStatusRepository get messageStatusRepo;
  ApiService get chatApiService;
  TransportManager get transportManager;
  TextEditingController get messageController;
  Map<String, dynamic>? get pendingContactMetadata;
  set pendingContactMetadata(Map<String, dynamic>? value);

  /// Conversation-specific list of user ids that should get a "sent" status
  /// row when the WebSocket transport accepts the message. DMs return the
  /// single recipient; groups return all members minus the current user.
  List<String> get statusAckRecipientIds;

  /// Non-null reason → bail out of [sendMessage] without sending. Group
  /// returns a reason when the current user has been removed from the
  /// conversation; DM uses the default (`null`, send always allowed).
  String? get sendMessageBlockedReason => null;

  /// Hides/shows the "sending…" affordance in the input bar.
  bool isSendingMessage = false;

  /// Re-emit the in-memory `messages` list in send-time order. Provided by
  /// `ChatSyncMixin`.
  void sortMessagesBySentAt();

  /// Animation hook used after we slot a new message into the list. Both
  /// already provided by `ChatScrollMixin`.
  void animateNewMessage(String messageId);
  void handleScrollToBottomTap();

  /// Cancels the staged reply. Provided by `ChatActionsMixin`.
  void cancelReply();

  // ---- Methods ----

  bool isResendingFailedMessage(String messageId) =>
      resendingFailedMessages[messageId] == true;

  /// Strips transient upload-state keys from [attachments] before they hit
  /// the local DB. The in-memory copy keeps these keys so the UI can render
  /// the cloud icon and live progress percent — but they must never reach
  /// the server, and the DB row is what `MessageGarbageCollector` reads
  /// when it resends a stalled message via WebSocket.
  Map<String, dynamic>? _stripUploadFlagsForPersistence(
    Map<String, dynamic>? attachments,
  ) {
    if (attachments == null || attachments.isEmpty) return attachments;
    final clean = Map<String, dynamic>.from(attachments)
      ..remove('upload_progress')
      ..remove('is_uploading')
      ..remove('upload_failed');
    return clean.isEmpty ? null : clean;
  }

  /// Stamp a message as failed in both the in-memory list and the local DB.
  /// Always rebuilds the attachments map (defaulting to empty when absent)
  /// so the upload-state flags are present regardless of the original
  /// shape.
  Future<void> markMessageAsFailed(String messageId) async {
    if (!canSetState) return;

    final index = messages.indexWhere((msg) => msg.id == messageId);
    if (index == -1) return;

    final failedMsg = messages[index];
    final updatedAttachments = Map<String, dynamic>.from(
      failedMsg.attachments ?? {},
    );
    updatedAttachments['is_uploading'] = false;
    updatedAttachments['upload_failed'] = true;

    final updatedMessage = failedMsg.copyWith(
      isFailed: true,
      attachments: updatedAttachments,
    );

    safeSetState(() {
      messages[index] = updatedMessage;
    });

    await messagesRepo.updateMessageFields(
      messageId,
      isFailed: true,
      attachments: _stripUploadFlagsForPersistence(updatedAttachments),
    );

    // A fresh user-initiated failure resets the backoff so the next retry
    // happens quickly. Failures that bubble up from inside a retry pass
    // preserve the current backoff so persistent failures keep slowing.
    if (!_retryPassInProgress) {
      _resetRetryBackoff();
    }
  }

  Future<void> resendFailedMessage(String messageId) async {
    // Already in-flight? Bail. (This is the canonical guard — outer callers
    // don't need to wrap the call site in another check.)
    if (isResendingFailedMessage(messageId)) return;

    try {
      safeSetState(() {
        resendingFailedMessages[messageId] = true;
      });

      final message = await messagesRepo.getMessageById(messageId);
      if (message == null) {
        debugPrint('Message not found: $messageId');
        return;
      }
      if (!message.isFailed) {
        debugPrint('Message is not in failed status');
        return;
      }

      // Preserve and restore the reply target around the resend so the
      // currently-staged reply isn't clobbered by the failed message's
      // original reply.
      final originalReplyToMessageData = replyToMessageData;
      final replyToMessageId = message.repliedTo;
      if (replyToMessageId != null) {
        final replyToMessage = await messagesRepo.getMessageById(
          replyToMessageId,
        );
        if (replyToMessage != null) {
          replyToMessageData = replyToMessage;
        }
      }

      try {
        final isMediaMessage = message.type == MessageType.image ||
            message.type == MessageType.video ||
            message.type == MessageType.audio ||
            message.type == MessageType.document;

        if (isMediaMessage) {
          final localPath = message.attachments?['local_path'] as String?;
          if (localPath == null || localPath.isEmpty) {
            debugPrint(
              'No local_path found in attachments for failed media message',
            );
            return;
          }
          final mediaFile = File(localPath);
          if (!mediaFile.existsSync()) {
            debugPrint('Media file not found at path: $localPath');
            return;
          }
          await sendMediaMessageToServer(
            mediaFile,
            message.type,
            existingMessageId: messageId,
          );
        } else {
          sendMessage(
            message.type,
            messageId: messageId,
            body: message.body,
          );
        }
      } finally {
        replyToMessageData = originalReplyToMessageData;
      }
    } catch (e) {
      debugPrint('Error resending failed message: $e');
    } finally {
      if (canSetState) {
        safeSetState(() {
          resendingFailedMessages.remove(messageId);
        });
      } else {
        resendingFailedMessages.remove(messageId);
      }
    }
  }

  /// Builds the optimistic message, persists it (or its post-upload media
  /// row), pushes the WebSocket payload, and writes per-recipient sent
  /// status rows once the transport accepts. On transport failure marks
  /// the message failed.
  ///
  /// [retryCount] is incremented when a UUIDv7 collision (sqlite errorCode
  /// 1555) forces a regeneration; the recursive call drops the same
  /// [mediaResponse] so a successful upload doesn't get re-uploaded.
  /// [body] is set on the resend path — it bypasses
  /// [messageController]'s text and clears the in-flight reply state.
  Future<void> sendMessage(
    MessageType messageType, {
    MediaResponse? mediaResponse,
    String? messageId,
    int? retryCount = 0,
    String? body,
  }) async {
    final blockedReason = sendMessageBlockedReason;
    if (blockedReason != null) {
      debugPrint('[SEND] blocked — $blockedReason');
      return;
    }

    if (mounted) {
      safeSetState(() {
        isSendingMessage = true;
      });
    }

    String messageText = '';
    if (messageType == MessageType.text ||
        messageType == MessageType.contact) {
      messageText = body ?? messageController.text.trim();
      if (messageText.isEmpty) return;
    }

    final isResend = body != null;

    if (!isResend) {
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      await draftNotifier.removeDraft(conversationId);
    }

    final id = messageId ?? newMessageId();
    final nowUTC = DateTime.now().toUtc();

    // Merge contact metadata into attachments if present (a contact message
    // carries the picked contacts in attachments alongside any media payload).
    Map<String, dynamic>? combinedAttachments = mediaResponse?.toJson();
    if (!isResend && pendingContactMetadata != null) {
      combinedAttachments = Map<String, dynamic>.from(combinedAttachments ?? {})
        ..addAll(pendingContactMetadata!);
    }

    final newMsg = MessageModel(
      id: id,
      chatId: conversationId,
      senderId: currentUserId,
      senderName: currentUserName,
      senderProfilePic: currentUserProfilePic,
      repliedTo: replyToMessageData?.id,
      type: messageType,
      body: messageText,
      attachments: combinedAttachments,
      sentAt: nowUTC.toIso8601String(),
    );

    if (messageId == null && mediaResponse == null) {
      // Fresh insert — handle UUIDv7 collisions (extremely rare, but the
      // sqlite primary-key constraint will reject duplicates so we re-roll
      // the id and try again up to 5 times).
      final result = await messagesRepo.insertMessage(newMsg);
      if (result["success"] == false && result["errorCode"] == 1555) {
        debugPrint('[SEND] uuid collision — retry $retryCount: $result');
        if ((retryCount ?? 0) > 5) return;
        sendMessage(
          messageType,
          mediaResponse: mediaResponse,
          retryCount: (retryCount ?? 0) + 1,
        );
        return;
      }
    } else if (messageId != null && mediaResponse != null) {
      // Post-upload path: swap the optimistic placeholder's attachments
      // for the cloud-URL response and clear the failed flag (covers the
      // retry-after-failure case).
      final result = await messagesRepo.updateMessageFields(
        id,
        attachments: mediaResponse.toJson(),
        isFailed: false,
      );
      if (result.isError) {
        debugPrint(
          '[SEND] failed to write media row, errorCode: ${result.errorCode}',
        );
        return;
      }
    }

    if (!isResend) {
      messageController.clear();
      pendingContactMetadata = null;
    }

    if (canSetState) {
      safeSetState(() {
        final index = messages.indexWhere((msg) => msg.id == id);
        if (index != -1) {
          messages[index] = newMsg;
          sortMessagesBySentAt();
        } else {
          messages.add(newMsg);
        }
      });
      animateNewMessage(newMsg.id);
      handleScrollToBottomTap();
    }

    final messagePayload = ChatMessagePayload(
      id: id,
      convId: conversationId,
      senderId: currentUserId ?? '',
      attachments: combinedAttachments,
      msgType: messageType,
      body: messageText,
      repliedTo: replyToMessageData?.id,
      sentAt: nowUTC,
    );

    final wsmsg = WSMessage(
      type: WSMessageType.messageNew,
      payload: messagePayload,
      wsTimestamp: DateTime.now(),
    ).toJson();

    ref
        .read(chatProvider.notifier)
        .updateLastMessageOnSendingOwnMessage(conversationId, newMsg);

    cancelReply();

    // Fire-and-forget. The MessageSentAckPayload handler flips the bubble
    // to "sent" on success; a transport rejection here flips it to failed.
    try {
      if (!transportManager.isConnected) {
        debugPrint('[SEND] transport disconnected — marking failed');
        markMessageAsFailed(newMsg.id);
      } else {
        unawaited(
          transportManager
              .sendMessage(wsmsg)
              .then((sendResult) async {
                if (sendResult == true) {
                  await messageStatusRepo
                      .insertMessageStatusesWithMultipleUserIds(
                        messageId: newMsg.id,
                        chatId: conversationId,
                        userIds: statusAckRecipientIds,
                      );
                } else {
                  debugPrint('[SEND] transport returned false — marking failed');
                  await markMessageAsFailed(newMsg.id);
                }
              })
              .catchError((e) {
                debugPrint('[SEND] transport threw: $e');
                markMessageAsFailed(newMsg.id);
              }),
        );
      }
    } catch (e) {
      debugPrint('[SEND] transport threw (sync path): $e');
      markMessageAsFailed(newMsg.id);
    }

    if (mounted) {
      safeSetState(() {
        isSendingMessage = false;
      });
    }
  }

  /// Uploads [mediaFile], shows progress on the optimistic message, and on
  /// success forwards into [sendMessage] (text-style send) with the
  /// resulting [MediaResponse]. On upload failure, marks the message
  /// failed via [markMessageAsFailed].
  ///
  /// When [existingMessageId] is provided this is a retry path — the
  /// in-memory message at that id is replaced with a fresh "uploading"
  /// version (so the bubble flips back from failed → uploading state).
  Future<void> sendMediaMessageToServer(
    File mediaFile,
    MessageType messageType, {
    String? existingMessageId,
  }) async {
    final messageId = existingMessageId ?? newMessageId();
    final nowUTC = DateTime.now().toUtc();

    final fileName = mediaFile.path.split('/').last;
    final attachments = <String, dynamic>{
      'file_name': fileName,
      'local_path': mediaFile.path,
      'is_uploading': true,
      'upload_progress': 0,
    };

    final newMsg = MessageModel(
      id: messageId,
      chatId: conversationId,
      senderId: currentUserId,
      senderName: currentUserName,
      senderProfilePic: currentUserProfilePic,
      repliedTo: replyToMessageData?.id,
      attachments: attachments,
      localMediaPath: mediaFile.path,
      type: messageType,
      sentAt: nowUTC.toIso8601String(),
    );

    if (canSetState) {
      if (existingMessageId != null) {
        // Retry: swap the existing failed message with the fresh uploading
        // one. DB row stays as-is; the next `sendMessage` call (on
        // upload success) will update it via `_messagesRepo`.
        final index = messages.indexWhere((msg) => msg.id == messageId);
        if (index != -1) {
          safeSetState(() {
            messages[index] = newMsg;
            sortMessagesBySentAt();
          });
          animateNewMessage(newMsg.id);
          handleScrollToBottomTap();
        }
      } else {
        safeSetState(() {
          messages.add(newMsg);
          sortMessagesBySentAt();
        });
        animateNewMessage(newMsg.id);
        handleScrollToBottomTap();
        // Persist a copy without the transient upload-state flags so they
        // don't leak to the server via MSG-GC's WS resend path.
        await messagesRepo.insertMessage(
          newMsg.copyWith(
            attachments: _stripUploadFlagsForPersistence(newMsg.attachments),
          ),
        );
      }
    }

    int? lastProgressUpdate = -1;

    final result = await chatApiService.chat.sendMediaMessage(
      mediaFile,
      onSendProgress: (sent, total) {
        final progress = total > 0 ? ((sent / total) * 100).round() : 0;
        if (progress == lastProgressUpdate || !canSetState) return;
        lastProgressUpdate = progress;

        final index = messages.indexWhere((msg) => msg.id == messageId);
        if (index == -1) return;
        final currentMsg = messages[index];
        final updatedAttachments = Map<String, dynamic>.from(
          currentMsg.attachments ?? {},
        );
        updatedAttachments['upload_progress'] = progress;
        updatedAttachments['is_uploading'] = true;
        safeSetState(() {
          messages[index] = currentMsg.copyWith(
            attachments: updatedAttachments,
          );
        });
      },
    );

    if (result.isSuccess && result.data != null) {
      final mediaData = MediaResponse.fromJson(
        result.data as Map<String, dynamic>,
      );

      // Strip the upload-progress flags before forwarding to sendMessage.
      if (canSetState) {
        final index = messages.indexWhere((msg) => msg.id == messageId);
        if (index != -1) {
          final currentMsg = messages[index];
          final updatedAttachments = Map<String, dynamic>.from(
            currentMsg.attachments ?? {},
          )
            ..remove('is_uploading')
            ..remove('upload_progress');
          safeSetState(() {
            messages[index] = currentMsg.copyWith(
              attachments: updatedAttachments,
            );
          });
        }
      }

      sendMessage(
        messageType,
        mediaResponse: mediaData,
        messageId: messageId,
      );
      debugPrint('Media data: $mediaData, messageType: $messageType');
    } else {
      await markMessageAsFailed(messageId);
    }
  }

  /// Auto-retry every failed message in the in-memory list that the current
  /// user owns. Sequential to avoid thundering-herd against the server.
  Future<void> resendAllFailedMessages() async {
    final failed = messages
        .where(
          (msg) =>
              msg.isFailed &&
              msg.senderId == currentUserId &&
              !isResendingFailedMessage(msg.id),
        )
        .toList();

    if (failed.isEmpty) return;
    debugPrint('[RESEND] Auto-resending ${failed.length} failed messages');

    _retryPassInProgress = true;
    try {
      for (final msg in failed) {
        if (!mounted) break;
        await resendFailedMessage(msg.id);
      }
    } finally {
      _retryPassInProgress = false;
    }
  }
}
