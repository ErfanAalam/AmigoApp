import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';

import '../../../env.dart';
import '../../../utils/user.utils.dart';
import '../../cookies.service.dart';
import 'stream_call_push_config.dart';
import 'stream_call_token_loader.dart';

/// Returns true if the FCM payload originated from Stream Video (vs our own
/// chat / call:* push protocol). Stream sets `sender: "stream.video"` on every
/// push it sends.
bool isStreamVideoPush(Map<String, dynamic> data) {
  final sender = data['sender']?.toString();
  final hit = sender == 'stream.video';
  debugPrint('[STREAM-FCM] isStreamVideoPush?  sender="$sender"  → $hit  '
      'keys=${data.keys.toList()}');
  return hit;
}

/// Hand a Stream-originated FCM payload to the SDK so it can show the native
/// incoming-call UI (CallKit on iOS, full-screen heads-up notification on
/// Android) even when the app is killed.
///
/// Safe to call from a top-level @pragma('vm:entry-point') function.
Future<void> handleStreamVideoBackgroundPush(RemoteMessage message) async {
  debugPrint('[STREAM-FCM] ▶ handleStreamVideoBackgroundPush  msgId=${message.messageId}');
  if (Environment.streamApiKey.isEmpty) {
    debugPrint('[STREAM-FCM] ✗ STREAM_API_KEY empty — bailing');
    return;
  }

  try {
    await Firebase.initializeApp();
    debugPrint('[STREAM-FCM]   Firebase initialised in handler');

    // Reuse already-running client if the engine is alive (foreground/idle).
    StreamVideo client;
    bool warmStart = true;
    try {
      client = StreamVideo.instance;
      debugPrint('[STREAM-FCM]   warm path: reusing StreamVideo.instance');
    } catch (_) {
      warmStart = false;
      // Cold path: the app is killed and there is no client. Build a
      // short-lived one JUST to call handleRingingFlowNotifications.
      //
      // CRITICAL: we do NOT call client.connect() and we set
      // autoConnect:false. Opening a WebSocket here would race with the
      // warm-path StreamCallService that the activity later spins up — two
      // WS for the same user, the cold-path one dies, Stream's coordinator
      // interprets that as "callee left the call" and ends it for the
      // caller.
      //
      // The native push-notification manager (which `manager.showIncomingCall`
      // delegates to) is process-level, not WS-dependent, and the
      // `getCallRingingState` HTTP call inside handleRingingFlowNotifications
      // uses the user JWT directly. So everything we need works without a WS.
      debugPrint('[STREAM-FCM]   cold path: bootstrapping (no WS connect)');
      final user = await UserUtils().getUserDetails();
      if (user == null) {
        debugPrint('[STREAM-FCM] ✗ no logged-in user in cold path — abort');
        return;
      }
      debugPrint('[STREAM-FCM]   cold-path user.id=${user.id}');

      final cookieService = CookieService();
      await cookieService.init();

      final token = await loadStreamToken();
      if (token == null) {
        debugPrint('[STREAM-FCM] ✗ cold-path token loader returned null — abort');
        return;
      }

      client = StreamVideo.create(
        Environment.streamApiKey,
        user: User.regular(
          userId: user.id,
          name: user.name,
          image: user.profilePic,
        ),
        userToken: token,
        options: StreamVideoOptions(
          keepConnectionsAliveWhenInBackground: true,
          autoConnect: false,
        ),
        pushNotificationManagerProvider: StreamVideoPushNotificationManager.create(
          iosPushProvider: StreamVideoPushProvider.apn(
            name: Environment.streamApnProviderName,
          ),
          androidPushProvider: StreamVideoPushProvider.firebase(
            name: Environment.streamFcmProviderName,
          ),
          pushConfiguration: amigoStreamPushConfiguration,
          registerApnDeviceToken: true,
        ),
      );

      // Subscribe to native push action events so the cold-path client can
      // dispose itself when the user declines from the notification, or
      // when a follow-up FCM (call.ended / call.missed) cancels the ring.
      // No WS needed — these events come from the native push manager.
      final subs = client.observeCoreRingingEventsForBackground();
      client.disposeAfterResolvingRinging(
        disposingCallback: () {
          debugPrint('[STREAM-FCM]   cold-path client disposed (ringing resolved)');
          subs.cancel();
        },
      );
    }

    debugPrint('[STREAM-FCM]   handing payload to '
        'StreamVideo.handleRingingFlowNotifications  warm=$warmStart  '
        'data.keys=${message.data.keys.toList()}');
    final handled = await client.handleRingingFlowNotifications(message.data);
    debugPrint('[STREAM-FCM]   ✓ handleRingingFlowNotifications → $handled');

    // Don't tear the cold-path client down here. `manager.showIncomingCall`
    // inside handleRingingFlowNotifications is fired with `unawaited(...)` —
    // calling `disconnect()` immediately races against that pending native
    // notification show. Let the client live until `disposeAfterResolvingRinging`
    // fires on a terminal event (decline / cancel / accept-handed-off).
    // Since autoConnect is false, no WS is open, so there's no dual-connection
    // problem to worry about.
  } catch (e, st) {
    debugPrint('[STREAM-FCM] ✗ handleStreamVideoBackgroundPush threw: $e\n$st');
  }
}
