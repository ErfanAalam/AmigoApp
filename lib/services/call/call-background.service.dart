import 'dart:async';
import 'dart:convert';
import 'package:amigo/env.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
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

import '../../models/call.model.dart';
import '../../utils/call.utils.dart';
import '../../types/socket.types.dart';
import '../notification.service.dart';
import 'call.service.dart';

// Global variables for background polling
Timer? _backgroundPollingTimer;
int? _backgroundPollingCallId;

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final CallService callService = CallService();
  final NotificationService notifcations = NotificationService();
  await notifcations.initialize();

  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
    final callUtils = CallUtils();
    switch (event?.event) {
      case Event.actionCallAccept:
        // _callService.initialize();
        // _callService.acceptCall();

        final callIdStr = event?.body['id']?.toString();
        final callerIdStr = event?.body['extra']?['callerId']?.toString();
        final callDetails = CallDetails(
          callId: callIdStr != null ? int.tryParse(callIdStr) : null,
          callerId: callerIdStr != null ? int.tryParse(callerIdStr) : null,
          callerName: event?.body['extra']?['callerName']?.toString(),
          callerProfilePic: null,
          callStatus: 'answered',
        );
        await callUtils.saveCallDetails(callDetails);

        // Stop background polling since call is accepted
        _stopBackgroundStatusPolling();

        break;

      case Event.actionCallDecline:
        // _callService.initialize();
        // _callService..declineCall();

        final callIdStr = event?.body['id']?.toString();
        final callerIdStr = event?.body['extra']?['callerId']?.toString();
        final callDetails = CallDetails(
          callId: callIdStr != null ? int.tryParse(callIdStr) : null,
          callerId: callerIdStr != null ? int.tryParse(callerIdStr) : null,
          callerName: null,
          callerProfilePic: null,
          callStatus: 'declined',
        );
        await callUtils.saveCallDetails(callDetails);

        // Stop background polling since call is declined
        _stopBackgroundStatusPolling();
        callService.endCall();

         await FlutterCallkitIncoming.endCall(event?.body['id'] ?? '');
          await FlutterCallkitIncoming.endAllCalls();

        // Initialize Dio and make API request
        final dio = Dio();
        try {
          await dio.post(
            '${Environment.baseUrl}/call/decline/${event?.body['id'] ?? ''}',
          );
        } catch (e) {
          debugPrint('Error declining call via API');
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
        final callDetails = CallDetails(
          callId: callIdStr != null ? int.tryParse(callIdStr) : null,
          callerId: callerIdStr != null ? int.tryParse(callerIdStr) : null,
          callerName: null,
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

  // Handle call notifications in background
  final data = message.data;

  if (data['type'] == 'call') {
    // Use CallKit for background call notifications
    await _handleBackgroundCallNotification(data);
  } else if (message.data['type'] == 'call_end') {
    // Ensure callId is a string (matching the format used when showing CallKit)
    final callId = message.data['callId']?.toString() ?? '';


    // Stop background polling immediately since call is ended via FCM
    _stopBackgroundStatusPolling();

    // Immediately dismiss CallKit UI - try both methods to ensure it works
    try {
      // First, try to end the specific call by ID
      if (callId.isNotEmpty) {
        await FlutterCallkitIncoming.endCall(callId);
      }
      // Always call endAllCalls as a fallback to ensure all calls are dismissed
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[BACKGROUND] Error ending CallKit: $e');
      // Try again with endAllCalls only
      try {
        await FlutterCallkitIncoming.endAllCalls();
      } catch (e2) {
        debugPrint('[BACKGROUND] Error calling endAllCalls: $e2');
      }
    }

    // 3. Update call details in SharedPreferences to mark call as ended
    if (callId.isNotEmpty) {
      try {
        final callUtils = CallUtils();
        final callIdInt = int.tryParse(callId);
        if (callIdInt != null) {
          final existingCallDetails = await callUtils.getCallDetails();
          final updatedCallDetails = existingCallDetails?.copyWith(
            callId: callIdInt,
            callStatus: 'ended',
          ) ?? CallDetails(
            callId: callIdInt,
            callStatus: 'ended',
          );
          await callUtils.saveCallDetails(updatedCallDetails);
        }
      } catch (e) {
        debugPrint('[BACKGROUND] Error updating call details: $e');
      }
    }

    // 4. Optionally show missed call notification
    final callerName = message.data['callerName']?.toString() ?? 'Unknown';
    await notifcations.showMessageNotification(
      title: 'Missed Call',
      body: 'You missed a call from $callerName',
      data: {'type': 'missed_call', 'callId': callId},
    );
  } else if (data['type'] == 'message') {
    // Handle regular message notifications in background
    // Store message in local DB if chat_message is present
    await _storeMessageFromNotificationBackground(data);

    // Show notification
    await notifcations.showMessageNotification(
      title: message.notification?.title ?? 'New Message',
      body: message.notification?.body ?? 'You have a new message',
      data: data,
    );
  } else {
    debugPrint('📨 Non-call message received in background: ${data['type']}');
  }
}

/// Handle background call notifications using CallKit
Future<void> _handleBackgroundCallNotification(
  Map<String, dynamic> data,
) async {
  try {
    final callId =
        data['callId']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final CallKitParams params = CallKitParams(
      id: callId,
      nameCaller: data['callerName'] ?? 'Unknown',
      appName: 'amigo',
      avatar: data['callerProfilePic'] ?? '',
      handle: data['callerPhone'] ?? 'Unknown',
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
      extra: data,
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

    await FlutterCallkitIncoming.showCallkitIncoming(params);

    // Start polling for call status after showing CallKit notification
    _startBackgroundStatusPolling(int.parse(callId));
  } catch (e) {
    debugPrint('❌ Error showing CallKit notification in background: $e');
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
        final updatedCallDetails = existingCallDetails?.copyWith(
          callId: callId,
          callStatus: status == 'declined' ? 'declined' : (status == 'ended' ? 'ended' : existingCallDetails.callStatus),
        ) ?? CallDetails(
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

/// Store message from FCM notification data to local database (background handler)
Future<void> _storeMessageFromNotificationBackground(
  Map<String, dynamic> data,
) async {
  try {
    // Check if chat_message is present in the notification data
    final chatMessageStr = data['chat_message'];
    if (chatMessageStr == null) {
      debugPrint('ℹ️ No chat_message in notification data, skipping storage');
      return;
    }

    // Parse the chat_message JSON string
    Map<String, dynamic> chatMessageJson;
    if (chatMessageStr is String) {
      chatMessageJson = jsonDecode(chatMessageStr);
    } else if (chatMessageStr is Map) {
      chatMessageJson = Map<String, dynamic>.from(chatMessageStr);
    } else {
      debugPrint('❌ Invalid chat_message format in notification');
      return;
    }

    // Convert to ChatMessagePayload
    final chatMessagePayload = ChatMessagePayload.fromJson(chatMessageJson);

    // Convert to MessageModel and store in local DB
    final messageModel = MessageModel(
      optimisticId: chatMessagePayload.optimisticId,
      canonicalId: chatMessagePayload.canonicalId,
      conversationId: chatMessagePayload.convId,
      senderId: chatMessagePayload.senderId,
      senderName: chatMessagePayload.senderName,
      type: chatMessagePayload.msgType,
      body: chatMessagePayload.body,
      status: MessageStatusType
          .delivered, // Messages from notifications are delivered
      attachments: chatMessagePayload.attachments,
      metadata: chatMessagePayload.metadata,
      isStarred: false,
      isReplied: chatMessagePayload.replyToMessageId != null,
      isForwarded: false,
      isDeleted: false,
      sentAt: chatMessagePayload.sentAt.toIso8601String(),
    );

    // Store in local database
    final messageRepo = MessageRepository();
    await messageRepo.insertMessage(messageModel);

    // Update conversation's last message and unread count
    final conversationRepo = ConversationRepository();
    final conversationId = chatMessagePayload.convId;
    // Use canonicalId if available, otherwise use optimisticId (which is always present)
    final messageId =
        chatMessagePayload.canonicalId ?? chatMessagePayload.optimisticId;

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
      '✅ [BACKGROUND] Stored message from FCM notification: ${chatMessagePayload.canonicalId ?? chatMessagePayload.optimisticId}',
    );
  } catch (e) {
    debugPrint(
      '❌ [BACKGROUND] Error storing message from FCM notification: $e',
    );
  }
}
