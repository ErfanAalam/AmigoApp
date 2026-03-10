import 'dart:async';
import 'dart:convert';
import 'package:amigo/env.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message-status.repo.dart';
import 'package:amigo/models/message.model.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
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
import '../../api/core/api_result.dart';
import '../../services/auth/auth.service.dart';
import '../../services/cookies.service.dart';
import '../../models/call.model.dart';
import '../../utils/call.utils.dart';
import '../../types/socket.types.dart';
import '../../utils/serialization.utils.dart';
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
        final callerPfpStr = event?.body['extra']?['callerProfilePic']
            ?.toString();
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
            await dio.post('${Environment.baseUrl}/call/decline/$callIdStr');
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

  // Parse ws_messages (batched) or ws_message (single, used for calls)
  List<WSMessage> wsMessages = [];
  WSMessage? wsMessage; // kept for call notifications which still use single
  try {
    final wsMessagesStr = data['ws_messages'];
    final wsMessageStr = data['ws_message'];

    if (wsMessagesStr != null) {
      // Batched path: array of ws_messages
      final List<dynamic> arr = jsonDecode(wsMessagesStr as String);
      for (final item in arr) {
        wsMessages.add(WSMessage.fromJson(Map<String, dynamic>.from(item as Map)));
      }
    } else if (wsMessageStr != null) {
      // Single path: still used for call notifications
      Map<String, dynamic> wsMessageJson;
      if (wsMessageStr is String) {
        wsMessageJson = jsonDecode(wsMessageStr);
      } else if (wsMessageStr is Map) {
        wsMessageJson = Map<String, dynamic>.from(wsMessageStr);
      } else {
        throw FormatException('Invalid ws_message format');
      }
      wsMessage = WSMessage.fromJson(wsMessageJson);
      wsMessages = [wsMessage];
    }
  } catch (e) {
    debugPrint('[BACKGROUND] Error parsing ws_message(s): $e');
  }

  // Handle different notification types
  switch (notificationType) {
    case 'call':
      // Calls still use single ws_message
      await _handleCallNotification(data, wsMessage);
      break;

    case 'ws-message':
      await _handleMessageNotificationBatchBackground(
        data,
        message.notification,
        wsMessages,
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

/// Handle a batch of ws-messages in background
Future<void> _handleMessageNotificationBatchBackground(
  Map<String, dynamic> data,
  RemoteNotification? notification,
  List<WSMessage> wsMessages,
  NotificationService notificationService,
) async {
  if (wsMessages.isEmpty) return;

  // Collect IDs for batch delivery receipt
  final List<Map<String, dynamic>> deliveries = [];
  final messageRepo = MessageRepository();

  for (final wsMessage in wsMessages) {
    try {
      switch (wsMessage.type) {
        case WSMessageType.messageNew:
          final chatPayload = wsMessage.chatMessagePayload;
          if (chatPayload != null) {
            final alreadyExists = await messageRepo.messageExists(chatPayload.id);

            if (!alreadyExists) {
              final msgBody =
                  chatPayload.body ??
                  ((chatPayload.msgType != MessageType.text)
                      ? chatPayload.msgType.toString()
                      : 'New message');

              await notificationService.showMessageNotification(
                title: chatPayload.senderName ?? 'New Message',
                body: msgBody.trim(),
                chatPayload: chatPayload,
              );
            }

            await _storeMessageFromPayloadBackground(chatPayload, sendReceipt: false);

            deliveries.add({
              'message_id': chatPayload.id.toString(),
              'conversation_id': chatPayload.convId,
            });
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
      debugPrint('[BACKGROUND] Error processing ws-message ${wsMessage.type}: $e');
    }
  }

  // Send all delivery receipts in one batch request
  if (deliveries.isNotEmpty) {
    await sendDeliveryReceiptBatch(deliveries);
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

/// Store message from ChatMessagePayload to local database (background handler).
/// Pass [sendReceipt: false] when receipts are sent in batch after the loop.
Future<void> _storeMessageFromPayloadBackground(
  ChatMessagePayload chatPayload, {
  bool sendReceipt = true,
}) async {
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

    // Send delivery receipt (skip when caller handles batch receipts)
    if (sendReceipt) {
      await sendDeliveryReceipt(chatPayload);
    }
  } catch (e) {
    debugPrint(
      '❌ [BACKGROUND] Error storing message from FCM notification: $e',
    );
  }
}

Map<String, dynamic> _parseResponseData(dynamic data) {
  Map<String, dynamic> parsed;

  if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        parsed = decoded;
      } else {
        // If decoded data is not a Map (e.g., List, primitive), wrap it
        // Convert string IDs to int before wrapping
        final convertedData = convertStringIdsToInt(decoded);
        return {
          'success': true,
          'code': 200,
          'message': 'Success',
          'data': convertedData,
        };
      }
    } catch (_) {
      // If parsing fails, wrap in ResultType format
      return {
        'success': false,
        'code': 500,
        'message': 'Failed to parse response',
        'error': data,
      };
    }
  } else if (data is Map<String, dynamic>) {
    parsed = data;
  } else {
    // If data is not a Map (e.g., List, primitive), wrap it in ResultType format
    // This preserves the actual data structure instead of discarding it
    // Convert string IDs to int before wrapping
    final convertedData = convertStringIdsToInt(data);
    return {
      'success': true,
      'code': 200,
      'message': 'Success',
      'data': convertedData,
    };
  }

  // Ensure it has the ResultType structure
  if (!parsed.containsKey('success')) {
    // If backend didn't return ResultType format, wrap it
    final wrapped = {
      'success': true,
      'code': 200,
      'message': parsed['message'] ?? 'Success',
      'data': parsed,
    };
    // Convert string IDs to int before returning
    return convertStringIdsToInt(wrapped);
  }

  // Convert string IDs (from BigInt) to int before returning
  return convertStringIdsToInt(parsed);
}

/// Send batch delivery receipts for multiple messages in one request.
Future<bool> sendDeliveryReceiptBatch(
  List<Map<String, dynamic>> messages,
) async {
  if (messages.isEmpty) return true;
  try {
    final cookieService = CookieService();
    await cookieService.init();

    final dio = Dio();
    dio.options.validateStatus = (status) => status != null;
    dio.interceptors.add(CookieManager(cookieService.cookieJar));

    final response = await dio.post(
      "${Environment.baseUrl}/message/delivered/batch",
      data: {'messages': messages},
    );

    final parsedData = _parseResponseData(response.data);
    final res = ApiResult<dynamic>.fromMap(parsedData);
    if (res.isSuccess) {
      debugPrint(
        '[BACKGROUND] 📬 Batch delivery receipt sent for ${messages.length} messages',
      );
      return true;
    }

    debugPrint(
      '[BACKGROUND] ⚠️ Batch delivery receipt failed (status ${response.statusCode})',
    );
    return false;
  } catch (e) {
    debugPrint('[BACKGROUND] ⚠️ Error sending batch delivery receipt: $e');
    return false;
  }
}

/// Send delivery receipt to backend via API (background isolate version).
/// Creates its own Dio instance with the cookie jar attached directly, so it
/// works correctly regardless of whether ApiClient has already been initialized.
Future<bool> sendDeliveryReceipt(ChatMessagePayload message) async {
  try {
    final cookieService = CookieService();
    await cookieService.init();

    final dio = Dio();
    dio.options.validateStatus = (status) => status != null;
    dio.interceptors.add(CookieManager(cookieService.cookieJar));

    final response = await dio.post(
      "${Environment.baseUrl}/message/delivered",
      data: {
        'message_id': message.id.toString(),
        'conversation_id': message.convId,
      },
    );

    final parsedData = _parseResponseData(response.data);
    final res = ApiResult<dynamic>.fromMap(parsedData);
    if (res.isSuccess) {
      debugPrint(
        '[BACKGROUND] 📬 Sent delivery receipt for message ${message.id}',
      );
      return true;
    }

    debugPrint(
      '[BACKGROUND] ⚠️ Delivery receipt failed (status ${response.statusCode})',
    );
    return false;
  } catch (e) {
    debugPrint('[BACKGROUND] ⚠️ Error sending delivery receipt: $e');
    return false;
  }
}
