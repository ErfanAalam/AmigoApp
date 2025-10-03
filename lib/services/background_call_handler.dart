import 'dart:async';
import 'package:amigo/api/api_service.dart';
import 'package:amigo/services/call_service.dart';
import 'package:amigo/env.dart';
import 'package:amigo/services/notification_service.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global variables for background polling
Timer? _backgroundPollingTimer;
int? _backgroundPollingCallId;

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final CallService _callService = CallService();
  final NotificationService _notifcations = NotificationService();
  await _notifcations.initialize();

  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
    print('🔔 CallKit event received: ${event?.event}');
    print('🔔 Full event data: $event');
    print('🔔 Event type: ${event?.event.runtimeType}');

    print(
      "--------------------------------------------------------------------------------",
    );
    print(
      "event -> ${event?.body['id']} :: ${event?.body['extra']['callerId']}",
    );
    print(
      "--------------------------------------------------------------------------------",
    );
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

        print(
          "--------------------------------------------------------------------------------",
        );
        print(
          "--------------------------------------------------------------------------------",
        );
        print("prefs updated for accepted call");
        print(
          "--------------------------------------------------------------------------------",
        );
        print(
          "--------------------------------------------------------------------------------",
        );

        // Navigator.popUntil(
        //   NavigationHelper.navigator!.context,
        //   (route) => route.isFirst,
        // );

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
          final response = await dio.post(
            '${Environment.baseUrl}/call/decline/${event?.body['id'] ?? ''}',
          );
          print('API request successful: ${response.statusCode}');
        } catch (e) {
          print('API request failed: $e');
        }

        print(
          "--------------------------------------------------------------------------------",
        );
        print(
          "--------------------------------------------------------------------------------",
        );
        print("prefs updated for declined call");
        print(
          "--------------------------------------------------------------------------------",
        );
        print(
          "--------------------------------------------------------------------------------",
        );

        break;
      case Event.actionCallEnded:
        print(
          "--------------------------------------------------------------------------------",
        );
        print("call ended from callkit");
        print(
          "--------------------------------------------------------------------------------",
        );

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
        print('🔔 Unhandled CallKit event: ${event?.event}');
        print('🔔 Event data: $event');
        break;
    }
  });
  print('📨 Background message received: ${message.messageId}');
  print('📨 Message data: ${message.data}');

  print(
    '--------------------------------------------------------------------------------',
  );
  print(
    '--------------------------------------------------------------------------------',
  );
  print('🔔 Background message received with data: ${message.data}');
  print(
    '--------------------------------------------------------------------------------',
  );
  print(
    '--------------------------------------------------------------------------------',
  );

  // Handle call notifications in background
  final data = message.data;
  if (data['type'] == 'call') {
    print('📞 Background call notification received - showing CallKit');

    // Use CallKit for background call notifications
    await _handleBackgroundCallNotification(data);
  } else if (message.data['type'] == 'call_end') {
    final callId = message.data['callId'];

    print(
      '--------------------------------------------------------------------------------',
    );
    print(
      '--------------------------------------------------------------------------------',
    );
    print('📞 Call ended notification received for callId: $callId');
    print(
      '--------------------------------------------------------------------------------',
    );
    print(
      '--------------------------------------------------------------------------------',
    );

    // Stop background polling since call is ended via FCM
    _stopBackgroundStatusPolling();

    // 1. End call notification (system UI)
    await FlutterCallkitIncoming.endCall(callId);
    await FlutterCallkitIncoming.endAllCalls();

    // 2. Optionally show missed call notification
    await _notifcations.showMessageNotification(
      title: 'Missed Call',
      body: 'You missed a call from ${message.data['callerName']}',
      data: {'type': 'missed_call', 'callId': callId},
    );
  } else {
    print('📨 Non-call message received in background: ${data['type']}');
  }
}

/// Handle background call notifications using CallKit
Future<void> _handleBackgroundCallNotification(
  Map<String, dynamic> data,
) async {
  try {
    print('🔧 Creating CallKit notification with data: $data');

    final callId =
        data['callId']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final from = data['callerId'] ?? data['from'];
    final payload = data;

    print(
      '🔧 CallKit params - callId: $callId, from: $from, callerName: ${payload['callerName']}',
    );

    final CallKitParams params = CallKitParams(
      id: callId,
      nameCaller: payload['callerName'] ?? 'Unknown',
      appName: 'amigo',
      avatar: payload['callerProfilePic'] ?? '',
      handle: payload['callerPhone'] ?? 'Unknown',
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
      extra: payload,
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
    // await FlutterCallkitIncoming.showMissCallNotification(params);
    print('📞 CallKit notification shown in background for call: $callId');

    // Start polling for call status after showing CallKit notification
    _startBackgroundStatusPolling(int.parse(callId));
  } catch (e) {
    print('❌ Error showing CallKit notification in background: $e');
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
      print('[BACKGROUND] Failed to fetch call status: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('[BACKGROUND] Error fetching call status: $e');
    return null;
  }
}

/// Start polling for call status in background as fallback
void _startBackgroundStatusPolling(int callId) {
  if (_backgroundPollingTimer != null) {
    _backgroundPollingTimer?.cancel();
  }

  _backgroundPollingCallId = callId;
  print('[BACKGROUND] Starting status polling for call: $callId');

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
      print(
        '[BACKGROUND] Status polling timeout after 30 seconds, stopping...',
      );
      timer.cancel();
      _backgroundPollingTimer = null;
      _backgroundPollingCallId = null;
      return;
    }

    final statusResponse = await _fetchBackgroundCallStatus(callId);
    if (statusResponse != null && statusResponse['success'] == true) {
      final callData = statusResponse['data'];
      final status = callData['status'];

      print(
        '[BACKGROUND] Polling - Call status: $status (poll $pollCount/$maxPolls)',
      );

      if (status == 'declined' || status == 'ended') {
        print(
          '[BACKGROUND] Call $status detected via polling, ending CallKit...',
        );
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

        print('[BACKGROUND] CallKit notification ended due to $status status');
      }
    }
  });
}

/// Stop background status polling
void _stopBackgroundStatusPolling() {
  if (_backgroundPollingTimer != null) {
    print('[BACKGROUND] Stopping status polling');
    _backgroundPollingTimer?.cancel();
    _backgroundPollingTimer = null;
    _backgroundPollingCallId = null;
  }
}
