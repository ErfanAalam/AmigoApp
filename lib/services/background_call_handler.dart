import 'dart:async';
import 'package:amigo/api/api_service.dart';
import 'package:amigo/services/call_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final CallService _callService = CallService();

  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
    print('🔔 CallKit event received: ${event?.event}');
    print('🔔 Full event data: $event');
    print('🔔 Event type: ${event?.event.runtimeType}');
    switch (event?.event) {
      case Event.actionCallAccept:
        // _callService.initialize();
        // _callService.acceptCall();

        print(
          "--------------------------------------------------------------------------------",
        );
        print("call accepted api request sent");
        print(
          "event -> ${event?.body['id']} :: ${event?.body['extra']['callerId']}",
        );
        print(
          "--------------------------------------------------------------------------------",
        );

        final res = await ApiService().authenticatedPut(
          '/call/accept',
          data: {
            'callId': event?.body['id'],
            'calleId': event?.body['extra']['callerId'],
          },
        );
        print("res -> $res");

        // Navigator.popUntil(
        //   NavigationHelper.navigator!.context,
        //   (route) => route.isFirst,
        // );

        break;
      case Event.actionCallDecline:
        // _callService.initialize();
        // _callService..declineCall();
        print(
          "--------------------------------------------------------------------------------",
        );
        print("event -> ${event}");
        print(
          "--------------------------------------------------------------------------------",
        );
        print("call declined api request sent");
        break;
      case Event.actionCallEnded:
        _callService.initialize();
        _callService..endCall();
        break;
      default:
        print('🔔 Unhandled CallKit event: ${event?.event}');
        print('🔔 Event data: $event');
        break;
    }
  });
  print('📨 Background message received: ${message.messageId}');
  print('📨 Message data: ${message.data}');

  // Handle call notifications in background
  final data = message.data;
  if (data['type'] == 'call') {
    print('📞 Background call notification received - showing CallKit');

    // Use CallKit for background call notifications
    await _handleBackgroundCallNotification(data);
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
    print('📞 CallKit notification shown in background for call: $callId');
  } catch (e) {
    print('❌ Error showing CallKit notification in background: $e');
  }
}
