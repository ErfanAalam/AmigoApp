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
import '../../../types/socket.types.dart';
import '../../../utils/call.utils.dart';
import '../../../utils/navigation-helper.util.dart';
import '../../../utils/user.utils.dart';
import '../../cookies.service.dart';
import '../../socket/transport.manager.dart';
import '../../socket/transport.service.dart';
import '../../socket/ws-message.handler.dart';
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
  // Singleton handle on Amigo's authenticated WS. Used to fire `call:terminate`
  // alongside the Stream-side end/leave/reject so the backend can update its
  // call_history row and reach the other party via FCM if they're offline.
  final TransportManager _transportManager = TransportManager();

  StreamVideo? _client;
  app_user.UserModel? _currentUser;

  app_call.ActiveCallState? _activeCall;
  Call? _streamCall;

  /// Display info for the remote party. Set on outgoing calls (from the chat
  /// row) and on incoming calls (from the call's member metadata) so the
  /// screen can render before the first participant-joined event lands.
  CallerHint? _callerHint;
  CallerHint? get callerHint => _callerHint;

  /// The peer user id we've already attempted a saved-contact-name lookup for
  /// on the current call (result baked into [_callerHint].contactName). Guards
  /// against repeating the DB lookup on every state event. Reset per call in
  /// [_clearMirror].
  String? _contactNameResolvedForId;

  /// Closes the double-push race opened by the contact-name lookup `await` in
  /// [_maybePushCallScreen] (set while a push is being prepared).
  bool _pushingCallScreen = false;

  /// Reactively-resolved saved-contact name for the current call's peer (null
  /// when the peer isn't a saved contact or isn't resolved yet). The call
  /// screen listens to this so a *late* resolution — e.g. a cold-start accept
  /// where the peer's user id only becomes known after the screen is already
  /// pushed — still updates the displayed name. The screen snapshots
  /// [_callerHint] at construction, so a plain field mutation wouldn't reach it.
  /// Reset per call in [_clearMirror].
  final ValueNotifier<String?> peerContactName = ValueNotifier<String?>(null);

  /// Single source of truth for "when did this call become connected?" Both
  /// the call screen and the ongoing-call notification read this so the two
  /// timers stay in lock-step (and survive notification dismissal).
  /// Set once when status first flips to a joined/connected state, cleared
  /// in [_clearMirror].
  DateTime? _callConnectedAt;
  DateTime? get callConnectedAt => _callConnectedAt;

  /// Tracks the cid we've issued `join()` for — guards against double-join.
  String? _joinedCid;
  /// Safety net for the audio-ready gate below. We delay pinning
  /// [_callConnectedAt] until a remote participant has audio enabled (i.e.
  /// media is actually flowing — not just signaling). If the remote joins
  /// muted, or our heuristic never matches for some reason, this timer fires
  /// after 8s and pins the anchor anyway so the timer can't sit on
  /// "Connecting…" forever.
  Timer? _audioReadyFallbackTimer;
  /// Hard cap on how long a call may ring before we force-terminate it.
  /// Stream's built-in outgoing auto-cancel only arms inside the join flow,
  /// but this app defers `join()` until the callee accepts (fast-join on the
  /// accept event), so the SDK timer never runs during the ring phase and the
  /// caller would otherwise ring ("turr turr") indefinitely. This client
  /// watchdog backstops BOTH ends — the caller (outgoing ring) and the callee
  /// (incoming ring) — and terminates the call with reason "timeout" at 30s.
  static const Duration _ringTimeout = Duration(seconds: 30);
  Timer? _ringWatchdogTimer;

  /// True for the current/just-ended call when it was torn down by the ring
  /// watchdog (or a peer's `timeout` terminate) rather than an active decline
  /// or hang-up. Drives the "Call timeout" overlay copy on BOTH ends. A
  /// `ValueNotifier` (not a plain bool) so the disconnect overlay can flip its
  /// label reactively if the WS `timeout` signal lands a beat after the Stream
  /// `Rejected` event that first paints the overlay. Reset when a new call
  /// begins, NOT in `_clearMirror` — the overlay reads it during its 2s linger
  /// after the mirror is already gone.
  final ValueNotifier<bool> endedByTimeout = ValueNotifier<bool>(false);

  // ── Ghost-call recovery (G-side: we're the party still in the call) ───────
  // The rejoin window is now SERVER-AUTHORITATIVE: the backend detects the
  // peer's socket drop instantly (no client SFU/presence heuristics), opens a
  // 30s window, and drives every transition via WS push —
  //   • `call:rejoin:peer_dropped` → show "Reconnecting…"   (_onPeerDropped)
  //   • `call:rejoin:expired{rejoined}` → "Reconnected"      (_onPeerReturned)
  //   • `call:rejoin:expired{expired}` + `call:terminate`    → end the call
  // So this side no longer detects drops/returns itself or runs a local
  // end-of-window timer; it just renders what the server says.
  /// The cid we're currently showing a "Reconnecting…" banner for (null = none).
  String? _rejoinWindowCid;
  /// UI safety net only: clears a stuck banner (and ends the call as a backstop)
  /// if no authoritative server signal arrives shortly after the 30s window.
  Timer? _rejoinHoldTimer;
  /// Grace beyond the server's 30s window before the local safety net fires.
  static const Duration _rejoinSafety = Duration(seconds: 35);
  /// cids the local user (L) dropped from that are awaiting an explicit rejoin
  /// decision (the blurred dialog). While a cid is here, [_maybePushCallScreen]
  /// will NOT auto-surface the call screen — we wait for the user to tap Rejoin.
  final Set<String> _suppressAutoPushCids = <String>{};
  /// cids for which an Amigo `call:terminate` was received — guards against a
  /// late rejoin push re-showing the banner after a clean hangup.
  final Set<String> _terminateReceivedForCid = <String>{};
  /// Drives the in-call "Reconnecting…" banner (peer name, or null = hidden).
  final ValueNotifier<String?> reconnectingPeerName = ValueNotifier<String?>(null);
  /// Briefly true after the peer returns → drives a "Call reconnected" flash.
  final ValueNotifier<bool> reconnectedFlash = ValueNotifier<bool>(false);
  Timer? _reconnectedFlashTimer;

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
  // Subscription to Amigo's own WS `call:terminate` stream. We listen here
  // (in addition to the in-house `CallService`) because the legacy listener
  // gates on its own `_activeCall` field, which is always null while
  // StreamCallService owns the call — so it silently drops every Stream
  // termination broadcast. Without this subscription the callee keeps
  // ringing whenever Stream's coordinator-side cancel doesn't reach the
  // device's Stream SDK in time (e.g. WS not yet connected, app cold-
  // started via FCM, push-but-no-WS race).
  StreamSubscription<CallPayload>? _amigoTerminateSub;
  // Ghost-call recovery — drive the waiter's "Reconnecting…" banner from prompt
  // out-of-band signals (backend peer-dropped push + peer presence-offline),
  // not just the slow SFU participant-left event.
  StreamSubscription<CallPayload>? _amigoPeerDroppedSub;
  StreamSubscription<CallPayload>? _amigoRejoinExpiredSub;
  /// Re-announces `call:connected` when the chat WS reconnects mid-call, so the
  /// backend resolves any rejoin window it opened on our brief socket drop.
  StreamSubscription<TransportConnectionState>? _transportReconnectSub;

  bool _isInitialized = false;
  bool _isTerminating = false;

  /// True while we're actively answering a call (from the accept button or the
  /// CallKit/notification accept). Cheap guard for the app-swipe teardown:
  /// answering over the lockscreen recreates the Android FlutterActivity, which
  /// fires `onPlatformUiLayerDestroyed` (activity detach) — this flag stops
  /// that teardown from killing the call being answered.
  bool _answering = false;

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
      _bindAmigoTerminateSubscription();
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
              _answering = true;
              _streamCall = call;
              _callerHint = _hintFromCall(call);
              // Attach the events logger immediately — the activeCall stream
              // may not have fired yet, and this is the path most likely to
              // surface the WS-vs-HTTP race we patched in vendor/.
              _attachCallEventLogging(call);
              // Drive the service mirror from this path too: the activeCall
              // stream may not fire promptly on cold-start, and without this
              // _onCallStateChanged never runs so the answer/disconnect
              // refinement (and our drop detection) is blind.
              _callStateSub?.cancel();
              _callStateSub = call.state.listen(_onCallStateChanged);
              // CRITICAL: Stream's consume helper accepts but never joins.
              // Without this the SFU connection is never established and mic
              // stays dead even though the UI shows "Connected".
              await ensureJoined(call);
              _answering = false;
              unawaited(_maybePushCallScreen(call));
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

  /// Sets the per-call screen behavior mode on the native side. See
  /// `MainActivity.setCallScreenMode` for the per-mode contract.
  ///
  /// Modes:
  ///   - `'audio'`: proximity sensor turns the screen off near the ear;
  ///     idle daemon NOT inhibited (screen still dims when ignored).
  ///   - `'video'`: keeps the screen on for the duration of the call,
  ///     same mechanism a video player uses; proximity disabled.
  ///   - `'none'`: releases both. Call this on _ActiveCallView dispose.
  Future<void> setCallScreenMode(String mode) async {
    try {
      await _lockScreenChannel.invokeMethod('setCallScreenMode', {'mode': mode});
      debugPrint('[STREAM-CALL]   setCallScreenMode($mode)');
    } catch (e) {
      debugPrint('[STREAM-CALL]   setCallScreenMode($mode) failed: $e');
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
        // Cheap insurance: if we're mid-answer this detach is an activity swap
        // (e.g. answering over the lockscreen recreates the activity), not a
        // swipe-from-recents — don't tear down the call being answered.
        if (_answering) {
          debugPrint('[STREAM-CALL] onPlatformUiLayerDestroyed — answering in '
              'progress, ignoring (activity swap, not a swipe-away)');
          return;
        }
        // A genuine swipe-from-recents kills the process moments after this
        // fires, so we act SYNCHRONOUSLY here (a deferred timer would die with
        // the process before signalling anything).
        final status = call.state.value.status;
        final createdByMe = call.state.value.createdByMe;
        final cid = call.callCid.value;
        // Was this a live, connected call? If so it's RECOVERABLE: keep the
        // Stream session alive (leave, never end) and open a rejoin window so
        // we can come back from the call-logs dot after restarting.
        final wasConnected = _callConnectedAt != null;
        debugPrint('[STREAM-CALL] onPlatformUiLayerDestroyed — app removed from '
            'recents (cid=$cid wasConnected=$wasConnected) — '
            '${wasConnected ? "leaving + opening rejoin window" : "cancelling"}');
        try {
          if (wasConnected) {
            // Best-effort fast path: tell the backend WE are the dropper but
            // may return. This is now redundant with the backend's own
            // socket-close detection (which is authoritative and instant), so
            // it's fine if this frame doesn't flush before the process is
            // reaped — the server opens the window either way.
            _sendRejoinWs(WSMessageType.callRejoinOpen, cid, {
              'initiated_by': 'leaver',
              'window_ms': 30000,
              // peer_* describe the party still in the call (who we'd rejoin).
              'peer_id': _activeCall?.userId,
              'peer_name': _activeCall?.userName,
              'peer_pfp': _activeCall?.userProfilePic,
            });
            // leave() (NOT end()) even if we created the call — ending would
            // tear it down for the peer and there'd be nothing to rejoin.
            await call.leave();
          } else if (status is CallStatusOutgoing ||
              status is CallStatusIncoming) {
            // Pre-connect (still ringing) — not recoverable; cancel cleanly so
            // the backend clears busy and the peer stops ringing.
            _sendCallTerminateWs('backgrounded');
            await call.reject(
              reason: createdByMe
                  ? CallRejectReason.cancel()
                  : CallRejectReason.decline(),
            );
          } else {
            _sendCallTerminateWs('backgrounded');
            await call.leave();
          }
        } catch (e) {
          debugPrint('[STREAM-CALL]   swipe teardown threw: $e — falling back to leave');
          try {
            await call.leave();
          } catch (_) {}
        }
        // NOTE: deliberately NOT calling `_client.disconnect()` here. The
        // vendored SDK's disconnect() calls pushNotificationManager
        // .unregisterDevice() → deleteDevice(<FCM token>), which DELETES this
        // device's push registration at Stream — after which Stream sends NO
        // `call.ring` FCM until a cold restart re-registers it, so the user
        // gets NO incoming-call notification. The process death closes the WS
        // on its own; the coordinator detects the dropped socket. Keeping the
        // device registered is what lets the very next call still ring.
        // Drop the CallStyle notification deterministically — without
        // StreamBackgroundService managing the call lifecycle, we own
        // dismissal end-to-end.
        // ignore: unawaited_futures
        StreamCallStyleNotifier.instance.hide();
        // Wipe the mirror synchronously (consistent with every other teardown
        // path) so no stale _streamCall/_activeCall lingers if the process
        // isn't killed immediately.
        _clearMirror();
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
    // Hard guard against joining a terminal call. Without this, the screen's
    // 2-second-linger rebuild after a reject(cancel) calls ensureJoined,
    // which then calls `call.join()` → `getUserMedia(audio)` → mic captured
    // → 3 failed attempts (the call is dead at Stream's side) → the
    // captured MediaStream is never disposed because the SDK's join path
    // owned it and never reached the cleanup branch. Net result: mic
    // remains held by our process even after the call screen pops, which
    // is the "I can't play music until I close Amigo" symptom.
    //
    // `CallStatusDisconnected` covers Rejected / Cancelled / Ended /
    // Failure / Replaced / Timeout — none of which should ever trigger
    // a join. `CallStatusReconnectionFailed` is also terminal.
    if (status is CallStatusDisconnected || status is CallStatusReconnectionFailed) {
      debugPrint('[STREAM-CALL]   ensureJoined: $cid is terminal '
          '(${status.runtimeType}) — refusing to join');
      _joinedCid = null;
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
    String joinErrMsg = '';
    res.fold(
      success: (_) => debugPrint('[STREAM-CALL]   ensureJoined: join SUCCESS'),
      failure: (f) {
        joinErrMsg = f.error.message;
        debugPrint('[STREAM-CALL]   ensureJoined: join FAILED — '
            'type=${f.error.runtimeType} '
            'message="${f.error.message}" '
            'full=${f.error}\n'
            'stack=${f.error.stackTrace}');
      },
    );
    if (res.isFailure) {
      // CRITICAL: a notification/CallKit accept makes the SDK's own accept
      // handler call accept()+join() FIRST; our `observeCoreRingingEvents.
      // onCallAccepted` then calls ensureJoined → a SECOND join() that fails
      // with "a call with the same cid is in progress". That is NOT a real
      // failure — the SDK's in-flight join owns the call and will complete.
      // We must NOT leave() here: leaving cancels the in-flight join
      // (`Cancelled{byUserId: <self>}`), which kills the callee's call and
      // strands the caller in a ghost call. Defer to the winning join.
      final lower = joinErrMsg.toLowerCase();
      if (lower.contains('in progress') || lower.contains('already')) {
        debugPrint('[STREAM-CALL]   ensureJoined: a join for $cid is already '
            'in progress — deferring to it, NOT leaving (avoids cancelling '
            'the live call)');
        _joinedCid = cid; // the in-flight join will bring us to joined
        return;
      }
      _joinedCid = null;
      // Genuine failure. `call.join()` may have partially set up the SFU
      // session — including `getUserMedia`, which captures the device mic.
      // The SDK generally tears that down on its own failure path, but the
      // "failed to join after 3 attempts" code path observed in the wild
      // can leave the MediaStream/audio track owned by our process if the
      // call transitioned to Disconnected mid-attempt. Force a `leave()`
      // here to drive the SDK through its session-dispose path — it's
      // a no-op if the SDK already cleaned up, and releases the mic if
      // it didn't.
      try {
        await call.leave();
      } catch (e) {
        debugPrint('[STREAM-CALL]   ensureJoined: post-failure leave() '
            'threw: $e');
      }
      return;
    }
    // Do NOT call setMicrophoneEnabled/setCameraEnabled here. `audioOnlyConnect`
    // already specifies the correct track state for join(); calling the
    // setters again triggers a second `getUserMedia` and republishes the
    // audio track, which the SFU treats as a track replacement and the
    // callee-side ends up Reconnecting → Disconnected within milliseconds
    // of connecting.

    // Force the audio output to OUR default rather than whatever the
    // Stream SDK picked from the call-type dashboard settings. The SDK's
    // `_applyCallSettingsToConnectOptions` respects per-call-type
    // `speakerDefaultOn` / `defaultDevice` flags, which were defaulting
    // our audio calls to loudspeaker — bad UX (and not what users expect
    // for a phone call). Policy here:
    //   1. External device (BT / wired) — always wins when connected.
    //   2. Otherwise: earpiece for audio calls, speaker for video calls.
    // The user can still flip output via the in-call picker.
    try {
      final devicesRes = await RtcMediaDeviceNotifier.instance.audioOutputs();
      final outputs = devicesRes.getDataOrNull() ?? const <RtcMediaDevice>[];
      RtcMediaDevice? target;
      for (final d in outputs) {
        if (d.isExternal) { target = d; break; }
      }
      if (target == null) {
        for (final d in outputs) {
          if (isVideoCall ? d.isSpeaker : d.isEarpiece) {
            target = d;
            break;
          }
        }
      }
      if (target != null) {
        debugPrint('[STREAM-CALL]   ensureJoined: routing audio output → '
            'label="${target.label}" id=${target.id} '
            'external=${target.isExternal} (video=$isVideoCall)');
        await call.setAudioOutputDevice(target);
      } else {
        debugPrint('[STREAM-CALL]   ensureJoined: no audio output target '
            'found among ${outputs.length} devices — leaving SDK default');
      }
    } catch (e, st) {
      debugPrint('[STREAM-CALL]   ensureJoined: audio routing failed: $e\n$st');
    }
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
      unawaited(_maybePushCallScreen(call));
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

      // Busy-on-another safety net (paired with the backend precheck gate).
      // The webhook-driven busy registry on the server *should* block this
      // call from ever being placed, but webhook-vs-coordinator races can
      // still let a second ring slip through (backend hasn't processed the
      // first `call.ring` yet when a third party dials us). Auto-reject
      // with `busy()` so the caller hears the busy tone immediately rather
      // than a 30-second ring-no-answer.
      final existing = _streamCall;
      final newCid = call.callCid.value;
      if (existing != null && existing.callCid.value != newCid) {
        final existingStatus = existing.state.value.status;
        // Don't auto-reject if the prior call is already terminal — the
        // 2-second linger keeps `_streamCall` around for the disconnect
        // animation, and during that window a brand-new incoming call is
        // legitimate.
        final isTerminal = existingStatus is CallStatusDisconnected
            || existingStatus is CallStatusReconnectionFailed;
        if (!isTerminal) {
          debugPrint('[STREAM-CALL] 🚧 busy: incoming $newCid arrived while '
              '${existing.callCid.value} is ${existingStatus.runtimeType} — '
              'auto-rejecting with CallRejectReason.busy()');
          // ignore: unawaited_futures
          call.reject(reason: CallRejectReason.busy());
          return;
        }
        debugPrint('[STREAM-CALL]   incoming $newCid arrived during terminal '
            'linger of ${existing.callCid.value} (${existingStatus.runtimeType}) — '
            'allowing through');
      }

      _streamCall = call;
      _callerHint ??= _hintFromCall(call);
      // Fresh incoming call — clear any leftover timeout flag.
      endedByTimeout.value = false;
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
      // Cap the incoming ring at 30s — see [_ringTimeout]. Backstops the
      // SDK's own auto-reject (which only arms on the CallKit/push path, not
      // this foreground `state.incomingCall` route) so the callee never rings
      // forever when the caller's cancel doesn't reach this device.
      _startRingWatchdog(call, outgoing: false);
      unawaited(_maybePushCallScreen(call));
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
        // Mark answering BEFORE join: this is the background/lockscreen accept,
        // which recreates the activity and fires onPlatformUiLayerDestroyed —
        // the `_answering` guard stops that from tearing down the call.
        _answering = true;
        _streamCall = call;
        _callerHint ??= _hintFromCall(call);
        _attachCallEventLogging(call);
        // Bind the state mirror on THIS path too. Unlike the foreground
        // incomingCall/activeCall listeners, the core-ringing accept path
        // never bound it — so _onCallStateChanged (answer refinement, drop
        // detection, ringtone stop) was blind on background answers.
        _callStateSub?.cancel();
        _callStateSub = call.state.listen(_onCallStateChanged);
        await ensureJoined(call);
        _answering = false;
        unawaited(_maybePushCallScreen(call));
      },
    );

    // Diagnostic-only listener on `pushManager.onCallEvent`. The actual
    // decline → reject path lives inside the SDK: `observeCoreRingingEvents`
    // above already bundles `observeCallDeclinedRingingEvent`, which runs
    // `_onCallDecline` → `consumeIncomingCall(uuid, cid)` → `call.reject(
    // reason: CallRejectReason.decline())` — the canonical primitive Stream's
    // coordinator uses to fan out the rejection to the caller.
    //
    // An earlier iteration of this code ran its own listener that called
    // `client.makeCall(type, id).reject()` on a freshly-made stateless Call.
    // That raced the SDK's own handler: by the time we tried to reject, the
    // broadcast receiver's `removeCall` had already nudged the cached entry,
    // so `consumeIncomingCall` on the SDK side returned null and the SDK's
    // reject got skipped — yet our stateless `reject()` also silently fizzled
    // because the Call had no loaded state. End result: decline-from-
    // notification did nothing, the caller stayed in ringing limbo.
    //
    // Killed/cold state is covered by the Kotlin-side AmigoColdDeclineBridge
    // (vendor/stream_video_push_notification/.../AmigoColdDeclineBridge.kt),
    // which HTTP-POSTs the cid + cached user_id to `/call/stream/decline-cold`
    // — that endpoint then re-signs a one-shot JWT and calls Stream's reject
    // API server-side. So the Dart side only needs to handle warm-path here.
    final pushManager = client.pushNotificationManager;
    if (pushManager != null) {
      debugPrint('[STREAM-CALL]   attaching diagnostic onCallEvent tap '
          '(reject path is owned by observeCoreRingingEvents)');
      _ringingEventsSub?.cancel();
      _ringingEventsSub = pushManager.onCallEvent.listen((event) {
        // `RingingEvent` is the union supertype — the per-action subclasses
        // (ActionCallAccept/Decline/Ended/…) carry the `data.callCid`. We
        // log the runtime type unconditionally to verify the broadcast
        // pipeline is alive; cid logging is best-effort.
        String? cid;
        if (event is ActionCallDecline) {
          cid = event.data.callCid;
        } else if (event is ActionCallAccept) {
          cid = event.data.callCid;
        } else if (event is ActionCallEnded) {
          cid = event.data.callCid;
        } else if (event is ActionCallIncoming) {
          cid = event.data.callCid;
        } else if (event is ActionCallCallback) {
          cid = event.data.callCid;
        }
        debugPrint('[STREAM-CALL] ⮕ pushManager.onCallEvent: '
            '${event.runtimeType}${cid != null ? "  cid=$cid" : ""}');

        // Tap-to-callback from a missed-call notification. The SDK delivers
        // this when the user taps the "Call back" button (or the body, when
        // wired via getCallbackPendingIntent). The original caller's id is
        // in `data.handle` because `handleStreamVideoBackgroundPush` set
        // `handle: createdById` when posting `showMissedCall`.
        if (event is ActionCallCallback) {
          // ignore: unawaited_futures
          _handleMissedCallCallback(event);
        }
      });
    } else {
      debugPrint('[STREAM-CALL]   ⚠ pushManager is null — '
          'SDK ringing-event observers cannot fire');
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
    // Backstop: make sure the peer's saved-contact name is resolved into the
    // hint so pickName()/the CallStyle notification can prefer it. Idempotent
    // (no-ops once resolved for this peer) — safe to call on every event.
    // ignore: unawaited_futures
    _enrichCallerHintWithContact();
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
      // Left the ring phase (answered/joined or terminal) — the 30s ring cap
      // no longer applies.
      _cancelRingWatchdog();
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
      // Caller-side busy tone for the Stream-coordinator-driven reject path.
      // When the callee's auto-reject (busy-on-another safety net above)
      // fires, Stream propagates `CallRejectedEvent{reason: busy}` to us as
      // `DisconnectReasonRejected` carrying the reason string. Playing the
      // tone here covers the case where the backend precheck didn't catch
      // the busy state (e.g. the webhook for the callee's first ring
      // hadn't landed when the precheck ran), so the caller still gets the
      // expected audible cue.
      if (reasonStr.contains('busy')
          && _activeCall?.callType == app_call.CallType.outgoing) {
        debugPrint('[STREAM-CALL]   caller-side busy reject — playing busy tone');
        // ignore: unawaited_futures
        StreamCallRingtones.instance.playBusy();
      }
    }

    // Best-name resolution chain: live SFU participant > existing mirror
    // entry (already enriched) > caller hint (stuffed in by initiateCall /
    // _hintFromCall) > member metadata > 'Unknown'. We avoid landing on
    // 'Unknown' aggressively because the CallStyle notification is built
    // off this and the user complained it stuck on "Unknown".
    String pickName() {
      // A saved device-contact name is authoritative — it overrides the live
      // SFU/server username so the call pill and the ongoing-call notification
      // show the name the user saved the peer under.
      final contactName = _callerHint?.contactName;
      if (contactName != null && contactName.isNotEmpty) return contactName;
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

    // Pin the canonical "call started" timestamp the first time remote
    // audio is actually FLOWING — not just when WE joined the SFU.
    // Stream's Joined/Connected status fires the moment our local signaling
    // is up, but the remote party's media path (ICE/DTLS + subscription)
    // lands ~4-5s later. Anchoring the on-screen timer + ongoing-call
    // notification on the earlier signal made the call feel broken — the
    // timer would tick over 4-5s of silence. We now wait for at least one
    // remote participant with audio enabled, and fall back at 8s so a
    // remote that joined muted doesn't strand us on "Connecting…" forever.
    if (refined == app_call.CallStatus.answered) {
      final remoteAudioReady = state.callParticipants
          .any((p) => !p.isLocal && p.isAudioEnabled);

      if (_callConnectedAt == null && !remoteAudioReady) {
        if (_audioReadyFallbackTimer == null) {
          debugPrint('[STREAM-CALL]   answered but no remote audio yet — '
              'arming 8s audio-ready fallback');
          _audioReadyFallbackTimer = Timer(const Duration(seconds: 8), () {
            _audioReadyFallbackTimer = null;
            if (_callConnectedAt != null) return;
            if (_activeCall?.status != app_call.CallStatus.answered) return;
            if (_streamCall == null) return;
            debugPrint('[STREAM-CALL]   audio-ready fallback fired — '
                'pinning anchor anyway (remote never reported audio enabled)');
            // Pin BEFORE re-entering: otherwise the re-entry sees
            // _callConnectedAt == null && !remoteAudioReady and would just
            // re-arm a fresh 8s timer, looping. With the anchor pinned the
            // re-entry takes the `else` branch and the CallStyle notif
            // fires with the correct connectedAt.
            //
            // We deliberately do NOT run the connect-beep here (unlike the
            // happy-path `firstConnect` block above). The beep is meant to
            // signal "remote audio just went live"; if we ended up in the
            // fallback we have no evidence that audio is actually flowing,
            // so a beep would be misleading. The timer still starts so the
            // UI stops sitting on "Connecting…", but we stay silent.
            _callConnectedAt = DateTime.now();
            _onCallStateChanged(_streamCall!.state.value);
          });
        }
      } else {
        final firstConnect = _callConnectedAt == null;
        if (firstConnect) {
          _callConnectedAt = DateTime.now();
          _audioReadyFallbackTimer?.cancel();
          _audioReadyFallbackTimer = null;
          debugPrint('[STREAM-CALL]   _callConnectedAt pinned  '
              'remoteAudioReady=$remoteAudioReady  '
              'participants=${state.callParticipants.length}');
          // Tell the backend, over the (reliable, alive) chat WS, that this
          // call is now connected and who the peer is. This records the in-call
          // pairing server-side so that if WE later drop (app killed / network
          // lost), the backend's socket-close handler can self-open a rejoin
          // window WITHOUT depending on Stream webhooks (which can't reach a
          // private-IP backend) or on our dying process flushing a frame.
          _sendRejoinWs(WSMessageType.callConnected, state.callCid.value, {
            'peer_id': _activeCall?.userId,
          });
          // Connect beep — fires once, exactly when remote audio actually
          // starts flowing (matches the on-screen timer start). Routes
          // through the in-call audio path so the user hears it on the
          // same output the call itself is using.
          // ignore: unawaited_futures
          StreamCallRingtones.instance.playConnectBeep();
        }
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
            : (_callerHint?.contactName ?? _callerHint?.userName ?? 'On call');
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
    }

    // NOTE: peer-drop / peer-return detection used to live here (off the SFU
    // participant count). It was removed — the SDK's participant list flaps on
    // a silent drop, which produced false "Reconnecting"/"Reconnected". The
    // backend now detects the peer's socket drop instantly and drives the
    // banner via WS push (see _bindAmigoTerminateSubscription / _onPeerDropped).

    final isTerminal = refined == app_call.CallStatus.ended ||
        refined == app_call.CallStatus.declined ||
        refined == app_call.CallStatus.missed;

    if (isTerminal && _terminalLingerTimer == null) {
      // Keep the mirror around for 2s so the pill/screen can show "Call
      // ended" / "Call declined" gracefully, then wipe everything.
      debugPrint('[STREAM-CALL]   terminal status $refined — lingering 2s');

      // (Disconnect beep is fired from `_clearMirror` so user-initiated
      // hangups — which call _clearMirror() directly without ever reaching
      // this block — get the beep too. See the comment there.)

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
    // Disconnect beep — fires here (rather than at the terminal status
    // event in _onCallStateChanged) because user-initiated paths
    // (endCall / declineCall) call _clearMirror() DIRECTLY after
    // call.leave() / call.reject(), which would null `_callConnectedAt`
    // before the SDK's terminal event reached _onCallStateChanged — so
    // the beep would never fire for normal hangups. Centralising it
    // here means every termination path produces exactly one beep
    // (the first _clearMirror invocation nulls `_callConnectedAt`, so
    // any subsequent re-entry from the SDK's terminal event no-ops).
    // The `_callConnectedAt != null` gate still skips calls that ended
    // during ringing (no audio path to play through anyway).
    if (_callConnectedAt != null) {
      // ignore: unawaited_futures
      StreamCallRingtones.instance.playDisconnectBeep();
    }
    _terminalLingerTimer?.cancel();
    _terminalLingerTimer = null;
    _audioReadyFallbackTimer?.cancel();
    _audioReadyFallbackTimer = null;
    _cancelRingWatchdog();
    _cancelRejoinWindow();
    _terminateReceivedForCid.clear();
    _answering = false;
    _activeCall = null;
    _streamCall = null;
    _callerHint = null;
    _contactNameResolvedForId = null;
    peerContactName.value = null;
    // Drop the cold-start name seed so it can't bleed into the next call.
    unawaited(CallUtils().clearIncomingCallSeed());
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

  Future<void> _maybePushCallScreen(Call call) async {
    final nav = NavigationHelper.navigator;
    if (nav == null) {
      debugPrint('[STREAM-CALL]   _maybePushCallScreen: no navigator yet');
      return;
    }
    // Ghost-call recovery: a call we dropped from is awaiting an explicit rejoin
    // decision (the blurred dialog). Don't surface the call screen on our own —
    // the user must tap "Rejoin" first (which clears this and pushes). Stops the
    // "call screen pops up out of nowhere on reopen" behaviour.
    if (_suppressAutoPushCids.contains(call.callCid.value)) {
      debugPrint('[STREAM-CALL]   _maybePushCallScreen: suppressed (awaiting rejoin '
          'decision) for ${call.callCid.value}');
      return;
    }
    if (StreamCallScreen.isMounted || _pushingCallScreen) {
      debugPrint('[STREAM-CALL]   _maybePushCallScreen: already mounted/pushing, skip');
      return;
    }
    _pushingCallScreen = true;
    try {
      // Try to derive a hint from the call's known members so the screen has a
      // name/avatar before any participant-joined event arrives, then resolve
      // the peer's saved-contact name into it (await) BEFORE pushing — the
      // screen snapshots the hint at construction, so it must be enriched first.
      _callerHint ??= _hintFromCall(call);
      // Cold-start accept: the SDK call state often hasn't hydrated the peer's
      // user id yet, so seed it from the FCM record persisted when the
      // incoming-call notification was shown. This lets the contact-name lookup
      // below resolve BEFORE the first paint (no username→contact-name flicker).
      await _seedHintFromPersistedIncomingCall(call);
      await _enrichCallerHintWithContact();
      // Another event may have pushed the screen while we awaited.
      if (StreamCallScreen.isMounted) return;
      final hint = _callerHint;
      debugPrint('[STREAM-CALL]   _maybePushCallScreen: pushing screen for '
          '${call.callCid.value}  '
          'hint=${hint?.contactName ?? hint?.userName}');
      nav.push(MaterialPageRoute(
        builder: (_) => StreamCallScreen(call: call, callerHint: hint),
        fullscreenDialog: true,
      ));
    } finally {
      _pushingCallScreen = false;
    }
  }

  /// Resolve the remote party's saved device-contact name (if any) into the
  /// active [_callerHint] so the call screen and the ongoing-call notification
  /// prefer it over the SFU/server username. Idempotent — it attempts the
  /// lookup at most once per peer per call (tracked by [_contactNameResolvedForId])
  /// and no-ops when the peer isn't a saved contact.
  Future<void> _enrichCallerHintWithContact() async {
    final uid = _peerUserId();
    if (uid == null || uid.isEmpty) return;
    if (_contactNameResolvedForId == uid) return;
    _contactNameResolvedForId = uid;
    final contactName = await UserUtils().preferredContactName(uid, null);
    if (contactName == null || contactName.isEmpty) return;
    // Guard against the call having been cleared while we awaited — _clearMirror
    // nulls _contactNameResolvedForId, so an equal value means we're still live.
    if (_contactNameResolvedForId == uid) {
      _callerHint =
          (_callerHint ?? CallerHint(userId: uid)).copyWith(contactName: contactName);
      // Reactive: updates the already-pushed call screen for the cold-start
      // case where resolution lands after the screen mounted.
      peerContactName.value = contactName;
    }
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
      // Cold-start / sparse member metadata (e.g. accept-from-killed): the
      // member list may be empty, but the call creator IS the remote party on
      // an incoming call. Surface at least the user id so the saved-contact
      // name can still be resolved against the local DB.
      final createdBy = s.createdByUserId;
      if (createdBy.isNotEmpty && createdBy != s.currentUserId) {
        return CallerHint(userId: createdBy);
      }
    } catch (_) {}
    return null;
  }

  /// Cold-start seed: when we don't yet have the peer's user id (the SDK call
  /// state hasn't hydrated members/creator on an accept-from-killed), pull the
  /// caller id + already-resolved display name from the FCM record persisted at
  /// notification time. Keyed by cid so a stale record can't seed a later call.
  Future<void> _seedHintFromPersistedIncomingCall(Call call) async {
    final uid = _callerHint?.userId;
    if (uid != null && uid.isNotEmpty) return; // already have a peer id
    try {
      final seed = await CallUtils().getIncomingCallSeed(call.callCid.value);
      final callerId = seed?['callerId'];
      if (callerId == null || callerId.isEmpty) return;
      _callerHint = (_callerHint ?? const CallerHint()).copyWith(
        userId: callerId,
        userName: seed?['name'],
        userProfilePic: seed?['profilePic'],
      );
    } catch (_) {}
  }

  /// Best-effort remote-party user id for the current call — caller hint first,
  /// then the live Stream call state (a non-self member, else the creator on an
  /// incoming call). This is what we resolve the saved-contact name against, so
  /// it has to work even before member metadata has fully hydrated.
  String? _peerUserId() {
    final hintId = _callerHint?.userId;
    if (hintId != null && hintId.isNotEmpty) return hintId;
    final s = _streamCall?.state.value;
    if (s != null) {
      for (final m in s.callMembers) {
        if (m.userId.isNotEmpty && m.userId != s.currentUserId) return m.userId;
      }
      final createdBy = s.createdByUserId;
      if (createdBy.isNotEmpty && createdBy != s.currentUserId) return createdBy;
    }
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
    // Fresh call — clear any leftover timeout flag from the previous one.
    endedByTimeout.value = false;

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
      final statusCode = e.response?.statusCode;
      final code = e.response?.data?['code']?.toString();
      final msg = e.response?.data?['message']?.toString() ?? 'Cannot place call';
      debugPrint('[STREAM-CALL] ✗ precheck failed: $statusCode code=$code msg=$msg');
      // Busy responses (callee on another call OR caller already engaged):
      // play the telephony busy tone so the user gets the audible cue they
      // expect from a phone, then surface the error to the UI which renders
      // a snackbar. The tone is fire-and-forget — we don't block on it.
      if (statusCode == 409 && (code == 'busy' || code == 'self_busy')) {
        // ignore: unawaited_futures
        StreamCallRingtones.instance.playBusy();
      }
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
        // Cap the outgoing ring at 30s — see [_ringTimeout]. The caller has
        // no SDK auto-cancel during the ring phase (join is deferred until
        // accept), so without this the ringback never stops on no-answer.
        _startRingWatchdog(call, outgoing: true);
        unawaited(_maybePushCallScreen(call));
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
    // User answered — kill the 30s ring cap before it can fire.
    _cancelRingWatchdog();
    // Guard the swipe teardown across the accept→join transition (this tap can
    // also recreate the activity when accepted from the lockscreen UI).
    _answering = true;

    final accept = await call.accept();
    final dt = DateTime.now().difference(t0).inMilliseconds;
    accept.fold(
      success: (_) async {
        final postStatus = call.state.value.status;
        debugPrint('[STREAM-CALL]   ✓ accept() ok in ${dt}ms — '
            'postStatus=${postStatus.runtimeType} — joining…');
        final join = await call.join();
        _answering = false;
        join.fold(
          success: (_) {
            debugPrint('[STREAM-CALL]   ✓ join() ok — pushing call screen');
            unawaited(_maybePushCallScreen(call));
          },
          failure: (f) => debugPrint('[STREAM-CALL] ✗ join failed: '
              'type=${f.error.runtimeType}  message="${f.error.message}"  full=${f.error}'),
        );
      },
      failure: (f) {
        _answering = false;
        debugPrint('[STREAM-CALL] ✗ accept failed in ${dt}ms — '
            'type=${f.error.runtimeType}  message="${f.error.message}"  full=${f.error}');
      },
    );
  }

  /// Rejoin a call we dropped out of (ghost-call recovery). The peer (G) is
  /// holding the call open; we re-`get()` the cid and join its existing SFU
  /// session. [peerId]/[peerName]/[peerPfp] seed the mirror so the call screen
  /// shows the right person before participant metadata arrives. Returns true
  /// if the rejoin was initiated, false if the call was already gone.
  Future<bool> rejoinCall(
    String cid, {
    String? peerId,
    String? peerName,
    String? peerPfp,
  }) async {
    debugPrint('[STREAM-CALL] ▶ rejoinCall(cid=$cid, peer=$peerId)');
    // User explicitly chose to rejoin — stop suppressing the call screen for
    // this cid so the push below (and any SDK activeCall event) can surface it.
    _suppressAutoPushCids.remove(cid);
    if (!_isInitialized) await initialize();
    final client = _client;
    if (client == null) {
      debugPrint('[STREAM-CALL] ✗ rejoinCall: client null');
      return false;
    }
    // Don't rejoin while already in a different live call.
    final existing = _streamCall;
    if (existing != null && existing.callCid.value != cid) {
      final st = existing.state.value.status;
      final terminal =
          st is CallStatusDisconnected || st is CallStatusReconnectionFailed;
      if (!terminal) {
        debugPrint('[STREAM-CALL]   rejoinCall: already in another call — ignoring');
        return false;
      }
    }
    final parts = cid.split(':');
    if (parts.length != 2) {
      debugPrint('[STREAM-CALL] ✗ rejoinCall: malformed cid $cid');
      return false;
    }
    final call = client.makeCall(
      callType: StreamCallType.fromString(parts[0]),
      id: parts[1],
    );
    final got = await call.get();
    if (got.isFailure) {
      debugPrint('[STREAM-CALL]   rejoinCall: call.get() failed — call gone');
      return false;
    }
    final status = call.state.value.status;
    if (status is CallStatusDisconnected ||
        status is CallStatusReconnectionFailed) {
      debugPrint('[STREAM-CALL]   rejoinCall: call already terminal — not rejoining');
      return false;
    }
    _answering = true;
    _streamCall = call;
    final resolvedName =
        (peerName != null && peerName.isNotEmpty) ? peerName : 'Unknown';
    _callerHint = CallerHint(
      userId: peerId ?? '',
      userName: resolvedName,
      userProfilePic: peerPfp,
    );
    _activeCall = app_call.ActiveCallState(
      callId: call.callCid.value,
      userId: peerId ?? '',
      userName: resolvedName,
      userProfilePic: peerPfp,
      callType: app_call.CallType.outgoing,
      status: app_call.CallStatus.connecting,
      startTime: DateTime.now(),
    );
    _attachCallEventLogging(call);
    _callStateSub?.cancel();
    _callStateSub = call.state.listen(_onCallStateChanged);
    await ensureJoined(call);
    _answering = false;
    // We're back in the call — resolve the backend rejoin window so it does NOT
    // expire and terminate the call at 30s, and the peer (G) flips from
    // "Reconnecting…" to "Reconnected". (The firstConnect `call:connected` will
    // also resolve it server-side; this is the direct, immediate signal.)
    _sendRejoinWs(WSMessageType.callRejoinResolved, cid, {'outcome': 'rejoined'});
    unawaited(_maybePushCallScreen(call));
    return true;
  }

  /// True if we're currently, actively joined to [cid] (not terminal). Used on
  /// app-reopen to tell a genuine drop (kill → not in the call → prompt to
  /// rejoin) apart from a brief WS blip (still in the Stream call → just tell
  /// the peer we're back, no dialog).
  bool isActivelyInCall(String cid) {
    final call = _streamCall;
    if (call == null || call.callCid.value != cid) return false;
    final st = call.state.value.status;
    return st is! CallStatusDisconnected &&
        st is! CallStatusReconnectionFailed &&
        st is! CallStatusIdle;
  }

  /// Suppress [_maybePushCallScreen] auto-surfacing [cid] until the user makes
  /// an explicit rejoin decision. Set by the reopen flow BEFORE showing the
  /// rejoin dialog; cleared by [rejoinCall] (Yes) or [clearAwaitingRejoinDecision]
  /// (No / dismissed).
  void markAwaitingRejoinDecision(String cid) => _suppressAutoPushCids.add(cid);
  void clearAwaitingRejoinDecision(String cid) => _suppressAutoPushCids.remove(cid);

  /// We were still in the Stream call when our chat-WS reconnected (a blip, not
  /// a real drop) — tell the backend so it closes the rejoin window and the
  /// peer's "Reconnecting…" clears. No rejoin/dialog needed.
  void notifyStillConnected(String cid) {
    debugPrint('[STREAM-CALL] ↺ still in call after reconnect — resolving rejoin '
        'window cid=$cid');
    _sendRejoinWs(WSMessageType.callRejoinResolved, cid, {'outcome': 'rejoined'});
  }

  /// Subscribe to Amigo's WS `call:terminate` broadcasts and tear down our
  /// Stream call when one arrives that matches our active or incoming call.
  ///
  /// This is belt-and-braces alongside Stream's coordinator-driven cancel
  /// (which the caller triggers via `call.reject(CallRejectReason.cancel())`
  /// in `endCall`). The Amigo broadcast reaches us reliably the moment the
  /// caller's WS send completes; Stream's CallRejectedEvent depends on the
  /// callee being WS-connected to Stream's coordinator at that exact moment,
  /// which isn't always true on the callee side (FCM cold-start race, brief
  /// WS reconnects, etc.). Having both paths means whichever one wins
  /// stops the ring.
  void _bindAmigoTerminateSubscription() {
    final handler = WebSocketMessageHandler();
    _amigoTerminateSub?.cancel();
    _amigoTerminateSub = handler.callTerminateStream.listen(_handleAmigoTerminate);
    // Waiter-side ghost-call recovery signals (see _onPeerDropped):
    _amigoPeerDroppedSub?.cancel();
    _amigoPeerDroppedSub = handler.callRejoinPeerDroppedStream.listen((p) {
      final cid = p.callId;
      if (cid != null) _onPeerDropped(cid);
    });
    // Server-driven resolution of OUR active rejoin window: the backend tells
    // the waiter when the window ends so the "Reconnecting…" banner clears from
    // an authoritative signal, not only the local 30s timer / SFU return event
    // (which can miss). `data.outcome=='rejoined'` → flash "Call reconnected".
    _amigoRejoinExpiredSub?.cancel();
    _amigoRejoinExpiredSub = handler.callRejoinExpiredStream.listen((p) {
      final cid = p.callId;
      if (cid == null || _rejoinWindowCid != cid) return;
      final outcome = p.data?['outcome']?.toString();
      debugPrint('[STREAM-CALL] ⇣ backend rejoin window ended cid=$cid '
          'outcome=$outcome — clearing banner (waiter)');
      if (outcome == 'rejoined') {
        _onPeerReturned(cid);
      } else {
        _cancelRejoinWindow();
      }
    });
    // When OUR chat WS reconnects while we're still in a connected call, the
    // backend may have opened a rejoin window for us (it treats our socket
    // close as a drop). Re-announce `call:connected` so the backend resolves
    // that window instead of expiring it at 30s and killing a healthy call.
    // This covers the brief-WS-blip case where we never left the Stream call,
    // so there's no rejoin action to otherwise resolve the window.
    _transportReconnectSub?.cancel();
    _transportReconnectSub =
        _transportManager.connectionStateStream.listen((s) {
      if (s != TransportConnectionState.connected) return;
      final call = _streamCall;
      if (call == null || _callConnectedAt == null) return;
      final cid = call.callCid.value;
      if (!isActivelyInCall(cid)) return;
      debugPrint('[STREAM-CALL] ↻ chat WS reconnected mid-call — re-announcing '
          'call:connected to resolve any rejoin window  cid=$cid');
      _sendRejoinWs(WSMessageType.callConnected, cid, {
        'peer_id': _activeCall?.userId,
      });
    });
    // NOTE: the peer `connection:status offline` presence trigger was removed.
    // Presence flaps on brief WS blips and is debounced ~8s on the backend, so
    // it produced late/false "Reconnecting". The backend now detects the peer's
    // socket drop instantly and pushes `call:rejoin:peer_dropped`, which is the
    // single authoritative source for the banner.
  }

  Future<void> _handleAmigoTerminate(CallPayload payload) async {
    final incomingCid = payload.callId;
    final call = _streamCall
        ?? _client?.state.activeCall.valueOrNull
        ?? _client?.state.incomingCall.valueOrNull;
    if (call == null) {
      debugPrint('[STREAM-CALL] ↘ Amigo call:terminate ignored '
          '(no Stream call mounted)  payloadCid=$incomingCid');
      return;
    }
    final ourCid = call.callCid.value;
    if (incomingCid != null && incomingCid.isNotEmpty && incomingCid != ourCid) {
      debugPrint('[STREAM-CALL] ↘ Amigo call:terminate ignored — cid mismatch  '
          'ours=$ourCid  payload=$incomingCid');
      return;
    }
    // Mark this call as intentionally terminated so the ghost-call drop
    // detector treats the imminent participant-leave as a clean hangup, not a
    // silent drop — and tear down any rejoin window already in flight.
    _terminateReceivedForCid.add(ourCid);
    if (_rejoinWindowCid == ourCid) {
      debugPrint('[STREAM-CALL]   terminate arrived during rejoin window — '
          'cancelling window for $ourCid');
      _cancelRejoinWindow();
    }
    // Don't bounce our own outbound terminate back through this handler:
    // when we cancel locally we already drove `call.reject/end/leave`.
    // `_isTerminating` is set by endCall(); for declineCall there's no
    // equivalent guard but the SDK's idempotent reject() handles re-entry.
    final terminatedBy = (payload.data is Map)
        ? (payload.data as Map)['terminated_by']?.toString()
        : null;
    if (terminatedBy != null && terminatedBy == _currentUser?.id) {
      debugPrint('[STREAM-CALL] ↘ Amigo call:terminate is our own echo — skip  '
          'cid=$ourCid');
      return;
    }
    final reason = (payload.data is Map)
        ? (payload.data as Map)['reason']?.toString()
        : null;
    debugPrint('[STREAM-CALL] ↙ Amigo call:terminate accepted  cid=$ourCid  '
        'terminatedBy=$terminatedBy  reason=$reason  '
        'status=${call.state.value.status.runtimeType}');
    // Peer timed out (their watchdog fired and broadcast `timeout`). Flag it
    // so this device's disconnect overlay shows "Call timeout" instead of the
    // generic "Call declined" the Stream `Rejected` event would otherwise map
    // to. The overlay listens reactively, so flipping this even slightly after
    // the Stream event paints still updates the copy within the 2s linger.
    if (reason == 'timeout') endedByTimeout.value = true;
    // ignore: unawaited_futures
    StreamCallRingtones.instance.stopAll();
    try {
      final status = call.state.value.status;
      // `CallRejectReason.callEnded` is the SDK's own "ended externally"
      // reason (see call_reject_reason.dart). For pre-join states reject()
      // is the right teardown; for joined calls leave() exits our session.
      if (status is CallStatusOutgoing || status is CallStatusIncoming) {
        await call.reject(reason: CallRejectReason.callEnded());
      } else {
        await call.leave();
      }
    } catch (e) {
      debugPrint('[STREAM-CALL]   teardown threw on Amigo terminate: $e — '
          'falling back to leave()');
      try {
        await call.leave();
      } catch (_) {}
    }
    _clearMirror();
  }

  /// Handles a tap on the "Call back" action of a missed-call notification.
  ///
  /// Re-initiates an outgoing call to the original caller using the same
  /// `initiateCall` path the in-app call button uses, so all the usual
  /// guards (precheck, busy detection, screen push, ringtone start) apply.
  ///
  /// Limitations:
  ///  - Warm-only. If the user taps "Call back" while the app is killed,
  ///    the SDK plugin spawns a background isolate which has no main
  ///    Riverpod state and can't drive the call screen. A cold-state
  ///    fallback would need an analogous bridge to `AmigoColdDeclineBridge`
  ///    (launch the activity with a deeplink, init the engine, then call
  ///    initiateCall). Not in scope for this pass.
  ///  - We don't have the caller's avatar in the event payload, so the
  ///    outgoing-call screen shows the name only until Stream's
  ///    coordinator pushes participant metadata.
  Future<void> _handleMissedCallCallback(ActionCallCallback event) async {
    final callerId = event.data.handle;
    final callerName = event.data.callerName ?? 'Unknown';
    debugPrint('[STREAM-CALL] ★ ActionCallCallback  callerId=$callerId  '
        'callerName=$callerName  cid=${event.data.callCid}');
    if (callerId == null || callerId.isEmpty) {
      debugPrint('[STREAM-CALL]   callback bailing — no caller id in event data');
      return;
    }
    // hasVideo round-trips through CallData; we honour it so a video call
    // is returned with video on, audio with audio.
    final isVideo = event.data.hasVideo == true;
    try {
      await initiateCall(callerId, callerName, null, video: isVideo);
    } catch (e, st) {
      debugPrint('[STREAM-CALL] ✗ missed-call callback initiate failed: $e\n$st');
    }
  }

  /// Arm the 30s ring cap for [call]. [outgoing] selects the correct teardown
  /// primitive when it fires (caller cancels, callee times out). Idempotent —
  /// re-arming cancels any prior watchdog first.
  void _startRingWatchdog(Call call, {required bool outgoing}) {
    _ringWatchdogTimer?.cancel();
    final cid = call.callCid.value;
    debugPrint('[STREAM-CALL]   ⏱ ring watchdog armed '
        '(${_ringTimeout.inSeconds}s) cid=$cid outgoing=$outgoing');
    _ringWatchdogTimer = Timer(_ringTimeout, () {
      _ringWatchdogTimer = null;
      // ignore: unawaited_futures
      _onRingTimeout(call, outgoing: outgoing);
    });
  }

  /// Cancel a pending ring watchdog (call answered, declined, or torn down).
  void _cancelRingWatchdog() {
    if (_ringWatchdogTimer != null) {
      debugPrint('[STREAM-CALL]   ⏱ ring watchdog cancelled');
      _ringWatchdogTimer!.cancel();
      _ringWatchdogTimer = null;
    }
  }

  /// Fired when a call has rung for [_ringTimeout] without being answered.
  /// Force-terminates BOTH ends with reason "timeout": stops the local
  /// ringback, notifies our backend over WS, and rejects on the Stream
  /// coordinator so the peer's ring is torn down too.
  Future<void> _onRingTimeout(Call call, {required bool outgoing}) async {
    // Bail if the call already moved past the ring phase (answered) or was
    // torn down while the timer was pending — only an unanswered ring times
    // out.
    final status = call.state.value.status;
    final stillRinging =
        status is CallStatusOutgoing || status is CallStatusIncoming;
    if (!stillRinging || _streamCall?.callCid.value != call.callCid.value) {
      debugPrint('[STREAM-CALL]   ⏱ ring timeout ignored — '
          'status=${status.runtimeType} stillRinging=$stillRinging');
      return;
    }
    debugPrint('[STREAM-CALL] ⏱ ring timeout (${_ringTimeout.inSeconds}s) — '
        'terminating cid=${call.callCid.value} outgoing=$outgoing '
        'reason=timeout');

    // Flag the timeout BEFORE rejecting so the disconnect overlay this
    // reject triggers reads "Call timeout" on the first paint.
    endedByTimeout.value = true;
    // ignore: unawaited_futures
    StreamCallRingtones.instance.stopAll();
    // Tell our backend first so the call_history row is finalised as a
    // timeout (and an offline peer's FCM ring is cancelled) even if the
    // Stream reject below hangs.
    _sendCallTerminateWs('timeout');

    // Reject on the coordinator so the peer stops ringing. The caller
    // (creator) cancels the outgoing ring; the callee times out the incoming
    // one — `CallRejectReason.timeout()` is the same primitive Stream's own
    // incoming-ring timer uses, and neither reason is read by the peer as an
    // active "declined" so both ends log it as a no-answer.
    try {
      await call.reject(
        reason:
            outgoing ? CallRejectReason.cancel() : CallRejectReason.timeout(),
      );
    } catch (e) {
      debugPrint('[STREAM-CALL]   ⏱ ring-timeout reject threw: $e');
    }
    _clearMirror();
  }

  /// Fire `call:terminate` on Amigo's WS so the backend can finalise the
  /// call_history row and (when the recipient is offline) push an FCM
  /// fallback. The Stream coordinator handles ring-cancel on the callee side
  /// for created-by-me calls via `call.end()` below — this WS message is for
  /// our own backend bookkeeping, not the cross-device ring teardown.
  void _sendCallTerminateWs(String reason) {
    final active = _activeCall;
    final me = _currentUser;
    if (active == null || me == null) {
      debugPrint('[STREAM-CALL]   skip call:terminate WS — '
          'activeCall=${active != null} currentUser=${me != null}');
      return;
    }
    final isOutgoing = active.callType == app_call.CallType.outgoing;
    final callerId = isOutgoing ? me.id : active.userId;
    final calleeId = isOutgoing ? active.userId : me.id;
    final wsmsg = WSMessage(
      type: WSMessageType.callTerminate,
      payload: CallPayload(
        callId: active.callId,
        callerId: callerId,
        calleeId: calleeId,
        data: {'reason': reason},
        timestamp: DateTime.now(),
      ),
      wsTimestamp: DateTime.now(),
    ).toJson();
    debugPrint('[STREAM-CALL]   ⇡ WS call:terminate  cid=${active.callId}  '
        'caller=$callerId  callee=$calleeId  reason=$reason');
    // Fire-and-forget. The Stream-side cancel is independent and must run
    // even if the WS is wedged.
    _transportManager.sendMessage(wsmsg).catchError((e) {
      debugPrint('[STREAM-CALL]   ⚠ WS call:terminate send failed: $e');
      return false;
    });
  }

  /// Fire a `call:rejoin:*` message on Amigo's WS. Shares the caller/callee
  /// derivation with [_sendCallTerminateWs] so the backend's participant gate
  /// passes. Fire-and-forget.
  void _sendRejoinWs(WSMessageType type, String cid, Map<String, dynamic> data) {
    final active = _activeCall;
    final me = _currentUser;
    if (active == null || me == null) {
      debugPrint('[STREAM-CALL]   skip ${type.value} WS — '
          'activeCall=${active != null} currentUser=${me != null}');
      return;
    }
    final isOutgoing = active.callType == app_call.CallType.outgoing;
    final callerId = isOutgoing ? me.id : active.userId;
    final calleeId = isOutgoing ? active.userId : me.id;
    final wsmsg = WSMessage(
      type: type,
      payload: CallPayload(
        callId: cid,
        callerId: callerId,
        calleeId: calleeId,
        data: data,
        timestamp: DateTime.now(),
      ),
      wsTimestamp: DateTime.now(),
    ).toJson();
    debugPrint('[STREAM-CALL]   ⇡ WS ${type.value}  cid=$cid  data=$data');
    _transportManager.sendMessage(wsmsg).catchError((e) {
      debugPrint('[STREAM-CALL]   ⚠ WS ${type.value} send failed: $e');
      return false;
    });
  }

  /// The backend told us (via `call:rejoin:peer_dropped`) that the peer dropped
  /// while we stayed connected. Show "Reconnecting…". The SERVER owns the 30s
  /// window and will drive the outcome (`call:rejoin:expired{rejoined}` →
  /// _onPeerReturned, or `call:terminate` at expiry). We only arm a local
  /// SAFETY net in case those signals are somehow missed.
  void _onPeerDropped(String cid) {
    if (_rejoinWindowCid == cid) return; // already showing the banner
    if (_streamCall?.callCid.value != cid) return; // not our current call
    if (_callConnectedAt == null) return; // never actually connected
    if (_terminateReceivedForCid.contains(cid)) return; // clean hangup, not a drop
    final st = _streamCall?.state.value.status;
    if (st is CallStatusDisconnected || st is CallStatusReconnectionFailed) {
      return; // call already terminal — not a recoverable drop
    }
    final peerName = (_activeCall?.userName.isNotEmpty ?? false)
        ? _activeCall!.userName
        : (_callerHint?.userName ?? 'the other person');
    debugPrint('[STREAM-CALL] ⚠ peer dropped (server push) cid=$cid — '
        'showing "Reconnecting…" (peer=$peerName)');
    _rejoinWindowCid = cid;
    reconnectedFlash.value = false;
    reconnectingPeerName.value = peerName;
    // Local safety net ONLY: if neither the server's reconnected push nor its
    // expiry terminate arrives shortly after the 30s window, clear the stuck
    // banner and end the call as a backstop.
    _rejoinHoldTimer?.cancel();
    _rejoinHoldTimer = Timer(_rejoinSafety, () async {
      if (_rejoinWindowCid != cid) return;
      debugPrint('[STREAM-CALL] ⏱ no server resolution after ${_rejoinSafety.inSeconds}s '
          '— local safety end cid=$cid');
      _cancelRejoinWindow();
      await endCall(reason: 'rejoin_timeout');
    });
  }

  /// The backend told us the peer rejoined (`call:rejoin:expired{rejoined}`).
  /// Clear the banner and flash "Call reconnected". Purely UI — the server
  /// already closed the window when L's rejoin resolved it.
  void _onPeerReturned(String cid) {
    if (_rejoinWindowCid != cid) return;
    debugPrint('[STREAM-CALL] ✓ peer returned (server push) cid=$cid — reconnected');
    _rejoinHoldTimer?.cancel();
    _rejoinHoldTimer = null;
    _rejoinWindowCid = null;
    reconnectingPeerName.value = null;
    reconnectedFlash.value = true;
    _reconnectedFlashTimer?.cancel();
    _reconnectedFlashTimer = Timer(const Duration(milliseconds: 2500), () {
      reconnectedFlash.value = false;
    });
  }

  /// Tear down any in-flight rejoin banner (timer + notifiers). Called when the
  /// server signals expiry, on a terminate mid-window, and from `_clearMirror`.
  void _cancelRejoinWindow({bool clearBanner = true}) {
    _rejoinHoldTimer?.cancel();
    _rejoinHoldTimer = null;
    _reconnectedFlashTimer?.cancel();
    _reconnectedFlashTimer = null;
    _rejoinWindowCid = null;
    if (clearBanner) {
      reconnectingPeerName.value = null;
      reconnectedFlash.value = false;
    }
  }

  @override
  Future<void> declineCall({String? reason, String? callId}) async {
    debugPrint('[STREAM-CALL] ▶ declineCall(reason=$reason, callId=$callId)  '
        'me=${_currentUser?.id}');
    // Stop the ringtone on user intent — same reason as acceptCall: the
    // SDK's status transition can lag the tap.
    // ignore: unawaited_futures
    StreamCallRingtones.instance.stopAll();
    // Notify our backend before handing off to Stream — if the SDK call
    // throws or hangs, the backend still gets the terminate signal.
    _sendCallTerminateWs(reason ?? 'user_declined');
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
    // Dispatch our own WS event first — Stream's SDK calls below propagate
    // the cancel over Stream's coordinator, but the backend also needs to
    // know so it can persist the call_history row.
    _sendCallTerminateWs(reason ?? 'user_hangup');
    final call = _streamCall ?? _client?.state.activeCall.valueOrNull;
    if (call != null) {
      // Pick the right Stream API based on call phase:
      //
      //   • Ringing (CallStatusOutgoing / CallStatusIncoming) — the SDK has
      //     not joined the SFU yet, so `end()` is a no-op for the callee
      //     even though it returns success: the coordinator won't fan out
      //     a CallEndedEvent to a call that never reached `joined`. The
      //     correct primitive is `reject(reason: cancel|decline)`, which
      //     emits a CallRejectedEvent the callee's SDK acts on to stop
      //     the ring. (Stream's own SDK uses this exact call internally
      //     when accepting one call cancels another outgoing — see
      //     `Call.accept` in stream_video/lib/src/call/call.dart.)
      //
      //   • Joined / Connected — `end()` (for the creator) terminates the
      //     live call for all participants; everyone else uses `leave()`
      //     to exit their own session.
      //
      //   • Anything else (Idle / Disconnected / Joining for non-creators)
      //     — fall back to `leave()`.
      final status = call.state.value.status;
      final createdByMe = call.state.value.createdByMe;
      final bool isRingingPhase = status is CallStatusOutgoing
          || status is CallStatusIncoming;
      final String op;
      Future<Result<None>> action;
      if (isRingingPhase) {
        op = createdByMe
            ? 'reject(cancel)'
            : 'reject(decline)';
        action = call.reject(
          reason: createdByMe
              ? CallRejectReason.cancel()
              : CallRejectReason.decline(),
        );
      } else if (createdByMe && status.isAlreadyJoined) {
        op = 'end()';
        action = call.end();
      } else {
        op = 'leave()';
        action = call.leave();
      }
      debugPrint('[STREAM-CALL]   $op on cid=${call.callCid.value}  '
          'createdByMe=$createdByMe  '
          'preStatus=${status.runtimeType}');
      try {
        final res = await action;
        debugPrint('[STREAM-CALL]   $op → success=${res.isSuccess}');
        // Belt-and-braces: if `end()` / `reject()` reports failure (perm
        // denied, race with auto-cancel, etc.), still exit our own session
        // so the SDK doesn't leave a dangling joined participant.
        if (!res.isSuccess) {
          debugPrint('[STREAM-CALL]   $op unsuccessful — falling back to leave()');
          await call.leave();
        }
      } catch (e) {
        debugPrint('[STREAM-CALL]   $op threw: $e — falling back to leave()');
        try {
          await call.leave();
        } catch (_) {}
      }
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
    await _amigoTerminateSub?.cancel();
    await _amigoPeerDroppedSub?.cancel();
    await _amigoRejoinExpiredSub?.cancel();
    await _transportReconnectSub?.cancel();
    _activeCallSub = null;
    _incomingCallSub = null;
    _callStateSub = null;
    _coreRingingSub = null;
    _connectionSub = null;
    _callEventsSub = null;
    _ringingEventsSub = null;
    _amigoTerminateSub = null;
    _amigoPeerDroppedSub = null;
    _amigoRejoinExpiredSub = null;
    _transportReconnectSub = null;
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
