import 'dart:async';
import 'dart:convert';
import 'package:amigo/env.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message-status.repo.dart';
import 'package:amigo/models/message.model.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// FlutterCallkitIncoming - commented out, replaced by native call screen
// import 'package:flutter_callkit_incoming/entities/android_params.dart';
// import 'package:flutter_callkit_incoming/entities/call_event.dart';
// import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
// import 'package:flutter_callkit_incoming/entities/ios_params.dart';
// import 'package:flutter_callkit_incoming/entities/notification_params.dart';
// import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../call/native_call_screen.service.dart';
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

  // FlutterCallkitIncoming event listener - commented out, replaced by native call screen
  // Native call screen handles accept/decline/end via AmigoCallPlugin EventChannel
  // FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
  //   ...
  // });

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
        wsMessages.add(
          WSMessage.fromJson(Map<String, dynamic>.from(item as Map)),
        );
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
      // Calls are handled entirely by native AmigoMessagingService.
      // Do NOT process here — the native MethodChannel is unavailable in
      // the background isolate and causes MissingPluginException.
      debugPrint('[BACKGROUND] Skipping call notification — handled natively');
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
  debugPrint(
    '[BACKGROUND] Handling call notification with data: $data and wsMessage: ${wsMessage?.type}',
  );
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
      // await _handleCallEnd(callId, callPayload, data);
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

    final callIdInt = int.tryParse(callId);
    final callUtils = CallUtils();

    // Dedup: if this callId is already 'ringing' in SharedPreferences, skip
    final existing = await callUtils.getCallDetails();
    if (callIdInt != null &&
        existing?.callId == callIdInt &&
        existing?.callStatus == 'ringing') {
      debugPrint('[BACKGROUND] Duplicate FCM for callId=$callIdInt, skipping');
      return;
    }

    final callerIdInt = callPayload?.callerId;
    final callDetails = CallDetails(
      callId: callIdInt,
      callerId: callerIdInt,
      callerName: callerName,
      callerProfilePic: callerProfilePic.isNotEmpty ? callerProfilePic : null,
      callStatus: 'ringing',
    );
    await callUtils.saveCallDetails(callDetails);

    // Show native incoming call screen (replaces FlutterCallkitIncoming)
    try {
      await NativeCallScreen.showIncomingCall(
        callId: callIdInt ?? 0,
        callerName: callerName,
        callerPhoto: callerProfilePic.isNotEmpty ? callerProfilePic : null,
      );
    } catch (e) {
      debugPrint('[BACKGROUND] Error showing native call screen: $e');
    }

    // FlutterCallkitIncoming - commented out, replaced by native call screen
    // await FlutterCallkitIncoming.showCallkitIncoming(params);

    // Start polling for call status after showing notification
    if (callIdInt != null) {
      // _startBackgroundStatusPolling(callIdInt);
    }
  } catch (e) {
    debugPrint('[BACKGROUND] Error showing call notification: $e');
  }
}

/// Handle call end notification
// Future<void> _handleCallEnd(
//   String callId,
//   CallPayload? callPayload,
//   Map<String, dynamic> data,
// ) async {
//   // Stop background polling immediately since call is ended via FCM
//   _stopBackgroundStatusPolling();
//
//   // Immediately dismiss CallKit UI
//   try {
//     if (callId.isNotEmpty) {
//       await FlutterCallkitIncoming.endCall(callId);
//     }
//     await FlutterCallkitIncoming.endAllCalls();
//   } catch (e) {
//     debugPrint('[BACKGROUND] Error ending CallKit: $e');
//     try {
//       await FlutterCallkitIncoming.endAllCalls();
//     } catch (e2) {
//       debugPrint('[BACKGROUND] Error calling endAllCalls: $e2');
//     }
//   }
//
//   // Update call details in SharedPreferences to mark call as ended
//   if (callId.isNotEmpty) {
//     try {
//       final callUtils = CallUtils();
//       final callIdInt = int.tryParse(callId);
//       if (callIdInt != null) {
//         final existingCallDetails = await callUtils.getCallDetails();
//         final updatedCallDetails =
//             existingCallDetails?.copyWith(
//               callId: callIdInt,
//               callStatus: 'ended',
//             ) ??
//             CallDetails(callId: callIdInt, callStatus: 'ended');
//         await callUtils.saveCallDetails(updatedCallDetails);
//       }
//     } catch (e) {
//       debugPrint('[BACKGROUND] Error updating call details: $e');
//     }
//   }
//
//   // Show missed call notification
//   final callerName =
//       callPayload?.callerName ?? data['callerName']?.toString() ?? 'Unknown';
//   final notifcations = NotificationService();
//   await notifcations.showMessageNotification(
//     title: 'Missed Call',
//     body: 'You missed a call from $callerName',
//     // data: {'type': 'missed_call', 'callId': callId},
//   );
// }

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
            final alreadyExists = await messageRepo.messageExists(
              chatPayload.id,
            );

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

            await _storeMessageFromPayloadBackground(
              chatPayload,
              sendReceipt: false,
            );

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
          debugPrint(
            '[BACKGROUND] Unhandled ws-message type: ${wsMessage.type}',
          );
      }
    } catch (e) {
      debugPrint(
        '[BACKGROUND] Error processing ws-message ${wsMessage.type}: $e',
      );
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
// void _startBackgroundStatusPolling(int callId) {
//   if (_backgroundPollingTimer != null) {
//     _backgroundPollingTimer?.cancel();
//   }
//
//   _backgroundPollingCallId = callId;
//
//   int pollCount = 0;
//   const maxPolls = 15; // 30 seconds / 2 seconds = 15 polls
//
//   _backgroundPollingTimer = Timer.periodic(const Duration(seconds: 2), (
//     timer,
//   ) async {
//     if (_backgroundPollingCallId == null) {
//       timer.cancel();
//       return;
//     }
//
//     pollCount++;
//
//     // Stop polling after 30 seconds (15 polls)
//     if (pollCount > maxPolls) {
//       timer.cancel();
//       _backgroundPollingTimer = null;
//       _backgroundPollingCallId = null;
//       return;
//     }
//
//     final statusResponse = await _fetchBackgroundCallStatus(callId);
//     if (statusResponse != null && statusResponse['success'] == true) {
//       final callData = statusResponse['data'];
//       final status = callData['status'];
//
//       if (status == 'declined' || status == 'ended') {
//         timer.cancel();
//         _backgroundPollingTimer = null;
//         _backgroundPollingCallId = null;
//
//         // End the CallKit notification
//         await FlutterCallkitIncoming.endCall(callId.toString());
//         await FlutterCallkitIncoming.endAllCalls();
//
//         // Update shared preferences
//         final callUtils = CallUtils();
//         final existingCallDetails = await callUtils.getCallDetails();
//         final updatedCallDetails =
//             existingCallDetails?.copyWith(
//               callId: callId,
//               callStatus: status == 'declined'
//                   ? 'declined'
//                   : (status == 'ended'
//                         ? 'ended'
//                         : existingCallDetails.callStatus),
//             ) ??
//             CallDetails(
//               callId: callId,
//               callStatus: status == 'declined' ? 'declined' : 'ended',
//             );
//         await callUtils.saveCallDetails(updatedCallDetails);
//       }
//     }
//   });
// }

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
