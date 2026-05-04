import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';
import 'package:uuid/uuid.dart';

import '../../../env.dart';
import '../../../models/call.model.dart' as app_call;
import '../../../models/user.model.dart' as app_user;
import '../../../utils/navigation-helper.util.dart';
import '../../../utils/user.utils.dart';
import '../../cookies.service.dart';
import '../i_call_backend.dart';
import 'stream_call_screens.dart';
import 'stream_call_token_loader.dart';

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
  StreamSubscription<CallState>? _callStateSub;
  StreamSubscription<Call?>? _activeCallSub;
  StreamSubscription? _coreRingingSub;

  bool _isInitialized = false;
  bool _isTerminating = false;

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

  @override
  Future<void> initialize() async {
    debugPrint('[STREAM-CALL] ▶ initialize() called  (already=$_isInitialized)');
    if (_isInitialized) {
      debugPrint('[STREAM-CALL]   ↳ already initialised, skipping');
      return;
    }

    debugPrint('[STREAM-CALL]   STREAM_API_KEY length=${Environment.streamApiKey.length}, '
        'callBackend=${Environment.callBackend}');
    if (Environment.streamApiKey.isEmpty) {
      debugPrint('[STREAM-CALL] ✗ STREAM_API_KEY is empty — Stream backend disabled.');
      return;
    }

    _currentUser = await UserUtils().getUserDetails();
    if (_currentUser == null) {
      debugPrint('[STREAM-CALL] ✗ No logged-in user; deferring init until login.');
      return;
    }
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
          registerApnDeviceToken: true,
        ),
      );
      debugPrint('[STREAM-CALL]   StreamVideo client constructed (with push manager)');

      _bindStateSubscriptions();
      debugPrint('[STREAM-CALL]   subscriptions wired');

      // Establish the WS connection eagerly so incoming-call events arrive
      // without waiting for the first user action.
      debugPrint('[STREAM-CALL]   issuing client.connect()…');
      _client!.connect().then((res) {
        debugPrint('[STREAM-CALL]   ✓ client.connect() completed → $res');
      }).catchError((e, st) {
        debugPrint('[STREAM-CALL] ✗ client.connect() failed: $e\n$st');
      });

      _isInitialized = true;
      debugPrint('[STREAM-CALL] ✓ initialise() done for user=${_currentUser!.id}');
    } catch (e, st) {
      debugPrint('[STREAM-CALL] ✗ initialise() threw: $e\n$st');
      _client = null;
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
        debugPrint('[STREAM-CALL]   activeCall=null → clearing mirror');
        _clearMirror();
        return;
      }

      _callStateSub = call.state.listen(_onCallStateChanged);
      debugPrint('[STREAM-CALL]   subscribed to call.state for ${call.callCid.value}');
      // Push the in-call screen if the user accepted from CallKit/notification
      // and there's no UI yet.
      _maybePushCallScreen(call);
    });

    // CallKit/native incoming UI fires this when user taps Accept while app
    // is in the background. Bring the UI to the front.
    _coreRingingSub?.cancel();
    _coreRingingSub = client.observeCoreRingingEvents(
      onCallAccepted: (Call call) {
        debugPrint('[STREAM-CALL] ★ observeCoreRingingEvents → onCallAccepted for ${call.callCid.value}');
        _maybePushCallScreen(call);
      },
    );
    debugPrint('[STREAM-CALL]   _bindStateSubscriptions complete');
  }

  void _onCallStateChanged(CallState state) {
    final status = _mapStreamStatus(state.status);
    final remote = _firstRemoteParticipant(state);
    debugPrint('[STREAM-CALL] ⮕ call.state: cid=${state.callCid.value} '
        'streamStatus=${state.status.runtimeType} mapped=$status '
        'createdByMe=${state.createdByMe} '
        'participants=${state.callParticipants.map((p) => p.userId).toList()}');

    final mirror = (_activeCall ?? app_call.ActiveCallState(
      callId: state.callCid.value,
      userId: remote?.userId ?? '',
      userName: remote?.name ?? remote?.userId ?? 'Unknown',
      userProfilePic: remote?.image,
      callType: state.createdByMe
          ? app_call.CallType.outgoing
          : app_call.CallType.incoming,
      status: status,
      startTime: DateTime.now(),
    )).copyWith(
      status: status,
      // Backfill remote identity once a participant joins.
      userId: remote?.userId ?? _activeCall?.userId ?? '',
      userName: remote?.name ?? _activeCall?.userName ?? 'Unknown',
      userProfilePic: remote?.image ?? _activeCall?.userProfilePic,
    );

    _activeCall = mirror;

    if (status == app_call.CallStatus.ended ||
        status == app_call.CallStatus.declined ||
        status == app_call.CallStatus.missed) {
      _clearMirror();
    }
  }

  app_call.CallStatus _mapStreamStatus(CallStatus s) {
    if (s is CallStatusIdle) return app_call.CallStatus.initiated;
    if (s is CallStatusOutgoing) return app_call.CallStatus.ringing;
    if (s is CallStatusIncoming) return app_call.CallStatus.ringing;
    if (s is CallStatusJoining) return app_call.CallStatus.connecting;
    if (s is CallStatusJoined) return app_call.CallStatus.answered;
    if (s is CallStatusReconnecting) return app_call.CallStatus.connecting;
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
    _activeCall = null;
    _streamCall = null;
    _isTerminating = false;
  }

  void _maybePushCallScreen(Call call) {
    final nav = NavigationHelper.navigator;
    if (nav == null) return;
    // Avoid pushing twice if a Stream call screen is already on top.
    if (StreamCallScreen.isMounted) return;
    nav.push(MaterialPageRoute(builder: (_) => StreamCallScreen(call: call)));
  }

  // ---- Lifecycle ----------------------------------------------------------

  @override
  Future<void> initiateCall(
    String calleeId,
    String calleeName,
    String? calleeProfilePic,
  ) async {
    debugPrint('[STREAM-CALL] ▶ initiateCall(calleeId=$calleeId, name=$calleeName)');

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

    debugPrint('[STREAM-CALL]   getOrCreate(members=[${_currentUser!.id}, $calleeId], '
        'ringing=true, video=false) …');
    final result = await call.getOrCreate(
      memberIds: [_currentUser!.id, calleeId],
      ringing: true,
      video: false, // audio-only for now
    );

    result.fold(
      success: (data) {
        debugPrint('[STREAM-CALL]   ✓ getOrCreate succeeded — call should be ringing on '
            'the server. Stream will fan-out the push to $calleeId now.');
        _streamCall = call;
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
    debugPrint('[STREAM-CALL] ▶ acceptCall(callId=$callId)');
    final call = _streamCall ?? _client?.state.activeCall.valueOrNull;
    if (call == null) {
      debugPrint('[STREAM-CALL] ✗ acceptCall: no incoming call to accept');
      return;
    }
    debugPrint('[STREAM-CALL]   accepting cid=${call.callCid.value}');

    final accept = await call.accept();
    accept.fold(
      success: (_) async {
        debugPrint('[STREAM-CALL]   ✓ accept() ok — joining…');
        final join = await call.join();
        join.fold(
          success: (_) {
            debugPrint('[STREAM-CALL]   ✓ join() ok — pushing call screen');
            _maybePushCallScreen(call);
          },
          failure: (f) => debugPrint('[STREAM-CALL] ✗ join failed: ${f.error.message}'),
        );
      },
      failure: (f) => debugPrint('[STREAM-CALL] ✗ accept failed: ${f.error.message}'),
    );
  }

  @override
  Future<void> declineCall({String? reason, String? callId}) async {
    debugPrint('[STREAM-CALL] ▶ declineCall(reason=$reason, callId=$callId)');
    final call = _streamCall ?? _client?.state.activeCall.valueOrNull;
    if (call == null) {
      debugPrint('[STREAM-CALL]   no active call to decline');
      return;
    }
    final res = await call.reject();
    debugPrint('[STREAM-CALL]   reject() → success=${res.isSuccess}');
    _clearMirror();
  }

  @override
  Future<void> endCall({String? reason}) async {
    debugPrint('[STREAM-CALL] ▶ endCall(reason=$reason)  terminating=$_isTerminating');
    if (_isTerminating) return;
    _isTerminating = true;
    final call = _streamCall ?? _client?.state.activeCall.valueOrNull;
    if (call != null) {
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

  /// Tear down for sign-out.
  Future<void> dispose() async {
    await _activeCallSub?.cancel();
    await _callStateSub?.cancel();
    await _coreRingingSub?.cancel();
    _activeCallSub = null;
    _callStateSub = null;
    _coreRingingSub = null;
    try {
      await _client?.disconnect();
    } catch (_) {}
    _client = null;
    _isInitialized = false;
    _clearMirror();
  }
}
