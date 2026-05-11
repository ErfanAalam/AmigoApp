import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter_background.dart' show StreamVideoFlutterBackground;
import 'package:stream_video_push_notification/stream_video_push_notification.dart';
import 'package:uuid/uuid.dart';

import '../../../env.dart';
import '../../../models/call.model.dart' as app_call;
import '../../../models/user.model.dart' as app_user;
import '../../../utils/navigation-helper.util.dart';
import '../../../utils/user.utils.dart';
import '../../cookies.service.dart';
import '../i_call_backend.dart';
import 'stream_call_logger.dart';
import 'stream_call_push_config.dart';
import 'stream_call_ringtones.dart';
import 'stream_call_screens.dart';
import 'stream_call_token_loader.dart';
import 'stream_callstyle_notifier.dart';

/// Stream Video implementation of the call backend.
///
/// Coexists with the in-house WebRTC `CallService`. Selected at runtime via
/// `Environment.callBackend == 'stream'`.
///
/// Public API mirrors `CallService` (via [ICallBackend]) so the Riverpod
/// `CallServiceNotifier`, the call pill, and chat-screen call buttons all keep
/// working without modification.
///
/// What this class is responsible for:
///  - Lazy bootstrapping the `StreamVideo` client (token loader hits our
///    backend `/call/stream/credentials`).
///  - Driving the call lifecycle (initiate / accept / decline / end).
///  - Keeping a lightweight [app_call.ActiveCallState] mirror in sync with
///    Stream's call state stream so the existing global call pill renders.
///  - Pushing the prebuilt [StreamCallContainer] screen — the SDK's screen
///    handles ringtone, lockscreen UI, audio routing, hold/mute, foreground
///    service, and CallKit on iOS, which is exactly the WhatsApp-style UX the
///    user asked for.
class StreamCallService implements ICallBackend {
  StreamCallService._internal();
  static final StreamCallService _instance = StreamCallService._internal();
  factory StreamCallService() => _instance;

  final CookieService _cookieService = CookieService();
  final Dio _dio = Dio();

  StreamVideo? _client;
  app_user.UserModel? _currentUser;

  app_call.ActiveCallState? _activeCall;
  Call? _streamCall;

  /// Display info for the remote party. Set on outgoing calls (from the chat
  /// row) and on incoming calls (from the call's member metadata) so the
  /// screen can render before the first participant-joined event lands.
  CallerHint? _callerHint;
  CallerHint? get callerHint => _callerHint;

  /// Single source of truth for "when did this call become connected?" Both
  /// the call screen and the ongoing-call notification read this so the two
  /// timers stay in lock-step (and survive notification dismissal).
  /// Set once when status first flips to a joined/connected state, cleared
  /// in [_clearMirror].
  DateTime? _callConnectedAt;
  DateTime? get callConnectedAt => _callConnectedAt;

  /// Tracks the cid we've issued `join()` for — guards against double-join.
  String? _joinedCid;
  /// Last name passed to the CallStyle notification. Lets us avoid spamming
  /// the native channel with a refresh on every state change unless the
  /// resolved name actually changed (e.g. SFU finally pushed participant
  /// metadata, replacing 'Unknown' with the real name).
  String? _lastShownNotifName;
  StreamSubscription<CallState>? _callStateSub;
  StreamSubscription<Call?>? _activeCallSub;
  StreamSubscription<Call?>? _incomingCallSub;
  StreamSubscription? _coreRingingSub;
  StreamSubscription? _connectionSub;
  // Subscription to the CallKit-style notification's RingingEvent stream.
  // We need this because stream_video_push_notification only forwards
  // ActionCallAccept (via observeCoreRingingEvents) — ActionCallDecline is
  // dropped on the floor, so the caller never finds out the user pressed
  // "Decline" on the heads-up notification. We listen here and explicitly
  // call `call.reject()` so the coordinator notifies the caller.
  StreamSubscription<RingingEvent>? _ringingEventsSub;
  // Per-call diagnostic subscription — fires for every coordinator event the
  // SDK processes for this call (accept/reject/end/etc.). Lets us see the
  // exact event sequence when something goes sideways (ghost call,
  // self-reject, …). Re-bound in `_attachCallEventLogging` whenever the
  // active call changes.
  StreamSubscription? _callEventsSub;

  bool _isInitialized = false;
  bool _isTerminating = false;

  /// Whether the Flutter app is currently in the foreground.
  ///
  /// Used to decide whether the in-app `StreamCallRingtones` should play.
  /// When the app is backgrounded the FCM-driven flutter_callkit_incoming
  /// notification already plays the system ringtone — letting the in-app
  /// driver also play it produces the duplicate ringing the user hits
  /// when minimising the app while a call comes in.
  ///
  /// Reads `WidgetsBinding.instance.lifecycleState` at call time. That value
  /// can be null very early in app boot (before the framework attaches), in
  /// which case we treat it as foregrounded — that's the safe default for
  /// initial route mounts driven from the cold-start consume helper.
  bool get _isAppForeground {
    final s = WidgetsBinding.instance.lifecycleState;
    return s == null || s == AppLifecycleState.resumed;
  }

  /// Plays the incoming-call ringtone only when the app is foregrounded.
  /// Logs the suppression reason so duplicate-ringtone bugs are diagnosable
  /// from logs alone without having to instrument both call sites.
  void _maybePlayIncomingRingtone(String origin) {
    if (_isAppForeground) {
      debugPrint('[STREAM-CALL]   ringtone($origin) → playIncoming (foreground)');
      // ignore: unawaited_futures
      StreamCallRingtones.instance.playIncoming();
    } else {
      debugPrint('[STREAM-CALL]   ringtone($origin) → SKIPPED — app is '
          '${WidgetsBinding.instance.lifecycleState?.name ?? "unknown"}; '
          'FCM/CallKit notification handles audio');
    }
  }

  // ---- ICallBackend surface ----------------------------------------------

  @override
  app_call.ActiveCallState? get activeCall => _activeCall;
  @override
  bool get hasActiveCall => _activeCall != null;
  @override
  bool get isInCall =>
      _activeCall?.status == app_call.CallStatus.answered ||
      _activeCall?.status == app_call.CallStatus.connecting;
  @override
  bool get isInitialized => _isInitialized;

  /// Public client accessor — used by `main.dart` background FCM handler so it
  /// can route Stream pushes when the app is killed.
  StreamVideo? get client => _client;

  /// Live Stream `Call` instance, when one is active. Used by the call pill so
  /// it can re-push the Flutter call screen if the user popped it.
  Call? get streamCall =>
      _streamCall ?? _client?.state.activeCall.valueOrNull;

