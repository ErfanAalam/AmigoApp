import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';

import '../../../env.dart';
import '../../../utils/user.utils.dart';
import '../../cookies.service.dart';
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
      // short-lived one just to handle this notification.
      debugPrint('[STREAM-FCM]   cold path: no live client — bootstrapping');
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
        ),
        pushNotificationManagerProvider: StreamVideoPushNotificationManager.create(
          iosPushProvider: StreamVideoPushProvider.apn(
            name: Environment.streamApnProviderName,
          ),
          androidPushProvider: StreamVideoPushProvider.firebase(
            name: Environment.streamFcmProviderName,
          ),
          registerApnDeviceToken: true,
        ),
      );
      debugPrint('[STREAM-FCM]   cold-path client constructed → connecting…');
      // ignore: unawaited_futures
      client.connect().then((_) {
        debugPrint('[STREAM-FCM]   cold-path client.connect() done');
      });

      // Tear the temporary client down once the ringing flow resolves.
      final sub = client.observeCallDeclinedRingingEvent();
      client.disposeAfterResolvingRinging(
        disposingCallback: () {
          debugPrint('[STREAM-FCM]   cold-path client disposed (ringing resolved)');
          sub?.cancel();
        },
      );
    }

    debugPrint('[STREAM-FCM]   handing payload to '
        'StreamVideo.handleRingingFlowNotifications  warm=$warmStart  '
        'data.keys=${message.data.keys.toList()}');
    final handled = await client.handleRingingFlowNotifications(message.data);
    debugPrint('[STREAM-FCM]   ✓ handleRingingFlowNotifications → $handled');
  } catch (e, st) {
    debugPrint('[STREAM-FCM] ✗ handleStreamVideoBackgroundPush threw: $e\n$st');
  }
}
