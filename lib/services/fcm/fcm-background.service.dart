import 'dart:async';
import 'dart:convert';
import 'package:amigo/env.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message-status.repo.dart';
import 'package:amigo/models/message.model.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../api/api_service.dart';
import '../../services/auth/auth.service.dart';
import '../../services/cookies.service.dart';
import '../../models/call.model.dart';
import '../../utils/call.utils.dart';
import '../../types/socket.types.dart';
import '../../utils/user.utils.dart';

import '../fcm/fcm-init.service.dart';

// Global variables for background polling
Timer? _backgroundPollingTimer;
int? _backgroundPollingCallId;

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Initialize ApiService for background handler
  try {
    final cookieService = CookieService();
    await cookieService.init();

    // Initialize API service
    final dio = Dio();
    final authService = AuthService();
    await ApiService.initialize(
      dio: dio,
      cookieService: cookieService,
      authService: authService,
    );
  } catch (e) {
    debugPrint('[FCM BACKGROUND] Error initializing ApiService: $e');
    // Continue anyway - delivery receipts are best-effort
  }

  final NotificationService notifcations = NotificationService();
  await notifcations.initialize();

  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
    final callUtils = CallUtils();
    switch (event?.event) {
      case Event.actionCallAccept:
        final callIdStr = event?.body['id']?.toString();
        final callerIdStr = event?.body['extra']?['callerId']?.toString();
        final callerNameStr = event?.body['extra']?['callerName']?.toString();
        final callerPfpStr = event?.body['extra']?['callerProfilePic']?.toString();
        final callDetails = CallDetails(
          callId: callIdStr != null ? int.tryParse(callIdStr) : null,
          callerId: callerIdStr != null ? int.tryParse(callerIdStr) : null,
          callerName: callerNameStr,
          callerProfilePic: callerPfpStr,
          callStatus: 'answered',
        );
        await callUtils.saveCallDetails(callDetails);

        // Stop background polling since call is accepted
        _stopBackgroundStatusPolling();

        break;

      case Event.actionCallDecline:
        final callIdStr = event?.body['id']?.toString();
        final callerIdStr = event?.body['extra']?['callerId']?.toString();
        final callerNameStr = event?.body['extra']?['callerName']?.toString();
        final callDetails = CallDetails(
          callId: callIdStr != null ? int.tryParse(callIdStr) : null,
          callerId: callerIdStr != null ? int.tryParse(callerIdStr) : null,
          callerName: callerNameStr,
          callerProfilePic: null,
          callStatus: 'declined',
        );
        await callUtils.saveCallDetails(callDetails);

        // Stop background polling since call is declined
        _stopBackgroundStatusPolling();

        // End CallKit notification
        await FlutterCallkitIncoming.endCall(event?.body['id'] ?? '');
        await FlutterCallkitIncoming.endAllCalls();

        // Decline via API (unprotected endpoint - no auth needed)
        if (callIdStr != null && callIdStr.isNotEmpty) {
          final dio = Dio();
          try {
            await dio.post(
              '${Environment.baseUrl}/call/decline/$callIdStr',
            );
            debugPrint('[FCM BACKGROUND] Call declined via API: $callIdStr');
          } catch (e) {
            debugPrint('[FCM BACKGROUND] Error declining call via API: $e');
          }
        }

        break;

      case Event.actionCallEnded:
        await FlutterCallkitIncoming.endCall(event?.body['id'] ?? '');
        await FlutterCallkitIncoming.endAllCalls();
        // Stop background polling since call is ended
        _stopBackgroundStatusPolling();

        break;

      case Event.actionCallTimeout:
        final callIdStr = event?.body['id']?.toString();
        final callerIdStr = event?.body['extra']?['callerId']?.toString();
        final callerNameStr = event?.body['extra']?['callerName']?.toString();
        final callDetails = CallDetails(
          callId: callIdStr != null ? int.tryParse(callIdStr) : null,
          callerId: callerIdStr != null ? int.tryParse(callerIdStr) : null,
          callerName: callerNameStr,
          callerProfilePic: null,
          callStatus: 'missed',
        );
        await callUtils.saveCallDetails(callDetails);

        // Stop background polling since call timed out
        _stopBackgroundStatusPolling();

        break;
      default:
        debugPrint('🔔 Unhandled CallKit event: ${event?.event}');
        break;
    }
  });

  // Parse notification data
  final data = message.data;
  final notificationType = data['type'] as String?;

  // Parse ws_message if present
  WSMessage? wsMessage;
  try {
    final wsMessageStr = data['ws_message'];
    if (wsMessageStr != null) {
      Map<String, dynamic> wsMessageJson;
      if (wsMessageStr is String) {
        wsMessageJson = jsonDecode(wsMessageStr);
      } else if (wsMessageStr is Map) {
        wsMessageJson = Map<String, dynamic>.from(wsMessageStr);
      } else {
        throw FormatException('Invalid ws_message format');
      }
      wsMessage = WSMessage.fromJson(wsMessageJson);
    }
  } catch (e) {
    debugPrint('[BACKGROUND] Error parsing ws_message: $e');
  }

  // Handle different notification types
  switch (notificationType) {
    case 'call':
      await _handleCallNotification(data, wsMessage);
      break;

    case 'ws-message':
      await _handleMessageNotificationBackground(
        data,
        message.notification,
        wsMessage,
        notifcations,
      );
      break;

    default:
      debugPrint('[BACKGROUND] Unhandled notification type: $notificationType');
  }
}