  @override
  Future<void> initialize() async {
    debugPrint('[STREAM-CALL] ▶ initialize() called  (already=$_isInitialized)');
    if (Environment.streamApiKey.isEmpty) {
      debugPrint('[STREAM-CALL] ✗ STREAM_API_KEY is empty — Stream backend disabled.');
      return;
    }

    // Look up the logged-in user FIRST so we can compare against any prior
    // session. The Riverpod call provider re-runs `initialize()` every time
    // the user logs back in (after `auth.service.dart:logout()` calls our
    // dispose) — but in case dispose wasn't called for some reason, we
    // still tear down a stale client when the user-id has changed.
    final freshUser = await UserUtils().getUserDetails();
    if (freshUser == null) {
      debugPrint('[STREAM-CALL] ✗ No logged-in user; deferring init until login.');
      return;
    }

    if (_isInitialized) {
      if (_currentUser?.id == freshUser.id) {
        debugPrint('[STREAM-CALL]   ↳ already initialised for ${freshUser.id}, skipping');
        return;
      }
      debugPrint('[STREAM-CALL]   user changed (was=${_currentUser?.id}, '
          'now=${freshUser.id}) — disposing stale client before re-init');
      await dispose();
    }
    _currentUser = freshUser;
    debugPrint('[STREAM-CALL]   STREAM_API_KEY length=${Environment.streamApiKey.length}, '
        'callBackend=${Environment.callBackend}');
    debugPrint('[STREAM-CALL]   currentUser.id=${_currentUser!.id} name=${_currentUser!.name}');

    try {
      debugPrint('[STREAM-CALL]   fetching Stream token from backend…');
      final token = await loadStreamToken();
      if (token == null) {
        debugPrint('[STREAM-CALL] ✗ token loader returned null — aborting init.');
        return;
      }
      debugPrint('[STREAM-CALL]   ✓ token received (len=${token.length})');

      debugPrint('[STREAM-CALL]   wiring pushNotificationManagerProvider '
          '(android="${Environment.streamFcmProviderName}", '
          'ios="${Environment.streamApnProviderName}") — these MUST match the '
          'provider names you configured in Stream Dashboard → Push Providers');
      _client = StreamVideo(
        Environment.streamApiKey,
        user: User.regular(
          userId: _currentUser!.id,
          name: _currentUser!.name,
          image: _currentUser!.profilePic,
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
          pushConfiguration: amigoStreamPushConfiguration,
          registerApnDeviceToken: true,
        ),
      );
      debugPrint('[STREAM-CALL]   StreamVideo client constructed (with push manager)');
      debugPrint('[STREAM-CALL]   pushNotificationManager=${_client!.pushNotificationManager == null ? "NULL" : "ok"}');

      _bindStateSubscriptions();
      debugPrint('[STREAM-CALL]   subscriptions wired');

      // Wire ONLY the app-swipe-from-recents handler — we deliberately skip
      // `StreamBackgroundService.init()` because it spawns a second
      // foreground-service notification on top of our CallStyle one (the
      // user reported two stickies in release: "Unknown / Hang up" + "Amigo
      // / vvvkkk vvvkkk / Cancel"). The CallStyle notification posted by
      // [StreamCallStyleNotifier] is the only one we want.
      //
      // `setOnPlatformUiLayerDestroyed` fires from the SDK plugin's
      // `onDetachedFromActivity` lifecycle callback (not from the
      // foreground service itself), so it works fine without
      // StreamBackgroundService. We use it to end the call when the user
      // swipes the app away from recents.
      _wireAppSwipeHandler();

      // Belt-and-braces: drop any stale CallStyle notification leftover
      // from a previous run (process killed mid-call, etc.). hide() is
      // idempotent.
      // ignore: unawaited_futures
      StreamCallStyleNotifier.instance.hide();

      // Establish the WS connection eagerly so incoming-call events arrive
      // without waiting for the first user action. After `connect` resolves,
      // explicitly register the device's FCM token with the Stream
      // coordinator — the SDK's auto-register path (in
      // stream_video_push_notification's `registerDevice()`) only listens
      // for `onTokenRefresh`, which doesn't fire on cold-start when the
      // token is already cached, so without this manual call we'd miss
      // the very first run after install (the "must open app twice"
      // symptom users reported).
      debugPrint('[STREAM-CALL]   issuing client.connect()…');
      _client!.connect().then((res) async {
        debugPrint('[STREAM-CALL]   ✓ client.connect() completed → $res');
        if (res.isSuccess) {
          await _registerFcmTokenWithStream();
        }
      }).catchError((e, st) {
        debugPrint('[STREAM-CALL] ✗ client.connect() failed: $e\n$st');
      });

      _isInitialized = true;
      debugPrint('[STREAM-CALL] ✓ initialise() done for user=${_currentUser!.id}');

      // Killed-state pickup: if the user tapped Accept on a notification while
      // the app was killed, the SDK has the call cached. We must explicitly
      // consume + accept it after the engine boots.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          // First log how many cached calls Stream's push manager is holding.
          // Stale accepted calls from a previous run can collide with the
          // current one — `consumeAndAcceptActiveCall` picks `.first`, so a
          // leftover entry would steal the cold-start handoff.
          try {
            final pending = await _client!.pushNotificationManager?.activeCalls();
            debugPrint('[STREAM-CALL]   push-mgr.activeCalls() → '
                '${pending?.length ?? 0}: '
                '${pending?.map((c) => "${c.callCid}(accepted=${c.isAccepted})").toList()}');
          } catch (_) {}

          debugPrint('[STREAM-CALL]   trying consumeAndAcceptActiveCall…');
          final consumed = await _client!.consumeAndAcceptActiveCall(
            onCallAccepted: (call) async {
              debugPrint('[STREAM-CALL]   ✓ cold-start accepted call: '
                  '${call.callCid.value}  status=${call.state.value.status.runtimeType}  '
                  'acceptedByMe=${(call.state.value.status is CallStatusIncoming) ? (call.state.value.status as CallStatusIncoming).acceptedByMe : "n/a"}');
              _streamCall = call;
              _callerHint = _hintFromCall(call);
              // Attach the events logger immediately — the activeCall stream
              // may not have fired yet, and this is the path most likely to
              // surface the WS-vs-HTTP race we patched in vendor/.
              _attachCallEventLogging(call);
              // CRITICAL: Stream's consume helper accepts but never joins.
              // Without this the SFU connection is never established and mic
              // stays dead even though the UI shows "Connected".
              await ensureJoined(call);
              _maybePushCallScreen(call);
            },
          );
          debugPrint('[STREAM-CALL]   consumeAndAcceptActiveCall → $consumed');
        } catch (e, st) {
          debugPrint('[STREAM-CALL] ✗ consumeAndAcceptActiveCall threw: $e\n$st');
        }
      });
    } catch (e, st) {
      debugPrint('[STREAM-CALL] ✗ initialise() threw: $e\n$st');
      _client = null;
    }
  }

  // ---- Lock screen flags ---------------------------------------------------

  static const MethodChannel _lockScreenChannel =
      MethodChannel('com.aiexch.amigo/lock_screen');

  Future<void> enableLockScreenFlags() async {
    try {
      await _lockScreenChannel.invokeMethod('enableLockScreenFlags');
      debugPrint('[STREAM-CALL]   lock-screen flags enabled');
    } catch (e) {
      debugPrint('[STREAM-CALL]   enableLockScreenFlags failed: $e');
    }
  }

  Future<void> disableLockScreenFlags() async {
    try {
      await _lockScreenChannel.invokeMethod('disableLockScreenFlags');
      debugPrint('[STREAM-CALL]   lock-screen flags disabled');
    } catch (e) {
      debugPrint('[STREAM-CALL]   disableLockScreenFlags failed: $e');
    }
  }

  /// Explicitly register the FCM token with Stream's coordinator. Stream's
  /// `pushNotificationManager.registerDevice()` only listens for
  /// `onTokenRefresh` on Android — which doesn't fire on a cold start when
  /// FirebaseMessaging already has a cached token. Without this manual call,
  /// the device isn't known to Stream until the OS rotates the token (or the
  /// app is opened a second time and `onTokenRefresh` finally fires), which
  /// is exactly the "first launch doesn't get pushes" bug.
  Future<void> _registerFcmTokenWithStream() async {
    final client = _client;
    if (client == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[STREAM-CALL]   ✗ FCM token unavailable — skip Stream device register');
        return;
      }
      debugPrint('[STREAM-CALL]   registering FCM token with Stream  '
          'tokenLen=${token.length}  provider=${Environment.streamFcmProviderName}');
      final res = await client.addDevice(
        pushToken: token,
        pushProvider: PushProvider.firebase,
        pushProviderName: Environment.streamFcmProviderName,
        voipToken: false,
      );
      debugPrint('[STREAM-CALL]   addDevice → success=${res.isSuccess}');
    } catch (e, st) {
      debugPrint('[STREAM-CALL]   ✗ _registerFcmTokenWithStream threw: $e\n$st');
    }
  }

  /// Hooks the SDK's plugin-level "platform UI layer destroyed" callback so
  /// we can detect the user swiping the app away from recents and tear the
  /// in-flight call down. The callback fires from the Stream Flutter plugin's
  /// `onDetachedFromActivity` lifecycle event, independent of whether
  /// `StreamBackgroundService` (the foreground-service notification source
  /// we deliberately skipped) is running.
  ///
  /// The platform forwards an empty `callCid` here, so we resolve the active
  /// call ourselves from `client.state.activeCall`.
  void _wireAppSwipeHandler() {
    StreamVideoFlutterBackground.setOnPlatformUiLayerDestroyed(
      (String _) async {
        // Always stop any in-flight ringtone before the activity tears
        // down — the channel may be dead by the time _onCallStateChanged
        // fires its terminal stop, leaving native MediaPlayer/ToneGenerator
        // resources orphaned. AmigoRingtoneManager.onDestroy provides the
        // final fallback if even this drops.
        // ignore: unawaited_futures
        StreamCallRingtones.instance.stopAll();
        final call = _streamCall ?? _client?.state.activeCall.valueOrNull;
        if (call == null) {
          debugPrint('[STREAM-CALL] onPlatformUiLayerDestroyed — no active call, nothing to tear down');
          return;
        }
        debugPrint('[STREAM-CALL] onPlatformUiLayerDestroyed — '
            'app removed from recents, ending call ${call.callCid.value}');
        try {
          // For the call creator, `end()` terminates the call for everyone.
          // For a regular participant, `leave()` is the right action; calling
          // `end()` returns a permission-denied result which we silently
          // swallow and fall through to leave().
          if (call.state.value.createdByMe) {
            await call.end();
          } else {
            await call.leave();
          }
        } catch (e) {
          debugPrint('[STREAM-CALL]   end/leave threw: $e — falling back to leave');
          try {
            await call.leave();
          } catch (_) {}
        }
        // Force-close our WS too so the coordinator sees the disconnect
        // before our process is killed. Without this the WS is reaped by the
        // OS asynchronously and the other side waits.
        try {
          await _client?.disconnect();
        } catch (_) {}
        // Drop the CallStyle notification deterministically — without
        // StreamBackgroundService managing the call lifecycle, we own
        // dismissal end-to-end.
        // ignore: unawaited_futures
        StreamCallStyleNotifier.instance.hide();
      },
    );
  }

  /// Idempotent `call.join(...)` wrapper with our audio-only defaults.
  ///
  /// Why this exists: Stream's `consumeAndAcceptActiveCall` (the cold-start
  /// pickup path) calls `accept()` but **does not** call `join()`. Without a
  /// join, the SFU media connection is never established → mic is dead and
  /// the two sides can't actually talk even though Stream marks the call as
  /// "connected". We surface this from every entry point that may have
  /// accepted a call (cold-start, foreground accept button, screen mount
  /// safety net).
  Future<void> ensureJoined(Call call) async {
    final cid = call.callCid.value;
    if (_joinedCid == cid) {
      debugPrint('[STREAM-CALL]   ensureJoined: $cid already joined');
      return;
    }
    final status = call.state.value.status;
    if (status.isAlreadyJoined) {
      // Already in a joined state but our flag is stale — reconcile.
      _joinedCid = cid;
      debugPrint('[STREAM-CALL]   ensureJoined: $cid already in joined state '
          '(${status.runtimeType}) — flag synced');
      return;
    }
    // Pick the right connect-options based on whether the call was placed
    // as a video call. We read `amigo_video_call` from the call's custom
    // data — stamped by the caller's `initiateCall` (see above). We do
    // NOT use `state.settings.video.enabled` because that's a per-call-TYPE
    // setting (always true for the default call type) and ignores the
    // per-call `video` flag.
    final customVideo = call.state.value.custom['amigo_video_call'];
    final isVideoCall = customVideo == true;
    final connectOpts = isVideoCall ? videoConnect : audioOnlyConnect;
    debugPrint('[STREAM-CALL]   ensureJoined: joining $cid (status=$status)  '
        'video=$isVideoCall  customVideo=$customVideo  '
        'connection=${_client?.state.connection.value}');
    _joinedCid = cid;
    final res = await call.join(connectOptions: connectOpts);
    res.fold(
      success: (_) => debugPrint('[STREAM-CALL]   ensureJoined: join SUCCESS'),
      failure: (f) => debugPrint('[STREAM-CALL]   ensureJoined: join FAILED — '
          'type=${f.error.runtimeType} '
          'message="${f.error.message}" '
          'full=${f.error}\n'
          'stack=${f.error.stackTrace}'),
    );
    if (res.isFailure) {
      _joinedCid = null;
      return;
    }
    // Do NOT call setMicrophoneEnabled/setCameraEnabled here. `audioOnlyConnect`
    // already specifies the correct track state for join(); calling the
    // setters again triggers a second `getUserMedia` and republishes the
    // audio track, which the SFU treats as a track replacement and the
    // callee-side ends up Reconnecting → Disconnected within milliseconds
    // of connecting.
  }

  /// Wire up the two streams we care about:
  ///  - `state.activeCall` to know when a call enters/leaves the foreground
  ///  - the per-call state stream to mirror status (ringing→answered→ended)
  ///    into our [app_call.ActiveCallState] so the call pill renders.
  void _bindStateSubscriptions() {
    final client = _client!;

    _activeCallSub?.cancel();
    _activeCallSub = client.state.activeCall.listen((Call? call) {
      debugPrint('[STREAM-CALL] ★ state.activeCall fired  call=${call?.callCid.value}');
      _streamCall = call;
      _callStateSub?.cancel();
      _callStateSub = null;

      if (call == null) {
        // Don't wipe the mirror immediately — `_onCallStateChanged` may have
        // just transitioned us into a terminal status (ended / declined) and
        // scheduled the linger timer so the pill / call screen can show the
        // "Call ended" pulse. Bypassing that would make the UI flash off.
        debugPrint('[STREAM-CALL]   activeCall=null  '
            '(mirror linger=${_terminalLingerTimer != null})');
        _attachCallEventLogging(null);
        if (_terminalLingerTimer == null) _clearMirror();
        return;
      }

      _callerHint ??= _hintFromCall(call);
      _callStateSub = call.state.listen(_onCallStateChanged);
      _attachCallEventLogging(call);
      debugPrint('[STREAM-CALL]   subscribed to call.state for ${call.callCid.value}');
      // Push the in-call screen if the user accepted from CallKit/notification
      // and there's no UI yet.
      _maybePushCallScreen(call);
    });

    // Foreground incoming-call routing. When the user is signed in with the
    // app open, the SDK delivers the ringing event over the coordinator WS
    // and exposes it on `state.incomingCall` BEFORE it appears as
    // `state.activeCall`. Without surfacing the screen here, the incoming
    // call lives only in the heads-up banner — which is exactly the
    // "doesn't ring when app is open" symptom.
    _incomingCallSub?.cancel();
    _incomingCallSub = client.state.incomingCall.listen((Call? call) {
      debugPrint('[STREAM-CALL] ★ state.incomingCall fired  call=${call?.callCid.value}');
      if (call == null) return;
      _streamCall = call;
      _callerHint ??= _hintFromCall(call);
      _attachCallEventLogging(call);
      // Subscribe to the call's state stream directly — Stream only flips
      // `state.activeCall` after we accept+join, so without this hook
      // _onCallStateChanged never fires during the ring phase (no
      // "answered"/"missed"/"declined" terminal handling, no auto-stop
      // ringtone via the state-stream driver).
      _callStateSub?.cancel();
      _callStateSub = call.state.listen(_onCallStateChanged);
      // Play the system ringtone right now; don't wait for a state event.
      // Foreground-only — when the app is backgrounded/minimised the
      // FCM-driven flutter_callkit_incoming notification plays the ringtone,
      // and letting the in-app driver also play results in two ringtones.
      _maybePlayIncomingRingtone('incomingCall');
      _maybePushCallScreen(call);
    });

    // CallKit/native incoming UI fires this when user taps Accept while app
    // is in the background. Bring the UI to the front.
    _coreRingingSub?.cancel();
    _coreRingingSub = client.observeCoreRingingEvents(
      onCallAccepted: (Call call) async {
        debugPrint('[STREAM-CALL] ★ observeCoreRingingEvents → onCallAccepted '
            'cid=${call.callCid.value}  '
            'status=${call.state.value.status.runtimeType}  '
            'createdByMe=${call.state.value.createdByMe}');
        _streamCall = call;
        _callerHint ??= _hintFromCall(call);
        _attachCallEventLogging(call);
        await ensureJoined(call);
        _maybePushCallScreen(call);
      },
    );

    // Decline-from-notification handler. The package's own subscriber
    // ignores ActionCallDecline (it only cancels its event subscriptions),
    // so without this the caller keeps ringing until call_timeout fires.
    final pushManager = client.pushNotificationManager;
    if (pushManager != null) {
      debugPrint('[STREAM-CALL]   wiring ActionCallDecline listener on '
          'pushManager.onCallEvent…');
      _ringingEventsSub?.cancel();
      _ringingEventsSub = pushManager.onCallEvent.listen((event) async {
        // Trace EVERY event so it's obvious from logs whether the listener is
        // firing at all when the user reports decline-from-notification not
        // notifying the caller.
        debugPrint('[STREAM-CALL] ⮕ pushManager.onCallEvent: '
            '${event.runtimeType}');
        if (event is! ActionCallDecline) return;
        final cid = event.data.callCid;
        debugPrint('[STREAM-CALL] ★ ActionCallDecline received cid=$cid');
        if (cid == null || !cid.contains(':')) {
          debugPrint('[STREAM-CALL]   ✗ cid missing/invalid — cannot reject');
          return;
        }
        final colon = cid.indexOf(':');
        final type = StreamCallType.fromString(cid.substring(0, colon));
        final id = cid.substring(colon + 1);
        debugPrint('[STREAM-CALL]   parsed cid → type=${type.value} id=$id');
        try {
          final call = client.makeCall(callType: type, id: id);
          debugPrint('[STREAM-CALL]   calling call.reject()…');
          final res = await call.reject();
          debugPrint('[STREAM-CALL]   reject() returned success=${res.isSuccess}'
              '${res.isSuccess ? "" : " err=${res.toString()}"}');
          // Belt-and-braces: drop the lock-screen launcher notification too.
          // Stream's call.ended/missed FCM normally clears it, but on a clean
          // local decline we don't want to wait for that round-trip.
          try {
            await pushManager.endCallByCid(cid);
            debugPrint('[STREAM-CALL]   endCallByCid($cid) ok');
          } catch (e) {
            debugPrint('[STREAM-CALL]   endCallByCid threw: $e');
          }
        } catch (e, st) {
          debugPrint('[STREAM-CALL] ✗ reject from notification failed: $e\n$st');
        }
      });
    } else {
      debugPrint('[STREAM-CALL]   ⚠ pushManager is null — '
          'ActionCallDecline cannot be wired');
    }

    // Visibility into the coordinator WS. If we never see `connected` here,
    // the callee will never receive ringing events while the app is open.
    _connectionSub?.cancel();
    _connectionSub = client.state.connection.listen((cs) {
      debugPrint('[STREAM-CALL]   client.connection → $cs');
    });

    debugPrint('[STREAM-CALL]   _bindStateSubscriptions complete');
  }

  /// Subscribes to the call's coordinator-event stream so we can see *exactly*
  /// what the SDK is processing when something looks suspicious. This is the
  /// channel that carries `StreamCallAcceptedEvent` / `StreamCallRejectedEvent`
  /// / `StreamCallEndedEvent` etc. — the same events that drive
  /// `_handleCoordinatorCallAccepted` / `_handleCoordinatorCallRejected` (the
  /// pair we patched in `vendor/stream_video/`).
  ///
  /// Why this matters: when the call goes wrong (caller sees "Call declined"
  /// out of nowhere, callee opens to a ghost call, …) the smoking-gun is in
  /// this stream. Logging it makes the failure obvious instead of having to
  /// reverse-engineer it from `state.status` transitions.
  void _attachCallEventLogging(Call? call) {
    _callEventsSub?.cancel();
    _callEventsSub = null;
    if (call == null) return;
    final cidShort = call.callCid.value;
    final me = _currentUser?.id ?? '<unknown>';
    debugPrint('[STREAM-EVENTS] ▶ attaching events listener  cid=$cidShort  me=$me');
    _callEventsSub = call.callEvents.listen((event) {
      // Coordinator events are the most reliable signal that the ring
      // phase is over — Accepted/Rejected/Ended all mean "stop the
      // ringtone, now". We can't rely on the call.state stream alone
      // because for the caller, the state stream lags behind the
      // coordinator event by 200-1000ms (the SDK has to round-trip a
      // join() before flipping state.status), and the user reads that
      // gap as "the ringback kept going after the call connected".
      if (event is StreamCallAcceptedEvent ||
          event is StreamCallRejectedEvent ||
          event is StreamCallEndedEvent ||
          event is StreamCallSessionEndedEvent ||
          event is StreamCallMissedEvent) {
        // ignore: unawaited_futures
        StreamCallRingtones.instance.stopAll();
      }
      // Decode the most diagnostic fields per event type so we don't have to
      // rely on toString() which the SDK doesn't always implement nicely.
      String summary;
      if (event is StreamCallAcceptedEvent) {
        summary = 'StreamCallAcceptedEvent  acceptedByUserId=${event.acceptedByUserId}'
            '  ←me=${event.acceptedByUserId == me}';
      } else if (event is StreamCallRejectedEvent) {
        summary = 'StreamCallRejectedEvent  rejectedByUserId=${event.rejectedByUserId}'
            '  ←me=${event.rejectedByUserId == me}';
      } else if (event is StreamCallEndedEvent) {
        summary = 'StreamCallEndedEvent';
      } else if (event is StreamCallRingingEvent) {
        summary = 'StreamCallRingingEvent';
      } else if (event is StreamCallMissedEvent) {
        summary = 'StreamCallMissedEvent';
      } else if (event is StreamCallSessionStartedEvent) {
        summary = 'StreamCallSessionStartedEvent';
      } else if (event is StreamCallSessionEndedEvent) {
        summary = 'StreamCallSessionEndedEvent';
      } else if (event is StreamCallMemberAddedEvent) {
        summary = 'StreamCallMemberAddedEvent';
      } else if (event is StreamCallMemberRemovedEvent) {
        summary = 'StreamCallMemberRemovedEvent';
      } else if (event is StreamCallUpdatedEvent) {
        summary = 'StreamCallUpdatedEvent';
      } else {
        summary = '${event.runtimeType}';
      }
      debugPrint('[STREAM-EVENTS] ⮕ $cidShort  $summary');
    });
  }

  Timer? _terminalLingerTimer;

  void _onCallStateChanged(CallState state) {
    final status = _mapStreamStatus(state.status);
    final remote = _firstRemoteParticipant(state);
    debugPrint('[STREAM-CALL] ⮕ call.state: cid=${state.callCid.value} '
        'streamStatus=${state.status.runtimeType} mapped=$status '
        'createdByMe=${state.createdByMe} '
        'participants=${state.callParticipants.map((p) => p.userId).toList()}');

    // Drive ringtone playback off the SDK's status. Idempotent: each helper
    // no-ops if already in the right mode and stops the *other* tone first.
    // Incoming uses the foreground-only guard so we don't double up with
    // flutter_callkit_incoming's notification ringtone when backgrounded.
    final streamStatus = state.status;
    if (streamStatus is CallStatusIncoming && !streamStatus.acceptedByMe) {
      _maybePlayIncomingRingtone('callState');
    } else if (streamStatus is CallStatusOutgoing &&
        !streamStatus.acceptedByCallee) {
      // ignore: unawaited_futures
      StreamCallRingtones.instance.playOutgoing();
    } else {
      // ignore: unawaited_futures
      StreamCallRingtones.instance.stopAll();
    }

    // Refine `ended` into `declined`/`missed` when possible, based on the
    // disconnect reason and prior status. The pill renders different copy
    // for each.
    app_call.CallStatus refined = status;
    if (state.status is CallStatusDisconnected) {
      final reason = (state.status as CallStatusDisconnected).reason;
      debugPrint('[STREAM-CALL]   disconnect details: '
          'reason=${reason.runtimeType} '
          'reasonStr="$reason" '
          'wasRinging=${_activeCall?.status == app_call.CallStatus.ringing} '
          'priorMirrorStatus=${_activeCall?.status}');
      final reasonStr = reason.toString().toLowerCase();
      final wasRinging = _activeCall?.status == app_call.CallStatus.ringing;
      if (reasonStr.contains('reject')) {
        refined = app_call.CallStatus.declined;
      } else if (wasRinging) {
        // Disconnected while still ringing → caller abandoned / callee
        // didn't answer in time.
        refined = app_call.CallStatus.missed;
      } else {
        refined = app_call.CallStatus.ended;
      }
    }

    // Best-name resolution chain: live SFU participant > existing mirror
    // entry (already enriched) > caller hint (stuffed in by initiateCall /
    // _hintFromCall) > member metadata > 'Unknown'. We avoid landing on
    // 'Unknown' aggressively because the CallStyle notification is built
    // off this and the user complained it stuck on "Unknown".
    String pickName() {
      if (remote != null && remote.name.isNotEmpty) return remote.name;
      final mirrored = _activeCall?.userName;
      if (mirrored != null && mirrored.isNotEmpty && mirrored != 'Unknown') {
        return mirrored;
      }
      final hintName = _callerHint?.userName;
      if (hintName != null && hintName.isNotEmpty) return hintName;
      for (final m in state.callMembers) {
        if (m.userId != state.currentUserId && m.name.isNotEmpty) {
          return m.name;
        }
      }
      return remote?.userId ?? 'Unknown';
    }

    String? pickAvatar() {
      final remoteImage = remote?.image;
      if (remoteImage != null && remoteImage.isNotEmpty) return remoteImage;
      final mirrored = _activeCall?.userProfilePic;
      if (mirrored != null && mirrored.isNotEmpty) return mirrored;
      final hintImage = _callerHint?.userProfilePic;
      if (hintImage != null && hintImage.isNotEmpty) return hintImage;
      for (final m in state.callMembers) {
        final image = m.image;
        if (m.userId != state.currentUserId &&
            image != null &&
            image.isNotEmpty) {
          return image;
        }
      }
      return null;
    }

    final resolvedName = pickName();
    final resolvedAvatar = pickAvatar();

    final mirror = (_activeCall ?? app_call.ActiveCallState(
      callId: state.callCid.value,
      userId: remote?.userId ?? _callerHint?.userId ?? '',
      userName: resolvedName,
      userProfilePic: resolvedAvatar,
      callType: state.createdByMe
          ? app_call.CallType.outgoing
          : app_call.CallType.incoming,
      status: refined,
      startTime: DateTime.now(),
    )).copyWith(
      status: refined,
      userId: remote?.userId ?? _activeCall?.userId ?? _callerHint?.userId ?? '',
      userName: resolvedName,
      userProfilePic: resolvedAvatar,
    );

    _activeCall = mirror;

    // Local call-history bookkeeping. We have everything we need from the
    // SDK's call.state stream — caller, callee, status — so we persist
    // straight into our SQLite `calls` table instead of relying on the
    // backend webhook. Methods are idempotent: replays of the same status
    // are no-ops.
    final cid = state.callCid.value;
    final callerIdResolved = state.createdByUserId;
    String? calleeIdResolved;
    for (final m in state.callMembers) {
      if (m.userId.isNotEmpty && m.userId != callerIdResolved) {
        calleeIdResolved = m.userId;
        break;
      }
    }
    if (callerIdResolved.isNotEmpty &&
        calleeIdResolved != null &&
        calleeIdResolved.isNotEmpty) {
      final isOutgoing = callerIdResolved == _currentUser?.id;
      // ignore: unawaited_futures
      StreamCallLogger.instance.recordStart(
        cid: cid,
        callerId: callerIdResolved,
        calleeId: calleeIdResolved,
        isOutgoing: isOutgoing,
      );
      if (refined == app_call.CallStatus.answered) {
        // ignore: unawaited_futures
        StreamCallLogger.instance.recordAnswered(cid);
      }
    }

    // Pin the canonical "call started" timestamp the first time we see the
    // call connected. The call screen reads from this so its on-screen
    // counter is independent of any local Timer drift.
    if (refined == app_call.CallStatus.answered) {
      final firstConnect = _callConnectedAt == null;
      _callConnectedAt ??= DateTime.now();
      // Post / refresh the CallStyle notification with the current best
      // name. We re-fire on every state-change while answered so when the
      // SFU finally surfaces participant.name (which lags behind the
      // initial Connected status by 1-2 events) the notification picks
      // up the real name instead of being stuck on the placeholder
      // 'Unknown'. The native side caches by NOTIFICATION_ID so this is
      // a cheap update — no flash, no reordering.
      final notifName = mirror.userName.isNotEmpty &&
              mirror.userName != 'Unknown'
          ? mirror.userName
          : (_callerHint?.userName ?? 'On call');
      if (firstConnect || notifName != _lastShownNotifName) {
        _lastShownNotifName = notifName;
        debugPrint('[STREAM-CALL]   CallStyle show/refresh  name="$notifName"  '
            'firstConnect=$firstConnect');
        // ignore: unawaited_futures
        StreamCallStyleNotifier.instance.show(
          callId: state.callCid.value,
          callerName: notifName,
          connectedAt: _callConnectedAt!,
        );
      }
    }

    final isTerminal = refined == app_call.CallStatus.ended ||
        refined == app_call.CallStatus.declined ||
        refined == app_call.CallStatus.missed;

    if (isTerminal && _terminalLingerTimer == null) {
      // Keep the mirror around for 2s so the pill/screen can show "Call
      // ended" / "Call declined" gracefully, then wipe everything.
      debugPrint('[STREAM-CALL]   terminal status $refined — lingering 2s');

      // Finalise the call-history row in local SQLite. Pass the disconnect
      // reason through verbatim so the logs screen can render "declined" /
      // "missed" / "ended" without needing a server round-trip.
      final terminalReason = state.status is CallStatusDisconnected
          ? (state.status as CallStatusDisconnected).reason.toString()
          : null;
      // ignore: unawaited_futures
      StreamCallLogger.instance.recordTerminal(
        cid: state.callCid.value,
        status: refined,
        reason: terminalReason,
      );

      // Belt-and-braces: dismiss any incoming-call notification still showing
      // on this device (the SDK normally does this, but if our caller
      // abandoned the call before the SDK delivered the cancel event, the
      // notification can otherwise stick around).
      try {
        // ignore: unawaited_futures
        _client?.pushNotificationManager
            ?.endCallByCid(state.callCid.value);
      } catch (_) {}

      // Drop our CallStyle notification immediately on disconnect.
      // ignore: unawaited_futures
      StreamCallStyleNotifier.instance.hide();

      _terminalLingerTimer = Timer(const Duration(seconds: 2), () {
        _terminalLingerTimer = null;
        _clearMirror();
      });
    }
  }

  app_call.CallStatus _mapStreamStatus(CallStatus s) {
    // Order matters — subtypes first.
    if (s is CallStatusReconnecting) return app_call.CallStatus.connecting;
    if (s is CallStatusConnecting) return app_call.CallStatus.connecting;
    if (s is CallStatusJoining) return app_call.CallStatus.connecting;
    if (s is CallStatusJoined) return app_call.CallStatus.answered;
    if (s is CallStatusConnected) return app_call.CallStatus.answered;
    if (s is CallStatusOutgoing) return app_call.CallStatus.ringing;
    if (s is CallStatusIncoming) return app_call.CallStatus.ringing;
    if (s is CallStatusIdle) return app_call.CallStatus.initiated;
    if (s is CallStatusDisconnected) return app_call.CallStatus.ended;
    return app_call.CallStatus.initiated;
  }

  CallParticipantState? _firstRemoteParticipant(CallState state) {
    for (final p in state.callParticipants) {
      if (p.userId != _currentUser?.id) return p;
    }
    return null;
  }

  void _clearMirror() {
    debugPrint('[STREAM-CALL] _clearMirror() — wiping active call mirror');
    _terminalLingerTimer?.cancel();
    _terminalLingerTimer = null;
    _activeCall = null;
    _streamCall = null;
    _callerHint = null;
    _callConnectedAt = null;
    _joinedCid = null;
    _lastShownNotifName = null;
    _isTerminating = false;
    // Belt-and-braces: ensure no stale CallStyle notification or ringtone
    // survives. Both are idempotent — calling them when already cleared
    // is cheap.
    // ignore: unawaited_futures
    StreamCallStyleNotifier.instance.hide();
    // ignore: unawaited_futures
    StreamCallRingtones.instance.stopAll();
  }

  void _maybePushCallScreen(Call call) {
    final nav = NavigationHelper.navigator;
    if (nav == null) {
      debugPrint('[STREAM-CALL]   _maybePushCallScreen: no navigator yet');
      return;
    }
    if (StreamCallScreen.isMounted) {
      debugPrint('[STREAM-CALL]   _maybePushCallScreen: already mounted, skip');
      return;
    }
    // Try to derive a hint from the call's known members so the screen has a
    // name/avatar before any participant-joined event arrives.
    final hint = _callerHint ?? _hintFromCall(call);
    debugPrint('[STREAM-CALL]   _maybePushCallScreen: pushing screen for '
        '${call.callCid.value}  hint=${hint?.userName}');
    nav.push(MaterialPageRoute(
      builder: (_) => StreamCallScreen(call: call, callerHint: hint),
      fullscreenDialog: true,
    ));
  }

  CallerHint? _hintFromCall(Call call) {
    try {
      final s = call.state.value;
      for (final m in s.callMembers) {
        if (m.userId != s.currentUserId) {
          return CallerHint(
            userId: m.userId,
            userName: (m.name?.isNotEmpty ?? false) ? m.name : null,
            userProfilePic: m.image,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ---- Lifecycle ----------------------------------------------------------

  @override
  Future<void> initiateCall(
    String calleeId,
    String calleeName,
    String? calleeProfilePic, {
    bool video = false,
  }) async {
    debugPrint('[STREAM-CALL] ▶ initiateCall(calleeId=$calleeId, '
        'name=$calleeName, video=$video)');

    if (!_isInitialized) {
      debugPrint('[STREAM-CALL]   not initialised yet — calling initialize() first');
      await initialize();
    }
    if (_client == null) {
      debugPrint('[STREAM-CALL] ✗ client is null after init — aborting');
      throw StateError('Stream client not initialised — check STREAM_API_KEY');
    }

    // Optional pre-flight — mirrors the WebRTC backend's `call_access` gate.
    try {
      debugPrint('[STREAM-CALL]   POST /call/stream/precheck …');
      final accessToken = await _cookieService.getAccessToken();
      final res = await _dio.post(
        '${Environment.baseUrl}/call/stream/precheck',
        data: {'callee_id': calleeId},
        options: Options(
          headers: {if (accessToken != null) 'Authorization': 'Bearer $accessToken'},
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      debugPrint('[STREAM-CALL]   precheck → ${res.statusCode}');
    } on DioException catch (e) {
      final msg = e.response?.data?['message']?.toString() ?? 'Cannot place call';
      debugPrint('[STREAM-CALL] ✗ precheck failed: ${e.response?.statusCode} $msg');
      throw StateError(msg);
    }

    final callId = const Uuid().v4();
    final call = _client!.makeCall(
      callType: StreamCallType.defaultType(),
      id: callId,
    );
    debugPrint('[STREAM-CALL]   makeCall() → cid=${call.callCid.value} (id=$callId)');

    // Seed the mirror immediately so the UI can show "calling …" while we
    // await the server round-trip.
    _activeCall = app_call.ActiveCallState(
      callId: call.callCid.value,
      userId: calleeId,
      userName: calleeName,
      userProfilePic: calleeProfilePic,
      callType: app_call.CallType.outgoing,
      status: app_call.CallStatus.ringing,
      startTime: DateTime.now(),
    );
    _callerHint = CallerHint(
      userId: calleeId,
      userName: calleeName,
      userProfilePic: calleeProfilePic,
    );

    // IMPORTANT: only pass the callees in `memberIds`. The caller is already
    // implicitly a member as the call's creator. Including them as an
    // explicit member triggers Stream's coordinator to emit a
    // `StreamCallRejectedEvent{rejectedByUserId: <caller>}` on certain
    // ringing edge paths (the caller-as-member is treated as "didn't pick
    // up"), which marks the call as `Disconnected{Rejected{caller}}` ~1s
    // after getOrCreate. The SDK's `_clear()` then cancels the in-flight
    // `call.join()` with "connect cancelled" and the call dies before the
    // callee even sees the ring.
    // Stamp `amigo_video_call` into the call's custom data. Stream's
    // `settings.video.enabled` is a per-call-TYPE setting (always true for
    // the default call type) — it does NOT reflect the per-call `video`
    // flag, so we cannot use it to distinguish voice vs video calls on the
    // callee side. Custom data round-trips through the coordinator so both
    // ends can read the same flag.
    debugPrint('[STREAM-CALL]   getOrCreate(members=[$calleeId], '
        'ringing=true, video=$video, custom={amigo_video_call: $video}) …');
    final result = await call.getOrCreate(
      memberIds: [calleeId],
      ringing: true,
      video: video,
      custom: {'amigo_video_call': video},
    );

    result.fold(
      success: (data) {
        // Log everything Stream returned so we can confirm the ring was
        // actually requested and the callee is in `members`. If `members`
        // doesn't contain $calleeId, the coordinator has nobody to push the
        // FCM to. If `ringing` isn't set on the call settings, no push
        // gets fanned out at all.
        try {
          final s = call.state.value;
          debugPrint('[STREAM-CALL]   ✓ getOrCreate succeeded  cid=${call.callCid.value}');
          debugPrint('[STREAM-CALL]     members=${s.callMembers.map((m) => m.userId).toList()}');
          debugPrint('[STREAM-CALL]     createdByMe=${s.createdByMe}  '
              'createdByUserId=${s.createdByUserId}  status=${s.status.runtimeType}');
          debugPrint('[STREAM-CALL]     isRingingFlow=${s.isRingingFlow}  '
              'startedAt=${s.startedAt}');
          debugPrint('[STREAM-CALL]   Stream should now push FCM to $calleeId. '
              'If callee never gets it: check Dashboard → Push Providers '
              '(Firebase) is configured and the callee user has a registered '
              'device token (via the SDK\'s pushNotificationManager).');
        } catch (e) {
          debugPrint('[STREAM-CALL]   could not introspect call state: $e');
        }
        _streamCall = call;
        // Drive the outgoing ringback ourselves — `state.activeCall` does
        // not fire until the caller calls `join()`, so we cannot rely on
        // _onCallStateChanged firing during the ring phase. Same reason
        // we attach a state listener directly here: the existing
        // _activeCallSub-based wiring won't kick in until accept+join.
        _attachCallEventLogging(call);
        _callStateSub?.cancel();
        _callStateSub = call.state.listen(_onCallStateChanged);
        // ignore: unawaited_futures
        StreamCallRingtones.instance.playOutgoing();
        _maybePushCallScreen(call);
      },
      failure: (failure) {
        debugPrint('[STREAM-CALL] ✗ getOrCreate failed: ${failure.error.message}');
        _clearMirror();
        throw StateError(failure.error.message);
      },
    );
  }

  @override
  Future<void> acceptCall({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerProfilePic,
  }) async {
    final t0 = DateTime.now();
    debugPrint('[STREAM-CALL] ▶ acceptCall(callId=$callId)  t=$t0');
    final call = _streamCall ?? _client?.state.activeCall.valueOrNull;
    if (call == null) {
      debugPrint('[STREAM-CALL] ✗ acceptCall: no incoming call to accept');
      return;
    }
    final cid = call.callCid.value;
    final preStatus = call.state.value.status;
    debugPrint('[STREAM-CALL]   accepting cid=$cid  preStatus=${preStatus.runtimeType}  '
        'me=${_currentUser?.id}');
    _attachCallEventLogging(call);

    // Cut the ringtone immediately on the user's intent to accept — don't
    // wait for the SDK's status transition to fire. The transition can
    // lag 100-300ms behind the tap and the user reads that gap as "the
    // ringtone kept playing after I picked up".
    // ignore: unawaited_futures
    StreamCallRingtones.instance.stopAll();

    final accept = await call.accept();
    final dt = DateTime.now().difference(t0).inMilliseconds;
    accept.fold(
      success: (_) async {
        final postStatus = call.state.value.status;
        debugPrint('[STREAM-CALL]   ✓ accept() ok in ${dt}ms — '
            'postStatus=${postStatus.runtimeType} — joining…');
        final join = await call.join();
        join.fold(
          success: (_) {
            debugPrint('[STREAM-CALL]   ✓ join() ok — pushing call screen');
            _maybePushCallScreen(call);
          },
          failure: (f) => debugPrint('[STREAM-CALL] ✗ join failed: '
              'type=${f.error.runtimeType}  message="${f.error.message}"  full=${f.error}'),
        );
      },
      failure: (f) => debugPrint('[STREAM-CALL] ✗ accept failed in ${dt}ms — '
          'type=${f.error.runtimeType}  message="${f.error.message}"  full=${f.error}'),
    );
  }

  @override
  Future<void> declineCall({String? reason, String? callId}) async {
    debugPrint('[STREAM-CALL] ▶ declineCall(reason=$reason, callId=$callId)  '
        'me=${_currentUser?.id}');
    // Stop the ringtone on user intent — same reason as acceptCall: the
    // SDK's status transition can lag the tap.
    // ignore: unawaited_futures
    StreamCallRingtones.instance.stopAll();
    final call = _streamCall ?? _client?.state.activeCall.valueOrNull;
    if (call == null) {
      debugPrint('[STREAM-CALL]   no active call to decline');
      return;
    }
    debugPrint('[STREAM-CALL]   reject() on cid=${call.callCid.value}  '
        'preStatus=${call.state.value.status.runtimeType}');
    final res = await call.reject();
    debugPrint('[STREAM-CALL]   reject() → success=${res.isSuccess}  '
        'postStatus=${call.state.value.status.runtimeType}');
    _clearMirror();
  }

  @override
  Future<void> endCall({String? reason}) async {
    debugPrint('[STREAM-CALL] ▶ endCall(reason=$reason)  terminating=$_isTerminating  '
        'me=${_currentUser?.id}');
    if (_isTerminating) return;
    _isTerminating = true;
    // Belt-and-braces ringtone stop. endCall covers the caller-cancels-
    // before-pickup path where the outgoing ringback is still pulsing.
    // ignore: unawaited_futures
    StreamCallRingtones.instance.stopAll();
    final call = _streamCall ?? _client?.state.activeCall.valueOrNull;
    if (call != null) {
      debugPrint('[STREAM-CALL]   leave() on cid=${call.callCid.value}  '
          'preStatus=${call.state.value.status.runtimeType}');
      final res = await call.leave();
      debugPrint('[STREAM-CALL]   leave() → success=${res.isSuccess}');
    }
    _clearMirror();
  }

  @override
  Future<void> toggleMute() async {
    final call = _streamCall ?? _client?.state.activeCall.valueOrNull;
    if (call == null) return;
    final isMuted = _activeCall?.isMuted ?? false;
    await call.setMicrophoneEnabled(enabled: isMuted /* flipping */);
    _activeCall = _activeCall?.copyWith(isMuted: !isMuted);
  }

  @override
  Future<void> toggleSpeaker() async {
    // Stream's prebuilt UI ships its own speaker toggle. We additionally route
    // audio at the OS level so the WebRTC engine actually flips output.
    final newSpeaker = !(_activeCall?.isSpeakerOn ?? false);
    try {
      await Helper.setSpeakerphoneOn(newSpeaker);
    } catch (e) {
      debugPrint('[STREAM CALL] setSpeakerphoneOn failed: $e');
    }
    _activeCall = _activeCall?.copyWith(isSpeakerOn: newSpeaker);
  }

  @override
  Future<void> restoreCallState(
    String callId,
    String callerId,
    String callerName,
    String? callerProfilePic,
  ) async {
    // No-op: Stream's push notification manager owns the killed-state revival
    // path. The active call surfaces via `state.activeCall` once the SDK boots.
  }

  /// Tear down for sign-out. Must be called from the auth logout flow so the
  /// next login can re-bind the StreamVideo client to the new user identity
  /// — otherwise the previous user's name/PFP keeps appearing on outgoing
  /// calls placed under the new login.
  Future<void> dispose() async {
    debugPrint('[STREAM-CALL] ▶ dispose()  user=${_currentUser?.id}');
    await _activeCallSub?.cancel();
    await _incomingCallSub?.cancel();
    await _callStateSub?.cancel();
    await _coreRingingSub?.cancel();
    await _connectionSub?.cancel();
    await _callEventsSub?.cancel();
    await _ringingEventsSub?.cancel();
    _activeCallSub = null;
    _incomingCallSub = null;
    _callStateSub = null;
    _coreRingingSub = null;
    _connectionSub = null;
    _callEventsSub = null;
    _ringingEventsSub = null;
    try {
      await _client?.disconnect();
    } catch (_) {}
    _client = null;
    _currentUser = null;
    _isInitialized = false;
    StreamCallLogger.instance.clear();
    _clearMirror();
  }
}
