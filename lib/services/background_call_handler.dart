import 'dart:async';
import 'package:amigo/env.dart';
import 'package:amigo/services/notification_service.dart';
import 'package:amigo/db/database_helper.dart';
import 'package:amigo/models/message_model.dart';
import 'package:amigo/db/repositories/messages_repository.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

// Global variables for background polling
Timer? _backgroundPollingTimer;
int? _backgroundPollingCallId;

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // final CallService _callService = CallService();
  final NotificationService notifcations = NotificationService();
  await notifcations.initialize();

  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
    final prefs = await SharedPreferences.getInstance();
    switch (event?.event) {
      case Event.actionCallAccept:
        // _callService.initialize();
        // _callService.acceptCall();

        prefs.setString('call_status', 'answered');
        prefs.setString('current_call_id', event?.body['id'] ?? '');
        prefs.setString(
          'current_caller_id',
          event?.body['extra']['callerId'] ?? '',
        );
        prefs.setString(
          'current_caller_name',
          event?.body['extra']['callerName'] ?? '',
        );

        // Stop background polling since call is accepted
        _stopBackgroundStatusPolling();

        break;

      case Event.actionCallDecline:
        // _callService.initialize();
        // _callService..declineCall();

        prefs.setString('call_status', 'declined');
        prefs.setString('current_call_id', event?.body['id'] ?? '');
        prefs.setString(
          'current_caller_id',
          event?.body['extra']['callerId'] ?? '',
        );

        // Stop background polling since call is declined
        _stopBackgroundStatusPolling();

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
        // Stop background polling since call is ended
        _stopBackgroundStatusPolling();

        break;

      case Event.actionCallTimeout:
        prefs.setString('call_status', 'missed');
        prefs.setString('current_call_id', event?.body['id'] ?? '');
        prefs.setString(
          'current_caller_id',
          event?.body['extra']['callerId'] ?? '',
        );

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
    final callId = message.data['callId'];

    // Stop background polling since call is ended via FCM
    _stopBackgroundStatusPolling();

    // 1. End call notification (system UI)
    await FlutterCallkitIncoming.endCall(callId);
    await FlutterCallkitIncoming.endAllCalls();

    // 2. Optionally show missed call notification
    await notifcations.showMessageNotification(
      title: 'Missed Call',
      body: 'You missed a call from ${message.data['callerName']}',
      data: {'type': 'missed_call', 'callId': callId},
    );
  } else if (data['type'] == 'message') {
    // Handle regular message notifications in background
    // await _handleBackgroundMessage(data);
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
        final prefs = await SharedPreferences.getInstance();
        if (status == 'declined') {
          prefs.setString('call_status', 'declined');
        } else if (status == 'ended') {
          prefs.setString('call_status', 'ended');
        }
        prefs.setString('current_call_id', callId.toString());
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

/// Handle background message notifications and store in local database
Future<void> _handleBackgroundMessage(Map<String, dynamic> data) async {
  try {
    debugPrint('📨 Processing background message: $data');

    // Parse the message data from FCM payload
    final messageData = _parseMessageFromFCM(data);
    if (messageData == null) {
      debugPrint('❌ Failed to parse message data from FCM payload');
      return;
    }

    // Initialize database helper and messages repository
    final dbHelper = DatabaseHelper.instance;
    final messagesRepo = MessagesRepository();

    // Ensure database is initialized
    await dbHelper.database;

    // Store the message in local SQLite database
    await messagesRepo.insertOrUpdateMessage(messageData);

    debugPrint('✅ Successfully stored background message in local database');
    debugPrint('   Message ID: ${messageData.id}');
    debugPrint('   Conversation ID: ${messageData.conversationId}');
    debugPrint('   Sender: ${messageData.senderName}');
    debugPrint('   Body: ${messageData.body}');
  } catch (e) {
    debugPrint('❌ Error handling background message: $e');
    debugPrint('   Stack trace: ${StackTrace.current}');
  }
}

/// Parse message data from FCM payload
MessageModel? _parseMessageFromFCM(Map<String, dynamic> data) {
  try {
    // Extract message data from FCM payload
    final messageId = int.tryParse(data['messageId']?.toString() ?? '0') ?? 0;
    final conversationId =
        int.tryParse(data['conversationId']?.toString() ?? '0') ?? 0;
    final senderId = int.tryParse(data['senderId']?.toString() ?? '0') ?? 0;
    final senderName = data['senderName']?.toString() ?? '';
    final senderProfilePic = data['senderProfilePic']?.toString();
    final body = data['body']?.toString() ?? '';
    final type = data['messageType']?.toString() ?? 'text';
    final createdAt =
        data['createdAt']?.toString() ?? DateTime.now().toIso8601String();
    final editedAt = data['editedAt']?.toString();

    // Parse attachments if present
    Map<String, dynamic>? attachments;
    if (data['attachments'] != null) {
      try {
        attachments = Map<String, dynamic>.from(data['attachments'] as Map);
      } catch (e) {
        debugPrint('⚠️ Failed to parse attachments: $e');
      }
    }

    // Parse metadata if present
    Map<String, dynamic>? metadata;
    if (data['metadata'] != null) {
      try {
        metadata = Map<String, dynamic>.from(data['metadata'] as Map);
      } catch (e) {
        debugPrint('⚠️ Failed to parse metadata: $e');
      }
    }

    // Parse reply data if present
    MessageModel? replyToMessage;
    int? replyToMessageId;
    if (data['replyToMessageId'] != null) {
      replyToMessageId = int.tryParse(
        data['replyToMessageId']?.toString() ?? '0',
      );
    }

    // Create MessageModel
    return MessageModel(
      id: messageId,
      body: body,
      type: type,
      senderId: senderId,
      conversationId: conversationId,
      createdAt: createdAt,
      editedAt: editedAt,
      metadata: metadata,
      attachments: attachments,
      deleted: false,
      senderName: senderName,
      senderProfilePic: senderProfilePic,
      replyToMessage: replyToMessage,
      replyToMessageId: replyToMessageId,
      isDelivered: true, // Messages received via FCM are considered delivered
    );
  } catch (e) {
    debugPrint('❌ Error parsing message from FCM: $e');
    return null;
  }
}