/// Handle call notifications in background
Future<void> _handleCallNotification(
  Map<String, dynamic> data,
  WSMessage? wsMessage,
) async {
  try {
    CallPayload? callPayload;

    // Extract call payload from ws_message if available
    if (wsMessage != null) {
      callPayload = wsMessage.callPayload;
    }

    // Fallback to direct data extraction for backward compatibility
    final callId =
        callPayload?.callId?.toString() ??
        data['callId']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Determine call event type from ws_message
    final wsType = wsMessage?.type;
    if (wsType == WSMessageType.callTerminate) {
      await _handleCallEnd(callId, callPayload, data);
      return;
    }

    // Handle incoming call (call:ringing, call:init, etc.)
    if (wsType == WSMessageType.callRinging ||
        wsType == WSMessageType.callInit ||
        callPayload != null) {
      await _handleIncomingCall(callId, callPayload, data);
    }
  } catch (e) {
    debugPrint('[BACKGROUND] Error handling call notification: $e');
  }
}

/// Handle incoming call notification
Future<void> _handleIncomingCall(
  String callId,
  CallPayload? callPayload,
  Map<String, dynamic> data,
) async {
  try {
    // Extract caller info from payload or data
    final callerName =
        callPayload?.callerName ?? data['callerName']?.toString() ?? 'Unknown';
    final callerProfilePic =
        callPayload?.callerPfp ?? data['callerProfilePic']?.toString() ?? '';
    final callerPhone =
        callPayload?.callerId.toString() ??
        data['callerPhone']?.toString() ??
        'Unknown';

    final CallKitParams params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'amigo',
      avatar: callerProfilePic,
      handle: callerPhone,
      type: 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{
        'callerId': callPayload?.callerId.toString(),
        'callerName': callerName,
        'callerProfilePic': callerProfilePic,
        ...data,
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#06bd98',
        backgroundUrl: 'assets/images/call_bg_dark.png',
        actionColor: '#36b554',
        textColor: '#ffffff',
        isShowFullLockedScreen: true,
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    // Save call details in SharedPreferences so they're available for accept/decline
    final callIdInt = int.tryParse(callId);
    final callerIdInt = callPayload?.callerId;
    final callUtils = CallUtils();
    final callDetails = CallDetails(
      callId: callIdInt,
      callerId: callerIdInt,
      callerName: callerName,
      callerProfilePic: callerProfilePic.isNotEmpty ? callerProfilePic : null,
      callStatus: 'ringing',
    );
    await callUtils.saveCallDetails(callDetails);

    await FlutterCallkitIncoming.showCallkitIncoming(params);

    // Start polling for call status after showing CallKit notification
    if (callIdInt != null) {
      _startBackgroundStatusPolling(callIdInt);
    }
  } catch (e) {
    debugPrint('[BACKGROUND] Error showing CallKit notification: $e');
  }
}

/// Handle call end notification
Future<void> _handleCallEnd(
  String callId,
  CallPayload? callPayload,
  Map<String, dynamic> data,
) async {
  // Stop background polling immediately since call is ended via FCM
  _stopBackgroundStatusPolling();

  // Immediately dismiss CallKit UI
  try {
    if (callId.isNotEmpty) {
      await FlutterCallkitIncoming.endCall(callId);
    }
    await FlutterCallkitIncoming.endAllCalls();
  } catch (e) {
    debugPrint('[BACKGROUND] Error ending CallKit: $e');
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e2) {
      debugPrint('[BACKGROUND] Error calling endAllCalls: $e2');
    }
  }

  // Update call details in SharedPreferences to mark call as ended
  if (callId.isNotEmpty) {
    try {
      final callUtils = CallUtils();
      final callIdInt = int.tryParse(callId);
      if (callIdInt != null) {
        final existingCallDetails = await callUtils.getCallDetails();
        final updatedCallDetails =
            existingCallDetails?.copyWith(
              callId: callIdInt,
              callStatus: 'ended',
            ) ??
            CallDetails(callId: callIdInt, callStatus: 'ended');
        await callUtils.saveCallDetails(updatedCallDetails);
      }
    } catch (e) {
      debugPrint('[BACKGROUND] Error updating call details: $e');
    }
  }

  // Show missed call notification
  final callerName =
      callPayload?.callerName ?? data['callerName']?.toString() ?? 'Unknown';
  final notifcations = NotificationService();
  await notifcations.showMessageNotification(
    title: 'Missed Call',
    body: 'You missed a call from $callerName',
    // data: {'type': 'missed_call', 'callId': callId},
  );
}

