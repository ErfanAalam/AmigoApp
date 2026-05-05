import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';
import 'package:uuid/uuid.dart';

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

/// Hand a Stream-originated FCM payload to the push notification manager so
/// it can show the native incoming-call UI (CallKit on iOS, full-screen
/// heads-up notification on Android) even when the app is killed.
///
/// IMPORTANT — this function deliberately does NOT open a WebSocket. Earlier
/// versions called `StreamVideo.handleRingingFlowNotifications` which goes
/// through `getCallRingingState` (a coordinator-WS call). That worked, but
/// the cold-path WS would race with the warm-path WS the activity opens
/// after the user taps Accept, and the SDK could interpret the cold-path
/// drop as "user rejected the call". By calling `showIncomingCall` directly
/// we skip the WS entirely — the native push notification UI doesn't need
/// it, and the warm-path takes over from cold-start via
/// `consumeAndAcceptActiveCall`.
///
/// Trade-off: we don't ask the coordinator whether the call is still
/// ringing before showing the UI. If the call was already cancelled in the
/// short FCM-delivery window, the user might see a brief notification
/// before the cancel-FCM clears it. That's acceptable; in exchange we
/// eliminate a whole category of WS-race bugs.
///
/// Safe to call from a top-level @pragma('vm:entry-point') function.
Future<void> handleStreamVideoBackgroundPush(RemoteMessage message) async {
  debugPrint('[STREAM-FCM] ▶ handleStreamVideoBackgroundPush  msgId=${message.messageId}');
  // Dump the full data payload so we can see exactly what Stream sent — type
  // (`call.ring` / `call.missed` / `call.ended`), call_cid, sender, etc.
  debugPrint('[STREAM-FCM]   data=${message.data}');
  if (Environment.streamApiKey.isEmpty) {
    debugPrint('[STREAM-FCM] ✗ STREAM_API_KEY empty — bailing');
    return;
  }

  final data = message.data;
  final type = data['type']?.toString();
  final callCid = data['call_cid']?.toString();
  if (callCid == null) {
    debugPrint('[STREAM-FCM] ✗ missing call_cid — bailing');
    return;
  }

  try {
    await Firebase.initializeApp();
    debugPrint('[STREAM-FCM]   Firebase initialised in handler');

    // ---------- Warm path: reuse the running client if one exists -------------
    StreamVideo client;
    bool warmStart = true;
    try {
      client = StreamVideo.instance;
      debugPrint('[STREAM-FCM]   warm path: reusing StreamVideo.instance');
    } catch (_) {
      warmStart = false;
      // ---------- Cold path: build a non-connecting client ----------------------
      // We don't need a WS for `showIncomingCall` / `showMissedCall` — both
      // route to the native push notification SDK and don't talk to the
      // coordinator. The token only matters because StreamVideoOptions
      // requires a user; we still pass a real one so push-token registration
      // continues to work after the activity boots.
      debugPrint('[STREAM-FCM]   cold path: bootstrapping (no WS)');
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

      // autoConnect:false is the load-bearing option here. Without it the
      // SDK opens a WS during the constructor and we're back in the
      // dual-WS race that previously broke accept-from-killed-state.
      client = StreamVideo.create(
        Environment.streamApiKey,
        user: User.regular(
          userId: user.id,
          name: user.name,
          image: user.profilePic,
        ),
        userToken: token,
        options: StreamVideoOptions(
          autoConnect: false,
          keepConnectionsAliveWhenInBackground: true,
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
      debugPrint('[STREAM-FCM]   cold-path client built  '
          'pushManager=${client.pushNotificationManager == null ? "NULL" : "ok"}');
    }

    final manager = client.pushNotificationManager;
    if (manager == null) {
      debugPrint('[STREAM-FCM] ✗ pushNotificationManager is NULL — bailing');
      return;
    }

    // Snapshot the cached active calls — useful for debugging stale-entry bugs
    // where a previous call's leftover entry confuses consumeAndAcceptActiveCall.
    try {
      final pre = await manager.activeCalls();
      debugPrint('[STREAM-FCM]   activeCalls() before show: '
          '${pre.length}: '
          '${pre.map((c) => "${c.callCid}(accepted=${c.isAccepted})").toList()}');
    } catch (_) {}

    // Pull display info out of the FCM payload. Stream sets these on every
    // ringing push; the field names are stable across SDK minor versions.
    final createdById = data['created_by_id']?.toString();
    final createdByName = data['created_by_display_name']?.toString();
    final callDisplayName = data['call_display_name']?.toString();
    final hasVideo = data['video']?.toString() != 'false';
    final callerName = (callDisplayName != null && callDisplayName.isNotEmpty)
        ? callDisplayName
        : createdByName;

    debugPrint('[STREAM-FCM]   parsed payload: type=$type  callCid=$callCid  '
        'createdById=$createdById  callerName="$callerName"  hasVideo=$hasVideo  '
        'warmStart=$warmStart');

    if (type == 'call.missed') {
      debugPrint('[STREAM-FCM]   showMissedCall…');
      await manager.showMissedCall(
        uuid: const Uuid().v4(),
        handle: createdById,
        callerName: callerName,
        callCid: callCid,
        hasVideo: hasVideo,
      );
      debugPrint('[STREAM-FCM]   ✓ showMissedCall returned');
      return;
    }
    if (type != 'call.ring') {
      debugPrint('[STREAM-FCM]   non-ring type "$type" — ignoring');
      return;
    }

    // call.ring → show incoming-call notification. NO ws connect, NO
    // getCallRingingState pre-flight. The native UI takes over from here;
    // when the user taps Accept the activity boots and StreamCallService's
    // `consumeAndAcceptActiveCall` does the actual coordinator accept on
    // the warm-path WS that will exist by then.
    debugPrint('[STREAM-FCM]   showIncomingCall(uuid=…, callCid=$callCid)');
    await manager.showIncomingCall(
      uuid: const Uuid().v4(),
      handle: createdById,
      callerName: callerName,
      callCid: callCid,
      hasVideo: hasVideo,
    );
    debugPrint('[STREAM-FCM]   ✓ showIncomingCall returned');

    try {
      final post = await manager.activeCalls();
      debugPrint('[STREAM-FCM]   activeCalls() after show: '
          '${post.length}: '
          '${post.map((c) => "${c.callCid}(accepted=${c.isAccepted})").toList()}');
    } catch (_) {}
  } catch (e, st) {
    debugPrint('[STREAM-FCM] ✗ handleStreamVideoBackgroundPush threw: $e\n$st');
  }
}