/// Handle message notifications in background
Future<void> _handleMessageNotificationBackground(
  Map<String, dynamic> data,
  RemoteNotification? notification,
  WSMessage? wsMessage,
  NotificationService notificationService,
) async {
  try {
    if (wsMessage == null) return;

    // Handle different message types
    switch (wsMessage.type) {
      case WSMessageType.messageNew:
        final chatPayload = wsMessage.chatMessagePayload;
        if (chatPayload != null) {
          final msgBody = chatPayload.body ??
              ((chatPayload.msgType != MessageType.text)
                  ? chatPayload.msgType.toString()
                  : 'New message');

          // Show notification (MessagingStyle handled inside)
          await notificationService.showMessageNotification(
            title: chatPayload.senderName ?? 'New Message',
            body: msgBody.trim(),
            chatPayload: chatPayload,
          );

          // Store message in local DB
          await _storeMessageFromPayloadBackground(chatPayload);
        }
        break;

      case WSMessageType.messageDelete:
        final deletePayload = wsMessage.deleteMessagePayload;
        if (deletePayload != null) {
          await _handleMessageDeleteBackground(deletePayload);
        }
        break;

      default:
        debugPrint('[BACKGROUND] Unhandled ws-message type: ${wsMessage.type}');
    }
  } catch (e) {
    debugPrint('[BACKGROUND] Error handling message notification: $e');
  }
}

/// Handle message delete in background
Future<void> _handleMessageDeleteBackground(
  DeleteMessagePayload payload,
) async {
  try {
    final conversationId = payload.convId;
    final deletedMessageIds = payload.messageIds;

    if (deletedMessageIds.isEmpty) {
      debugPrint('[BACKGROUND] No message IDs to delete');
      return;
    }

    // Get current user ID to check which messages were unread
    final currentUser = await UserUtils().getUserDetails();
    if (currentUser == null) {
      debugPrint('[BACKGROUND] Cannot handle message delete: no current user');
      return;
    }
    final currentUserId = currentUser.id;

    // Get messages before deletion to check if they were unread
    final messageRepo = MessageRepository();
    final messagesToDelete = await messageRepo.getMessagesByIds(
      deletedMessageIds,
    );

    if (messagesToDelete.isEmpty) {
      debugPrint(
        '[BACKGROUND] Messages not found in local database, may have been already deleted',
      );
      return;
    }

    // Count unread messages (messages not sent by current user and not read by current user)
    final messageStatusRepo = MessageStatusRepository();
    int unreadCountToDecrement = 0;
    for (final message in messagesToDelete) {
      // Only count messages sent by others (not by current user)
      if (message.senderId != currentUserId) {
        // Check if message was unread
        final isRead = await messageStatusRepo.isReadByUser(
          message.id,
          currentUserId,
        );
        if (!isRead) {
          unreadCountToDecrement++;
        }
      }
    }

    // Delete messages from local DB
    await messageRepo.permanentlyDeleteMessages(deletedMessageIds);

    // Get conversation to update unread count
    final conversationRepo = ConversationRepository();
    final conversation = await conversationRepo.getConversationById(
      conversationId,
    );

    if (conversation != null) {
      // Get the new last message after deletion
      final lastMessage = await messageRepo.getLastMessage(conversationId);

      // Decrement unread count if unread messages were deleted
      final currentUnreadCount = conversation.unreadCount ?? 0;
      final newUnreadCount = currentUnreadCount > unreadCountToDecrement
          ? currentUnreadCount - unreadCountToDecrement
          : 0;

      // Update last message and unread count in database
      if (lastMessage != null) {
        await conversationRepo.updateLastMessage(
          conversationId,
          lastMessage.id,
        );
      }

      await conversationRepo.updateUnreadCount(conversationId, newUnreadCount);

      debugPrint(
        '✅ [BACKGROUND] Deleted ${deletedMessageIds.length} messages from conversation $conversationId, decremented unread count by $unreadCountToDecrement (new count: $newUnreadCount)',
      );
    } else {
      debugPrint(
        '⚠️ [BACKGROUND] Conversation $conversationId not found in database',
      );
    }
  } catch (e) {
    debugPrint('[BACKGROUND] Error handling message delete: $e');
  }
}

/// Fetch call status from unprotected endpoint in background
Future<Map<String, dynamic>?> _fetchBackgroundCallStatus(int callId) async {
  try {
    final dio = Dio();
    final response = await dio.get(
      '${Environment.baseUrl}/call/status/$callId',
    );

    if (response.statusCode == 200) {
      return response.data;
    } else {
      debugPrint(
        '[BACKGROUND] Failed to fetch call status: ${response.statusCode}',
      );
      return null;
    }
  } catch (e) {
    debugPrint('[BACKGROUND] Error fetching call status: $e');
    return null;
  }
}

/// Start polling for call status in background as fallback
void _startBackgroundStatusPolling(int callId) {
  if (_backgroundPollingTimer != null) {
    _backgroundPollingTimer?.cancel();
  }

  _backgroundPollingCallId = callId;

  int pollCount = 0;
  const maxPolls = 15; // 30 seconds / 2 seconds = 15 polls

  _backgroundPollingTimer = Timer.periodic(const Duration(seconds: 2), (
    timer,
  ) async {
    if (_backgroundPollingCallId == null) {
      timer.cancel();
      return;
    }

    pollCount++;

    // Stop polling after 30 seconds (15 polls)
    if (pollCount > maxPolls) {
      timer.cancel();
      _backgroundPollingTimer = null;
      _backgroundPollingCallId = null;
      return;
    }

    final statusResponse = await _fetchBackgroundCallStatus(callId);
    if (statusResponse != null && statusResponse['success'] == true) {
      final callData = statusResponse['data'];
      final status = callData['status'];

      if (status == 'declined' || status == 'ended') {
        timer.cancel();
        _backgroundPollingTimer = null;
        _backgroundPollingCallId = null;

        // End the CallKit notification
        await FlutterCallkitIncoming.endCall(callId.toString());
        await FlutterCallkitIncoming.endAllCalls();

        // Update shared preferences
        final callUtils = CallUtils();
        final existingCallDetails = await callUtils.getCallDetails();
        final updatedCallDetails =
            existingCallDetails?.copyWith(
              callId: callId,
              callStatus: status == 'declined'
                  ? 'declined'
                  : (status == 'ended'
                        ? 'ended'
                        : existingCallDetails.callStatus),
            ) ??
            CallDetails(
              callId: callId,
              callStatus: status == 'declined' ? 'declined' : 'ended',
            );
        await callUtils.saveCallDetails(updatedCallDetails);
      }
    }
  });
}

/// Stop background status polling
void _stopBackgroundStatusPolling() {
  if (_backgroundPollingTimer != null) {
    _backgroundPollingTimer?.cancel();
    _backgroundPollingTimer = null;
    _backgroundPollingCallId = null;
  }
}

/// Store message from ChatMessagePayload to local database (background handler)
Future<void> _storeMessageFromPayloadBackground(
  ChatMessagePayload chatPayload,
) async {
  try {
    // Convert to MessageModel and store in local DB
    final messageModel = MessageModel(
      id: chatPayload.id,
      conversationId: chatPayload.convId,
      senderId: chatPayload.senderId,
      senderName: chatPayload.senderName,
      type: chatPayload.msgType,
      body: chatPayload.body,
      status: MessageStatusType
          .delivered, // Messages from notifications are delivered
      attachments: chatPayload.attachments,
      metadata: chatPayload.metadata,
      isStarred: false,
      isReplied: chatPayload.replyToMessageId != null,
      isForwarded: false,
      isDeleted: false,
      sentAt: chatPayload.sentAt.toIso8601String(),
    );

    // Store in local database
    final messageRepo = MessageRepository();
    await messageRepo.insertMessage(messageModel);

    // Update conversation's last message and unread count
    final conversationRepo = ConversationRepository();
    final conversationId = chatPayload.convId;
    final messageId = chatPayload.id;

    // Get current conversation to check unread count
    final conversation = await conversationRepo.getConversationById(
      conversationId,
    );

    if (conversation != null) {
      // Increment unread count (messages from notifications are unread)
      final currentUnreadCount = conversation.unreadCount ?? 0;
      final newUnreadCount = currentUnreadCount + 1;

      // Update last message ID
      await conversationRepo.updateLastMessage(conversationId, messageId);

      // Update unread count
      await conversationRepo.updateUnreadCount(conversationId, newUnreadCount);

      debugPrint(
        '✅ [BACKGROUND] Updated conversation $conversationId: lastMessageId=$messageId, unreadCount=$newUnreadCount',
      );
    } else {
      debugPrint(
        '⚠️ [BACKGROUND] Conversation $conversationId not found in database',
      );
    }

    debugPrint(
      '✅ [BACKGROUND] Stored message from FCM notification: ${chatPayload.id}',
    );

    // Send delivery receipt to backend
    await sendDeliveryReceipt(chatPayload);
  } catch (e) {
    debugPrint(
      '❌ [BACKGROUND] Error storing message from FCM notification: $e',
    );
  }
}

/// Send delivery receipt to backend via API
/// This notifies the sender that the message was delivered via FCM
/// Uses API instead of WebSocket since app might be killed/not connected
Future<void> sendDeliveryReceipt(ChatMessagePayload message) async {
  try {
    // Get current user ID
    final currentUser = await UserUtils().getUserDetails();
    if (currentUser == null) {
      debugPrint(
        '[BACKGROUND] ⚠️ Cannot send delivery receipt: no current user',
      );
      return;
    }

    // Try to get ApiService instance
    ApiService? apiService;
    try {
      apiService = ApiService();
    } catch (e) {
      debugPrint(
        '[BACKGROUND] ⚠️ ApiService not initialized, skipping delivery receipt: $e',
      );
      return;
    }

    // Send delivery receipt via API
    // The backend will handle WebSocket broadcast to the sender
    await apiService.chat.markMessageDelivered(
      messageId: message.id,
      conversationId: message.convId,
    );

    debugPrint(
      '[BACKGROUND] 📬 Sent delivery receipt for message ${message.id} to sender ${message.senderId}',
    );
  } catch (e) {
    debugPrint('[BACKGROUND] ⚠️ Error sending delivery receipt: $e');
    // Don't throw - delivery receipt is best-effort
    // The sync mechanism will handle it if API fails
  }
}
