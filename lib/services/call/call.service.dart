import 'dart:async';
import 'package:amigo/env.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// FlutterCallkitIncoming - commented out, replaced by native call screen
// import 'package:flutter_callkit_incoming/entities/android_params.dart';
// import 'package:flutter_callkit_incoming/entities/call_event.dart';
// import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
// import 'package:flutter_callkit_incoming/entities/ios_params.dart';
// import 'package:flutter_callkit_incoming/entities/notification_params.dart';
// import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:proximity_screen_lock/proximity_screen_lock.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../models/call.model.dart';
import '../../models/user.model.dart';
import '../../types/socket.types.dart';
import '../../utils/navigation-helper.util.dart';
import '../../utils/ringtone.util.dart';
import '../../utils/call.utils.dart';
import '../../ui/snackbar.dart';
import '../socket/transport.manager.dart';
import '../socket/transport.service.dart';
import '../cookies.service.dart';
import '../socket/ws-message.handler.dart';
import 'call-foreground.service.dart';
import 'i_call_backend.dart';
import 'native_call_screen.service.dart';

import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';


class CallService implements ICallBackend {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Services
  // final NotificationService _notificationService = NotificationService();
  UserModel? _currentUser;

  // Call state
  ActiveCallState? _activeCall;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool _isTerminating = false; // Guard against concurrent cleanup from CallKit/endCall
  Timer? _callDurationTimer;
  Timer? _callStartedTimer;
  Timer? _statusPollingTimer;
  Timer? _offerRetryTimer;
  Map<String, dynamic>? _lastOfferMsg;
  String? _pollingCallId;

  final TransportManager _transportManager = TransportManager();
  final CookieService _cookieService = CookieService();
  
  // Method channel for lock screen flags
  static const MethodChannel _lockScreenChannel = MethodChannel('com.aiexch.amigo/lock_screen');

  // Call stream subscriptions
  StreamSubscription<CallPayload>? _callInitSubscription;
  StreamSubscription<CallPayload>? _callInitAckSubscription;
  StreamSubscription<CallPayload>? _callOfferSubscription;
  StreamSubscription<CallPayload>? _callAnswerSubscription;
  StreamSubscription<CallPayload>? _callIceSubscription;
  StreamSubscription<CallPayload>? _callAcceptSubscription;
  StreamSubscription<CallPayload>? _callTerminateSubscription;
  StreamSubscription<CallPayload>? _callRingingSubscription;
  StreamSubscription<CallPayload>? _callErrorSubscription;
  StreamSubscription<CallPayload>? _callMissedSubscription;

  // Call-ID deduplication to prevent WS + FCM double-processing the same call
  final Set<String> _recentCallIds = {};

  // Proximity control for global screen lock
  StreamSubscription<dynamic>? _proximitySubscription;
  bool _isProximityScreenLocked = false;

  // WebRTC configuration - using Plan B for compatibility
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      // Public STUN fallback
      {'urls': 'stun:stun.l.google.com:19302'},

      // TURN server over UDP and TCP
      {
        'urls': [
          'turn:turn.amigochats.com:3478?transport=udp',
          'turn:turn.amigochats.com:3478?transport=tcp',
        ],
        'username': 'amigo',
        'credential': 'amigopass',
      },

      // TURN server over TLS (secure)
      {
        'urls': ['turns:turn.amigochats.com:5349?transport=tcp'],
        'username': 'amigo',
        'credential': 'amigopass',
      },
    ],
    'sdpSemantics': 'plan-b',
  };

  // Constraints for audio-only calls
  final Map<String, dynamic> _mediaConstraints = {
    'audio': {
      'mandatory': {
        'googEchoCancellation': true,
        'googAutoGainControl': true,
        'googNoiseSuppression': true,
        'googHighpassFilter': true,
        'googTypingNoiseDetection': true,
        'googAudioMirroring': false,
      },
      'optional': [],
    },
    'video': false, // Audio only
  };

  // Getters
  ActiveCallState? get activeCall => _activeCall;
  bool get hasActiveCall => _activeCall != null;
  bool get isInCall => _activeCall?.status == CallStatus.answered || _activeCall?.status == CallStatus.connecting;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// Initialize the call service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _currentUser = await UserUtils().getUserDetails();

      // IMPORTANT: Read pending accept BEFORE subscribing to streams.
      // On cold start, gap-fill call:ringing can arrive the moment we subscribe.
      // If _handleIncomingCall fires before _handlePendingAccept reads SharedPrefs,
      // it sets _activeCall and _handlePendingAccept bails ("already in a call").
      // By reading SharedPrefs first and adding to dedup set, we block the replay.
      final pendingCallDetails = await CallUtils().getCallDetails();
      final hasPendingAccept = pendingCallDetails != null && pendingCallDetails.callStatus == 'accepting';
      if (hasPendingAccept && pendingCallDetails.callId != null) {
        _recentCallIds.add(pendingCallDetails.callId!);
        Future.delayed(const Duration(seconds: 60), () => _recentCallIds.remove(pendingCallDetails.callId!));
      }

      final handler = WebSocketMessageHandler();

      // Setup individual call stream listeners
      _callInitSubscription = handler.callInitStream.listen(_handleCallInit);
      _callInitAckSubscription = handler.callInitAckStream.listen(
        _handleCallInitAck,
      );
      _callOfferSubscription = handler.callOfferStream.listen(_handleCallOffer);
      _callAnswerSubscription = handler.callAnswerStream.listen(
        _handleCallAnswer,
      );
      _callIceSubscription = handler.callIceStream.listen(_handleCallIce);
      _callAcceptSubscription = handler.callAcceptStream.listen(
        _handleCallAccept,
      );
      _callTerminateSubscription = handler.callTerminateStream.listen(
        _handleCallTerminate,
      );
      _callRingingSubscription = handler.callRingingStream.listen(
        _handleIncomingCall,
      );
      _callErrorSubscription = handler.callErrorStream.listen(_handleCallError);
      _callMissedSubscription = handler.callMissedStream.listen(_handleCallMissed);

      _isInitialized = true;

      // Save base URL to SharedPrefs so native code (CallActionReceiver) can call
      // the decline/accept API directly without going through Flutter.
      _saveBaseUrlToPrefs();

      // Set up native call screen event handlers (replaces FlutterCallkitIncoming)
      _setupNativeCallScreenEvents();

      // Terminated-state answer: if the user tapped Answer on the notification
      // while the app was killed, CallActionReceiver saved callStatus="accepting".
      // We detect that here and auto-accept so the call goes through.
      if (hasPendingAccept) {
        _handlePendingAccept(pendingCallDetails);
      }

      // FlutterCallkitIncoming event listener - commented out, replaced by native call screen
      // FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      //   switch (event?.event) {
      //     case Event.actionCallAccept:
      //       final callDetails = await CallUtils().getCallDetails();
      //       await acceptCall(
      //         callId: callDetails?.callId,
      //         callerId: callDetails?.callerId,
      //         callerName: callDetails?.callerName,
      //         callerProfilePic: callDetails?.callerProfilePic,
      //       );
      //       break;
      //     case Event.actionCallDecline:
      //       final callId = await CallUtils().getCallId();
      //       await declineCall(callId: callId);
      //       FlutterCallkitIncoming.endAllCalls();
      //       break;
      //     case Event.actionCallEnded:
      //       if (!_isTerminating) { endCall(); }
      //       break;
      //     default:
      //       break;
      //   }
      // });
    } catch (e) {
      debugPrint('[CALL] Error initializing CallService');
    }
  }

  /// Save the API base URL to SharedPreferences so native code (CallActionReceiver)
  /// can make direct HTTP calls (e.g., decline) without Flutter.
  void _saveBaseUrlToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', Environment.baseUrl);
    } catch (e) {
      debugPrint('[CALL] Error saving base URL to prefs: $e');
    }
  }

  /// Handle a pending "accepting" status from terminated-state answer.
  /// [callDetails] is pre-read from SharedPrefs in initialize() BEFORE
  /// stream subscriptions, so gap-fill call:ringing can't race us.
  void _handlePendingAccept(CallDetails callDetails) async {
    try {
      final callId = callDetails.callId;
      debugPrint('[CALL] Handling pending accept from terminated state, callId=$callId');

      // Check call status from backend — the native HTTP accept may have already gone through
      final serverStatus = await _getCallStatusFromServer(callId);

      if (serverStatus == 'ended' || serverStatus == 'missed' || serverStatus == 'declined') {
        debugPrint('[CALL] Call $callId already $serverStatus on server, clearing');
        await CallUtils().clearCallDetails();
        return;
      }

      final skipWs = serverStatus == 'answered';
      if (skipWs) {
        debugPrint('[CALL] Call $callId already answered on server, restoring local state only');
      } else {
        // Server says still ringing — wait for WS to send accept
        await _waitForConnection();
      }

      await acceptCall(
        callId: callId,
        callerId: callDetails.callerId,
        callerName: callDetails.callerName ?? 'Unknown',
        callerProfilePic: callDetails.callerProfilePic,
        skipWsAccept: skipWs,
      );
    } catch (e) {
      debugPrint('[CALL] Error handling pending accept: $e');
      try { await CallUtils().clearCallDetails(); } catch (_) {}
    }
  }

  /// Query the backend for the current call status.
  Future<String?> _getCallStatusFromServer(String? callId) async {
    if (callId == null || callId.isEmpty) return null;
    try {
      final dio = Dio();
      final response = await dio.get(
        '${Environment.baseUrl}/call/status/$callId',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']?['status'] as String?;
      }
    } catch (e) {
      debugPrint('[CALL] Error checking call status from server: $e');
    }
    return null;
  }

  /// Accept via HTTP as a fallback when WS send fails.
  Future<bool> _acceptViaHttp(String callId) async {
    try {
      final dio = Dio();
      final response = await dio.post(
        '${Environment.baseUrl}/call/accept/$callId',
        data: {},
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[CALL] HTTP accept fallback failed: $e');
      return false;
    }
  }

  /// Wait up to 10 seconds for the transport to connect.
  Future<void> _waitForConnection() async {
    if (_transportManager.isConnected) return;

    debugPrint('[CALL] Waiting for transport connection...');
    final completer = Completer<void>();
    Timer? timeout;
    StreamSubscription? sub;

    timeout = Timer(const Duration(seconds: 10), () {
      sub?.cancel();
      if (!completer.isCompleted) {
        debugPrint('[CALL] Transport connection timeout — proceeding anyway');
        completer.complete();
      }
    });

    sub = _transportManager.connectionStateStream.listen((state) {
      if (state == TransportConnectionState.connected) {
        timeout?.cancel();
        sub?.cancel();
        if (!completer.isCompleted) {
          debugPrint('[CALL] Transport connected — proceeding with accept');
          completer.complete();
        }
      }
    });

    // Check again in case it connected between the initial check and subscribing
    if (_transportManager.isConnected && !completer.isCompleted) {
      timeout.cancel();
      sub.cancel();
      completer.complete();
    }

    return completer.future;
  }

  /// Set up event handlers from native call screen
  void _setupNativeCallScreenEvents() {
    NativeCallScreen.onCallAccepted = (String callId) async {
      debugPrint('[CALL] Native call screen: call accepted (callId=$callId)');
      final callDetails = await CallUtils().getCallDetails();
      await acceptCall(
        callId: callDetails?.callId ?? callId,
        callerId: callDetails?.callerId,
        callerName: callDetails?.callerName,
        callerProfilePic: callDetails?.callerProfilePic,
      );
    };

    NativeCallScreen.onCallDeclined = (String callId) async {
      debugPrint('[CALL] Native call screen: call declined (callId=$callId)');
      await declineCall(callId: callId.isNotEmpty ? callId : null);
    };

    NativeCallScreen.onCallEnded = (String callId) async {
      debugPrint('[CALL] Native call screen: call ended (callId=$callId)');
      if (!_isTerminating) {
        await endCall();
      }
    };

    NativeCallScreen.onMuteToggled = (bool isMuted) async {
      debugPrint('[CALL] Native call screen: mute toggled ($isMuted)');
      // Sync mute state from native
      if (_activeCall != null && _activeCall!.isMuted != isMuted) {
        await toggleMute();
      }
    };

    NativeCallScreen.onSpeakerToggled = (bool isSpeakerOn) async {
      debugPrint('[CALL] Native call screen: speaker toggled ($isSpeakerOn)');
      if (_activeCall != null && _activeCall!.isSpeakerOn != isSpeakerOn) {
        await toggleSpeaker();
      }
    };

  }

  /// Initiate an outgoing call
  ///
  /// [video] is part of the [ICallBackend] surface. The legacy WebRTC
  /// backend doesn't have a video implementation — we accept the param
  /// for ABI compatibility but log a warning if `video=true`. Use the
  /// Stream backend for video calls.
  Future<void> initiateCall(
    String calleeId,
    String calleeName,
    String? calleeProfilePic, {
    bool video = false,
  }) async {
    try {
      if (video) {
        debugPrint('[CALL] ⚠ video=true requested but the legacy WebRTC '
            'backend is audio-only. Falling back to audio.');
      }
      // Ensure initialization completes before proceeding
      if (!_isInitialized) {
        await initialize();
        // Wait a bit for initialization to fully complete
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Double-check initialization
      if (!_isInitialized) {
        debugPrint('[CALL] CallService not initialized, cannot initiate call');
        throw Exception('CallService not initialized');
      }

      // IMPORTANT: Clean up any stale state before initiating new call
      // This ensures we start with a clean slate after ending a previous call
      if (hasActiveCall || _statusPollingTimer != null || _pollingCallId != null || _callDurationTimer != null || _callStartedTimer != null) {
        debugPrint('[CALL] Found stale call state before initiating new call - cleaning up');
        debugPrint('[CALL] Stale state - hasActiveCall: $hasActiveCall, pollingTimer: ${_statusPollingTimer != null}, pollingCallId: $_pollingCallId, durationTimer: ${_callDurationTimer != null}, startedTimer: ${_callStartedTimer != null}');
        await _cleanup();
        // Wait a bit to ensure cleanup is complete
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Double-check cleanup - force clear if still exists
        if (_activeCall != null) {
          debugPrint('[CALL] WARNING: _activeCall still exists after cleanup - forcing clear');
          _activeCall = null;
        }
        if (_statusPollingTimer != null || _pollingCallId != null) {
          debugPrint('[CALL] WARNING: Status polling still active - forcing stop');
          _stopStatusPolling();
        }
      }

      // Check if WebSocket is connected
      if (!_transportManager.isConnected) {
        debugPrint('[CALL] WebSocket not connected, connecting...');
        final accessToken = await _cookieService.getAccessToken();
        if (accessToken != null) {
          await _transportManager.connect(accessToken);
        }
        // Wait for connection to stabilize
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Verify WebSocket is still connected
      if (!_transportManager.isConnected) {
        debugPrint('[CALL] WebSocket connection failed');
        throw Exception('WebSocket not connected');
      }

      // Get current user info - must be available
      if (_currentUser == null) {
        _currentUser = await UserUtils().getUserDetails();
        if (_currentUser == null) {
          debugPrint('[CALL] Current user not available');
          throw Exception('User not logged in');
        }
      }

      // Enable wakelock only when initiating call (will be managed by lifecycle observer)
      await WakelockPlus.enable();

      // Get user media
      await _setupLocalMedia();

      await Helper.setSpeakerphoneOn(false);

      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      final callInitPayload = CallPayload(
        callerId: _currentUser!.id,
        callerName: _currentUser!.name,
        callerPfp: _currentUser!.profilePic,
        calleeId: calleeId,
        calleeName: calleeName,
        calleePfp: calleeProfilePic,
        timestamp: DateTime.now(),
      );

      final wsmsg = WSMessage(
        type: WSMessageType.callInit,
        payload: callInitPayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      // Send message and handle errors
      try {
        await _transportManager.sendMessage(wsmsg);
        debugPrint('[CALL] Call init message sent successfully');
      } catch (e) {
        debugPrint('❌ Error sending call:init: $e');
        await _cleanup();
        rethrow;
      }

      // Set up local call state AFTER successfully sending message
      // This will be updated when backend confirms via call:init:ack or call:ringing
      // IMPORTANT: Ensure _activeCall is null before setting new call
      if (_activeCall != null) {
        debugPrint('[CALL] WARNING: _activeCall was not null before setting new call - clearing it');
        _activeCall = null;
        // Small delay to ensure state is cleared and provider syncs
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      _activeCall = ActiveCallState(
        callId: '', // Will be updated from backend response
        userId: calleeId,
        userName: calleeName,
        userProfilePic: calleeProfilePic,
        callType: CallType.outgoing,
        status: CallStatus.initiated,
        startTime: DateTime.now(),
        isSpeakerOn: false,
      );
      
      debugPrint('[CALL] ✅ New call state set: callId=${_activeCall!.callId}, status=${_activeCall!.status}, callType=${_activeCall!.callType}');
      debugPrint('[CALL] Provider should sync within 100ms - UI should update soon');

      // Show native outgoing call screen
      await NativeCallScreen.showOutgoingCall(
        callId: _activeCall!.callId,
        calleeName: calleeName,
        calleePhoto: calleeProfilePic,
      );

      // Start the 30-second timeout timer
      _startCallStartedTimer();

      // Start status polling as fallback (will be updated when we get the actual callId)
      // Note: We'll start polling after we get the callId from the server response

      try {
        await RingtoneManager.playRingtone();
      } catch (e) {
        debugPrint('[CALL] Error playing ringtone');
        // await RingtoneManager.playSystemRingtone();
      }
    } catch (e) {
      debugPrint('[CALL] Failed to initiate call: $e');
      await _cleanup();
      rethrow;
    }
  }

  /// Restore call state from SharedPreferences
  Future<void> restoreCallState(
    String callId,
    String callerId,
    String callerName,
    String? callerProfilePic,
  ) async {
    try {
      _activeCall = ActiveCallState(
        callId: callId,
        userId: callerId,
        userName: callerName,
        userProfilePic: callerProfilePic,
        callType: CallType.incoming,
        status: CallStatus.ringing,
        startTime: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[CALL] Error restoring call state');
    }
  }

  /// Accept an incoming call
  Future<void> acceptCall({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerProfilePic,
    bool skipWsAccept = false,
  }) async {
    try {
      // If _activeCall is null but we have callId, try to restore call state
      if (_activeCall == null && callId != null) {
        if (callerId != null && callerName != null) {
          await restoreCallState(
            callId,
            callerId,
            callerName,
            callerProfilePic,
          );
        } else {
          debugPrint('Cannot restore call state: missing caller information');
          return;
        }
      }

      if (_activeCall == null && callId == null) {
        debugPrint('No active call to accept');
        return;
      }

      if (callId != null && _activeCall != null) {
        _activeCall = _activeCall?.copyWith(callId: callId);
      }

      // Enable wakelock when accepting call (will be managed by lifecycle observer)
      await WakelockPlus.enable();

      // Enable global proximity control for screen lock
      _initializeProximityControl();

      // Setup local media if not already done
      if (_localStream == null) {
        await _setupLocalMedia();
      }

      if (_currentUser == null) return;

      // Send call:accept via WS (unless HTTP accept already went through)
      if (!skipWsAccept) {
        final callAcceptPayload = CallPayload(
          callId: _activeCall!.callId,
          callerId: _activeCall!.userId,
          calleeId: _currentUser!.id,
          timestamp: DateTime.now(),
        );

        final wsmsg = WSMessage(
          type: WSMessageType.callAccept,
          payload: callAcceptPayload,
          wsTimestamp: DateTime.now(),
        ).toJson();

        final wsSent = await _transportManager.sendMessage(wsmsg);
        if (!wsSent) {
          debugPrint('[CALL] WS accept failed (returned false), trying HTTP fallback');
          if (_activeCall != null && _activeCall!.callId.isNotEmpty) {
            await _acceptViaHttp(_activeCall!.callId);
          }
        }
      }

      // Cancel the call started timer since call is now accepted
      _callStartedTimer?.cancel();
      _callStartedTimer = null;

      await Helper.setSpeakerphoneOn(false);
      _activeCall = _activeCall!.copyWith(
        status: CallStatus.answered,
        isSpeakerOn: false,
      );

      debugPrint('[CALL] Call accepted - status: ${_activeCall!.status}, isSpeakerOn: ${_activeCall!.isSpeakerOn}');

      // Transition native call screen to in-call mode
      await NativeCallScreen.updateCallState(
        callMode: 'in_call',
        isMuted: _activeCall!.isMuted,
        isSpeakerOn: _activeCall!.isSpeakerOn,
      );
      // Dismiss incoming notification and show ongoing notification
      await NativeCallScreen.dismissIncomingNotification();
      await NativeCallScreen.showOngoingNotification(
        callId: _activeCall!.callId,
        callerName: _activeCall!.userName,
        callerPhoto: _activeCall!.userProfilePic,
      );

      // Start timer immediately when call is accepted
      _startCallTimer();

      // Start foreground service to keep microphone active in background
      await CallForegroundService.startService(
        callerName: _activeCall!.userName,
      );

      // Enable lock screen flags for call
      await _enableLockScreenFlags();

      await CallUtils().clearCallDetails();
    } catch (e) {
      debugPrint('[CALL] Error accepting call');
    }
  }

  /// Decline an incoming call or cancel an outgoing call
  Future<void> declineCall({String? reason, String? callId}) async {
    try {
      // Get callId from parameter, active call, or SharedPreferences
      String? actualCallId = callId;

      if ((actualCallId == null || actualCallId.isEmpty) && _activeCall != null) {
        actualCallId = _activeCall!.callId;
      }

      if (actualCallId == null || actualCallId.isEmpty) {
        actualCallId = await CallUtils().getCallId();
      }

      if (actualCallId == null || actualCallId.isEmpty) {
        debugPrint('[CALL] No callId available to decline');
        await _cleanup();
        return;
      }

      // If we have callId but no active call, try to restore from SharedPreferences
      if (_activeCall == null) {
        final callDetails = await CallUtils().getCallDetails();

        if (callDetails?.callerId != null && callDetails?.callerName != null) {
          await restoreCallState(
            actualCallId,
            callDetails!.callerId!,
            callDetails.callerName!,
            callDetails.callerProfilePic,
          );
        } else {
          debugPrint(
            '[CALL] Cannot restore call state, but will still send decline with callId=$actualCallId',
          );
        }
      }

      // Update callId if we have it
      if (_activeCall != null && _activeCall!.callId != actualCallId) {
        _activeCall = _activeCall!.copyWith(callId: actualCallId);
      }

      if (_currentUser == null) {
        _currentUser = await UserUtils().getUserDetails();
        if (_currentUser == null) {
          debugPrint('[CALL] Current user not available, cannot decline');
          await _cleanup();
          return;
        }
      }

      // Determine caller/callee based on call type
      // For outgoing calls: we are the caller, other user is callee
      // For incoming calls: other user is caller, we are the callee
      final isOutgoing = _activeCall?.callType == CallType.outgoing;
      String? actualCallerId;
      String? actualCalleeId;

      if (_activeCall != null) {
        if (isOutgoing) {
          // We are the caller
          actualCallerId = _currentUser!.id;
          actualCalleeId = _activeCall!.userId;
        } else {
          // We are the callee
          actualCallerId = _activeCall!.userId;
          actualCalleeId = _currentUser!.id;
        }
      } else {
        // Try to get from SharedPreferences (this is typically an incoming call)
        final callerId = await CallUtils().getCallerId();
        if (callerId != null) {
          actualCallerId = callerId;
          actualCalleeId = _currentUser!.id;
        }
      }

      if (actualCallerId == null || actualCalleeId == null) {
        debugPrint(
          '[CALL] Cannot determine caller/callee IDs, cannot send decline',
        );
        await _cleanup();
        return;
      }

      final declineReason =
          reason ?? (isOutgoing ? 'caller_cancelled' : 'user_declined');
      debugPrint(
        '[CALL] Declining call: callId=$actualCallId, callerId=$actualCallerId, calleeId=$actualCalleeId, isOutgoing=$isOutgoing, reason=$declineReason',
      );

      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      final callDeclinePayload = CallPayload(
        callId: actualCallId,
        callerId: actualCallerId,
        calleeId: actualCalleeId,
        data: {'reason': declineReason},
        timestamp: DateTime.now(),
      );

      final wsmsg = WSMessage(
        type: WSMessageType.callTerminate,
        payload: callDeclinePayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      // Send decline message and wait for it
      try {
        await _transportManager.sendMessage(wsmsg);
        debugPrint('[CALL] Decline message sent successfully');
      } catch (e) {
        debugPrint('❌ Error sending call:decline: $e');
      }

      // Cancel the call started timer since call is being declined
      _callStartedTimer?.cancel();
      _callStartedTimer = null;
      _stopStatusPolling();

      // Stop ringtone
      try {
        await RingtoneManager.stopRingtone();
      } catch (e) {
        await RingtoneManager.dispose();
        debugPrint('[CALL] Error stopping ringtone in decline: $e');
      }

      // Disable lock screen flags when call is declined
      await _disableLockScreenFlags();

      // Dismiss native call screen and notifications
      await NativeCallScreen.dismissCallScreen();

      // FlutterCallkitIncoming - commented out, replaced by native call screen
      // await FlutterCallkitIncoming.endAllCalls();

      // Clean up state
      await _cleanup();

      await CallUtils().clearCallDetails();
    } catch (e) {
      debugPrint('[CALL] Error declining call: $e');
      await _cleanup();
    }
  }

  /// End the current call
  Future<void> endCall({String? reason}) async {
    try {
      if (_activeCall == null) return;
      if (_currentUser == null) return;
      // Don't send another terminate if _handleCallTerminate is already running
      if (_isTerminating) {
        debugPrint('[CALL] endCall skipped - _handleCallTerminate already in progress');
        return;
      }

      // Determine caller/callee based on call type
      final isOutgoing = _activeCall!.callType == CallType.outgoing;
      final callerId = isOutgoing ? _currentUser!.id : _activeCall!.userId;
      final calleeId = isOutgoing ? _activeCall!.userId : _currentUser!.id;

      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      final callEndPayload = CallPayload(
        callId: _activeCall!.callId,
        callerId: callerId,
        calleeId: calleeId,
        data: {'reason': reason ?? 'user_hangup'},
        timestamp: DateTime.now(),
      );
      

      final wsmsg = WSMessage(
        type: WSMessageType.callTerminate,
        payload: callEndPayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      _transportManager.sendMessage(wsmsg).catchError((e) {
        debugPrint('❌ Error sending call:end: $e');
      });

      try {
        await RingtoneManager.stopRingtone();
      } catch (e) {
        await RingtoneManager.dispose();
        debugPrint('[CALL] Error stopping ringtone: $e');
      }

      // Disable lock screen flags when call ends
      await _disableLockScreenFlags();

      // Dismiss native call screen and notifications
      try {
        await NativeCallScreen.dismissCallScreen();
      } catch (e) {
        debugPrint('[CALL] Error dismissing native call screen: $e');
      }

      // FlutterCallkitIncoming - commented out, replaced by native call screen
      // try {
      //   await FlutterCallkitIncoming.endAllCalls();
      // } catch (e) {
      //   debugPrint('[CALL] Error ending CallKit calls: $e');
      // }

      await CallUtils().clearCallDetails();

      // IMPORTANT: Cleanup and wait to ensure everything is cleared
      await _cleanup();
      
      // Wait a bit to ensure cleanup is complete and state is fully cleared
      await Future.delayed(const Duration(milliseconds: 200));
      
      debugPrint('[CALL] Call ended and cleanup completed. _activeCall: ${_activeCall == null ? "null" : "still exists (should be null)"}');
      
      // Double-check cleanup - force clear if still exists
      if (_activeCall != null) {
        debugPrint('[CALL] WARNING: _activeCall still exists after cleanup - forcing clear');
        _activeCall = null;
        _stopStatusPolling();
      }
    } catch (e) {
      debugPrint('[CALL] Error ending call: $e');
      await _cleanup();
      // Force clear on error too
      _activeCall = null;
      _pollingCallId = null;
      _statusPollingTimer?.cancel();
      _statusPollingTimer = null;
    }
  }

  /// Toggle mute
  Future<void> toggleMute() async {
    if (_localStream == null) return;

    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      final track = audioTracks[0];
      track.enabled = !track.enabled;

      _activeCall = _activeCall?.copyWith(isMuted: !track.enabled);

      // Sync mute state to native call screen
      NativeCallScreen.updateCallState(isMuted: _activeCall?.isMuted);
      if (_activeCall != null) {
        NativeCallScreen.updateOngoingNotification(
          callerName: _activeCall!.userName,
          isMuted: _activeCall!.isMuted,
        );
      }
    }
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    if (_activeCall == null) return;

    final newSpeakerState = !_activeCall!.isSpeakerOn;
    await Helper.setSpeakerphoneOn(newSpeakerState);

    _activeCall = _activeCall!.copyWith(isSpeakerOn: newSpeakerState);

    // Sync speaker state to native call screen
    NativeCallScreen.updateCallState(isSpeakerOn: newSpeakerState);
  }

  /// Handle missed-call notification from server
  void _handleCallMissed(CallPayload payload) async {
    debugPrint('[CALL] Missed call from callerId=${payload.callerId}');
    // Prefer the saved contact name over the server-provided username.
    final callerName = await UserUtils()
            .preferredContactName(payload.callerId, payload.callerName) ??
        'Unknown';
    await NativeCallScreen.showMissedCallNotification(
      callId: payload.callId ?? '',
      callerName: callerName,
    );
  }

  /// Setup local media stream
  Future<void> _setupLocalMedia() async {
    try {
      // Add a small delay to ensure audio system is ready
      await Future.delayed(const Duration(milliseconds: 200));

      _localStream = await navigator.mediaDevices.getUserMedia(
        _mediaConstraints,
      );
    } catch (e) {
      // Retry once after a delay
      try {
        await Future.delayed(const Duration(milliseconds: 500));

        _localStream = await navigator.mediaDevices.getUserMedia(
          _mediaConstraints,
        );
      } catch (retryError) {
        debugPrint('[CALL] Failed to setup local media even on retry');
      }
    }
  }

  /// Create peer connection
  Future<void> _createPeerConnection() async {
    try {
      _peerConnection = await createPeerConnection(_configuration);

      // Add local stream (Plan B compatible)
      if (_localStream != null) {
        await _peerConnection!.addStream(_localStream!);
      }

      // Handle remote stream (Plan B compatible)
      _peerConnection!.onAddStream = (MediaStream stream) {
        _remoteStream = stream;
      };

      // Handle ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _sendIceCandidate(candidate);
      };

      // Handle connection state changes
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[CALL] WebRTC connection state: $state');
      };
    } catch (e) {
      debugPrint('[CALL] Error creating peer connection');
    }
  }

  /// Create and send offer
  Future<void> _createOffer() async {
    try {
      if (_peerConnection == null) {
        await _createPeerConnection();
      }

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      if (_currentUser == null) return;

      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      final callOfferPayload = CallPayload(
        callId: _activeCall!.callId,
        callerId: _currentUser!.id,
        calleeId: _activeCall!.userId,
        data: {'sdp': offer.sdp, 'type': offer.type},
        timestamp: DateTime.now(),
      );

      final wsmsg = WSMessage(
        type: WSMessageType.callOffer,
        payload: callOfferPayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      _lastOfferMsg = wsmsg;
      _transportManager.sendMessage(wsmsg).catchError((e) {
        debugPrint('❌ Error sending call:offer: $e');
      });

      // Retry sending the offer every 3s while in 'connecting' state.
      // Covers the terminated-app case where the callee's Flutter wasn't
      // online when the first offer was sent.
      _offerRetryTimer?.cancel();
      _offerRetryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (_activeCall?.status != CallStatus.connecting || _lastOfferMsg == null) {
          _offerRetryTimer?.cancel();
          _offerRetryTimer = null;
          _lastOfferMsg = null;
          return;
        }
        debugPrint('[CALL] Re-sending offer (callee may not have received it yet)');
        _transportManager.sendMessage(_lastOfferMsg!).catchError((e) {
          debugPrint('❌ Error re-sending call:offer: $e');
        });
      });
    } catch (e) {
      debugPrint('[CALL] Error creating offer');
    }
  }

  /// Handle incoming offer
  Future<void> _handleOffer(
    Map<String, dynamic> payload,
    CallPayload callPayload,
  ) async {
    try {
      if (_peerConnection == null) {
        await _createPeerConnection();
      }

      final offer = RTCSessionDescription(payload['sdp'], payload['type']);
      await _peerConnection!.setRemoteDescription(offer);

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      if (_currentUser == null) return;

      // Use caller/callee from the received payload
      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      final callAnswerPayload = CallPayload(
        callId: callPayload.callId ?? _activeCall?.callId,
        callerId: callPayload.callerId, // Caller from received offer
        calleeId: callPayload.calleeId, // Callee (should be us)
        data: {'sdp': answer.sdp, 'type': answer.type},
        timestamp: DateTime.now(),
      );

      final wsmsg = WSMessage(
        type: WSMessageType.callAnswer,
        payload: callAnswerPayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      _transportManager.sendMessage(wsmsg).catchError((e) {
        debugPrint('❌ Error sending call:answer: $e');
      });
    } catch (e) {
      debugPrint('[CALL] Error handling offer');
    }
  }

  /// Handle incoming answer
  Future<void> _handleAnswer(Map<String, dynamic> payload) async {
    try {
      if (_peerConnection == null) return;

      final answer = RTCSessionDescription(payload['sdp'], payload['type']);
      await _peerConnection!.setRemoteDescription(answer);

      // SDP answer received — callee's Flutter is running and WebRTC is live.
      // Stop offer retries and transition from 'connecting' → 'answered'.
      _offerRetryTimer?.cancel();
      _offerRetryTimer = null;
      _lastOfferMsg = null;

      if (_activeCall?.status == CallStatus.connecting) {
        _activeCall = _activeCall!.copyWith(status: CallStatus.answered);
        _startCallTimer();
        NativeCallScreen.updateCallState(
          callMode: 'in_call',
          isMuted: _activeCall!.isMuted,
          isSpeakerOn: _activeCall!.isSpeakerOn,
        );
        debugPrint('[CALL] SDP answer received — call timer started');
      }
    } catch (e) {
      debugPrint('[CALL] Error handling answer');
    }
  }

  /// Handle ICE candidate
  Future<void> _handleIceCandidate(Map<String, dynamic> payload) async {
    try {
      if (_peerConnection == null) return;

      final candidate = RTCIceCandidate(
        payload['candidate'],
        payload['sdpMid'],
        payload['sdpMLineIndex'],
      );

      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      debugPrint('[CALL] Error handling ICE candidate');
    }
  }

  /// Send ICE candidate
  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    try {
      if (_activeCall == null || _currentUser == null) return;

      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      final callIcePayload = CallPayload(
        callId: _activeCall!.callId,
        callerId: _currentUser!.id,
        calleeId: _activeCall!.userId,
        data: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        timestamp: DateTime.now(),
      );

      final wsmsg = WSMessage(
        type: WSMessageType.callIce,
        payload: callIcePayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      _transportManager.sendMessage(wsmsg).catchError((e) {
        debugPrint('❌ Error sending call:ice: $e');
      });
    } catch (e) {
      debugPrint('[CALL] Error sending ICE candidate');
    }
  }

  /// Start call duration timer
  void _startCallTimer() {
    if (_callDurationTimer != null) return;

    // Reset the start time to now when the timer starts (when call is accepted)
    _activeCall = _activeCall?.copyWith(startTime: DateTime.now());

    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeCall != null && _activeCall!.status == CallStatus.answered) {
        final duration = DateTime.now().difference(_activeCall!.startTime);
        _activeCall = _activeCall!.copyWith(duration: duration);
      }
    });
  }

  void _startCallStartedTimer() {
    if (_callStartedTimer != null) return;

    // Start the 30-second timeout timer when call is initiated
    _callStartedTimer = Timer(const Duration(seconds: 30), () async {
      // If call is still not accepted after 30 seconds, decline it automatically
      if (_activeCall != null && _activeCall!.status != CallStatus.answered) {
        declineCall(reason: 'timeout');
        try {
          await RingtoneManager.stopRingtone();
        } catch (e) {
          await RingtoneManager.dispose();
          debugPrint('[CALL] Error stopping ringtone in timeout');
        }
      }
    });
  }

  /// Helper to convert CallPayload data to Map
  Map<String, dynamic>? _payloadDataToMap(CallPayload payload) {
    if (payload.data == null) return null;
    if (payload.data is Map<String, dynamic>) {
      return payload.data as Map<String, dynamic>;
    }
    if (payload.data is Map) {
      return Map<String, dynamic>.from(payload.data as Map);
    }
    try {
      return payload.data.toJson() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Handle call init message
  void _handleCallInit(CallPayload payload) async {
    final payloadMap = _payloadDataToMap(payload);
    if (payloadMap?['success'] == true || payload.data?['success'] == true) {
      final callId = payload.callId;
      if (callId != null && callId.isNotEmpty) {
        _activeCall = _activeCall?.copyWith(callId: callId);

        // Start status polling as fallback when WebSocket might not be reliable
        _startStatusPolling(callId);
      }
    } else {
      _cleanup();
    }
  }

  /// Handle call init ack message
  void _handleCallInitAck(CallPayload payload) async {
    // Similar to call init, handle acknowledgment
    final callId = payload.callId;
    if (callId != null && callId.isNotEmpty) {
      _activeCall = _activeCall?.copyWith(callId: callId);
      _startStatusPolling(callId);
    }
  }

  /// Handle call accept message
  void _handleCallAccept(CallPayload payload) async {
    // For outgoing calls, we might receive accept even if callId doesn't match exactly
    // Check if we have an active outgoing call
    if (_activeCall == null) {
      debugPrint('[CALL] Ignoring call:accept - no active call');
      return;
    }

    // For outgoing calls, be more lenient with callId matching
    // The callId might be empty initially and get updated later
    final isOutgoingCall = _activeCall!.callType == CallType.outgoing;
    final callIdMatches = payload.callId == null ||
                         _activeCall!.callId == payload.callId ||
                         _activeCall!.callId.isEmpty;

    if (!callIdMatches && !isOutgoingCall) {
      debugPrint('[CALL] Ignoring call:accept - callId mismatch. Active: ${_activeCall!.callId}, Payload: ${payload.callId}');
      return;
    }

    debugPrint('[CALL] Handling call:accept for callId=${payload.callId ?? _activeCall!.callId}, ActiveCallId: ${_activeCall!.callId}');

    // Update callId if provided and different (or if it was empty)
    if (payload.callId != null && (_activeCall!.callId != payload.callId || _activeCall!.callId.isEmpty)) {
      debugPrint('[CALL] Updating callId from ${_activeCall!.callId} to ${payload.callId}');
      _activeCall = _activeCall!.copyWith(callId: payload.callId);
    }

    // Cancel the call started timer since call is now accepted
    _callStartedTimer?.cancel();
    _callStartedTimer = null;

    // Stop status polling since call is now accepted
    _stopStatusPolling();

    await Helper.setSpeakerphoneOn(false);

    // For outgoing calls: use intermediate 'connecting' state while WebRTC sets up
    // For incoming calls: go straight to 'answered' (callee is already ready)
    final isOutgoing = _activeCall!.callType == CallType.outgoing;
    final initialStatus = isOutgoing ? CallStatus.connecting : CallStatus.answered;

    _activeCall = _activeCall!.copyWith(
      status: initialStatus,
      isSpeakerOn: false,
    );

    debugPrint('[CALL] Call status updated to $initialStatus for callId=${_activeCall!.callId}, isSpeakerOn=${_activeCall!.isSpeakerOn}');

    // Small delay to ensure UI has time to react to status change
    await Future.delayed(const Duration(milliseconds: 100));

    // Enable global proximity control
    _initializeProximityControl();

    try {
      await RingtoneManager.stopRingtone();
      FlutterRingtonePlayer().stop();
    } catch (e) {
      await RingtoneManager.dispose();
      debugPrint('[CALL] Error stopping ringtone in accept');
    }

    // For outgoing calls, delay timer start until WebRTC connects (onConnectionState)
    // For incoming calls, start timer immediately
    if (!isOutgoing) {
      _startCallTimer();
    }

    // Transition native call screen
    await NativeCallScreen.updateCallState(
      callMode: isOutgoing ? 'connecting' : 'in_call',
      isMuted: _activeCall!.isMuted,
      isSpeakerOn: _activeCall!.isSpeakerOn,
    );
    await NativeCallScreen.dismissIncomingNotification();
    await NativeCallScreen.showOngoingNotification(
      callId: _activeCall!.callId,
      callerName: _activeCall!.userName,
      callerPhoto: _activeCall!.userProfilePic,
    );

    // Start foreground service to keep microphone active in background
    await CallForegroundService.startService(callerName: _activeCall!.userName);

    // Enable lock screen flags for call
    await _enableLockScreenFlags();

    // For outgoing calls, create offer immediately
    // For incoming calls, wait for offer from caller
    if (isOutgoing) {
      _createOffer();
    }
    // For incoming calls, the peer connection will be created when offer arrives
  }

  /// Handle call offer message
  void _handleCallOffer(CallPayload payload) async {
    final offerPayload = _payloadDataToMap(payload);
    if (offerPayload != null) {
      // Update active call with callId if not set
      if (payload.callId != null && _activeCall != null) {
        _activeCall = _activeCall!.copyWith(callId: payload.callId);
      }
      _handleOffer(offerPayload, payload);
    }
  }

  /// Handle call answer message
  void _handleCallAnswer(CallPayload payload) async {
    final answerPayload = _payloadDataToMap(payload);
    if (answerPayload != null) {
      // Update active call with callId if not set
      if (payload.callId != null && _activeCall != null) {
        _activeCall = _activeCall!.copyWith(callId: payload.callId);
      }
      _handleAnswer(answerPayload);
    }
  }

  /// Handle call ice message
  void _handleCallIce(CallPayload payload) async {
    final icePayload = _payloadDataToMap(payload);
    if (icePayload != null) {
      // Update active call with callId if not set
      if (payload.callId != null && _activeCall != null) {
        _activeCall = _activeCall!.copyWith(callId: payload.callId);
      }
      _handleIceCandidate(icePayload);
    }
  }

  /// Handle call terminate message (replaces call:decline, call:end, call:missed)
  void _handleCallTerminate(CallPayload payload) async {
    if (_activeCall == null) {
      debugPrint('[CALL] Ignoring call:terminate for callId=${payload.callId} - no active call');
      return;
    }

    // Prevent concurrent termination from CallKit/endCall racing with this handler
    if (_isTerminating) {
      debugPrint('[CALL] Ignoring call:terminate for callId=${payload.callId} - already terminating');
      return;
    }
    _isTerminating = true;

    final isOutgoingCall = _activeCall!.callType == CallType.outgoing;
    final callIdMatches = payload.callId == null ||
                         _activeCall!.callId == payload.callId ||
                         _activeCall!.callId.isEmpty;

    if (!callIdMatches && !isOutgoingCall) {
      debugPrint('[CALL] Ignoring call:terminate for callId=${payload.callId} - callId mismatch. Active: ${_activeCall!.callId}');
      _isTerminating = false;
      return;
    }

    // Extract reason from payload data
    final reason = payload.data is Map 
        ? (payload.data as Map)['reason']?.toString() 
        : null;
    
    debugPrint('[CALL] Handling call:terminate for callId=${payload.callId}, reason=$reason, ActiveCallId: ${_activeCall!.callId}');
    
    FlutterRingtonePlayer().stop();
    
    // Update callId if provided and different (or if it was empty)
    if (payload.callId != null && (_activeCall!.callId != payload.callId || _activeCall!.callId.isEmpty)) {
      debugPrint('[CALL] Updating callId from ${_activeCall!.callId} to ${payload.callId}');
      _activeCall = _activeCall!.copyWith(callId: payload.callId);
    }

    // Cancel the call started timer
    _callStartedTimer?.cancel();
    _callStartedTimer = null;
    
    // Stop status polling
    _stopStatusPolling();
    
    // Set the appropriate terminal status so the UI can show it
    if (reason == 'declined' || reason == 'user_declined' || reason == 'caller_cancelled' || reason == 'declined_via_polling') {
      _activeCall = _activeCall!.copyWith(status: CallStatus.declined);
      debugPrint('[CALL] Call status updated to declined for callId=${_activeCall!.callId}');
    } else if (reason == 'timeout' || reason == 'missed' || reason == 'missed_via_polling') {
      _activeCall = _activeCall!.copyWith(status: CallStatus.missed);
      debugPrint('[CALL] Call status updated to missed for callId=${_activeCall!.callId}');
    } else {
      // Covers: 'caller_hungup', 'callee_hungup', 'user_hangup', 'abandoned',
      // 'network_error', 'busy', 'ended_via_polling', null, and any unknown reason
      _activeCall = _activeCall!.copyWith(status: CallStatus.ended);
      debugPrint('[CALL] Call status updated to ended for callId=${_activeCall!.callId}, reason=$reason');
    }

    // Stop ringtone
    try {
      await RingtoneManager.stopRingtone();
    } catch (e) {
      await RingtoneManager.dispose();
      debugPrint('[CALL] Error stopping ringtone in terminate');
    }

    // Dismiss native call screen and notifications
    await NativeCallScreen.dismissCallScreen();
    // FlutterCallkitIncoming - commented out, replaced by native call screen
    // await FlutterCallkitIncoming.endAllCalls();
    FlutterRingtonePlayer().stop();

    // Cleanup all call resources
    await _cleanup();
    
    debugPrint('[CALL] Call terminate handled and cleanup completed. _activeCall: ${_activeCall == null ? "null" : "NOT null (ERROR!)"}');
    _isTerminating = false;
  }

  /// Handle call error message
  void _handleCallError(CallPayload payload) async {
    debugPrint('[CALL] Call error received: ${payload.error}');

    // Extract error code and message
    String errorMessage = 'Call failed';
    String? errorCode;

    if (payload.error != null) {
      if (payload.error is Map) {
        final errorMap = payload.error as Map;
        errorCode = errorMap['code']?.toString();
        errorMessage = errorMap['message']?.toString() ?? errorMessage;
        debugPrint('[CALL] Error code: $errorCode, message: $errorMessage');
      } else if (payload.error is String) {
        errorMessage = payload.error as String;
      }
    }

    // Stop ringtone if playing
    try {
      await RingtoneManager.stopRingtone();
      FlutterRingtonePlayer().stop();
    } catch (e) {
      await RingtoneManager.dispose();
      debugPrint('[CALL] Error stopping ringtone in error handler: $e');
    }

    // Stop timers
    _callStartedTimer?.cancel();
    _callStartedTimer = null;
    _stopStatusPolling();
    FlutterRingtonePlayer().stop();
    // Navigate back from call screen if we're on it
    if (NavigationHelper.navigator != null) {
      try {
        final navigator = NavigationHelper.navigator!;

        // Pop back if we navigated to call screen
        if (navigator.canPop()) {
          navigator.pop();
        }
      } catch (e) {
        debugPrint('[CALL] Error navigating back from call screen: $e');
      }
    }

    // Show error message to user
    if (NavigationHelper.navigatorKey.currentContext != null) {
      // Special handling for USER_BUSY - might be stale backend state
      if (errorCode == 'USER_BUSY') {
        errorMessage =
            'User is busy. If this persists, please restart the app.';
      }

      Snack.error(errorMessage);
    }

    // Clean up call state - IMPORTANT: do this last
    _cleanup();
  }

  /// Handle incoming call
  void _handleIncomingCall(CallPayload payload) async {
    if (payload.callId == null) {
      debugPrint('[CALL] Incoming call missing callId');
      return;
    }

    // Dedup: WS + FCM can both fire for the same call; only process once
    if (_recentCallIds.contains(payload.callId!)) {
      debugPrint('[CALL] Duplicate callId=${payload.callId} ignored');
      return;
    }
    _recentCallIds.add(payload.callId!);
    Future.delayed(const Duration(seconds: 60), () => _recentCallIds.remove(payload.callId!));

    debugPrint('[CALL] Handling incoming call: callId=${payload.callId}, callerId=${payload.callerId}');
    debugPrint('[CALL] Current state - _activeCall: ${_activeCall != null ? "exists (callId=${_activeCall!.callId})" : "null"}, _pollingCallId: $_pollingCallId');

    // Stop any existing status polling FIRST to prevent it from clearing the new call
    if (_statusPollingTimer != null || _pollingCallId != null) {
      debugPrint('[CALL] Stopping existing status polling before processing new call');
      _stopStatusPolling();
      await Future.delayed(const Duration(milliseconds: 50)); // Small delay to ensure timer is cancelled
    }

    // If we already have an active call, check if it's the same call or a stale one
    if (_activeCall != null) {
      // If it's the same call, don't process again
      if (_activeCall!.callId == payload.callId) {
        debugPrint('[CALL] Already processing this incoming call');
        return;
      }
      // If it's a different call, clean up the stale one first
      final staleCallId = _activeCall!.callId;
      debugPrint(
        '[CALL] Cleaning up stale call (callId=$staleCallId) before processing new incoming call (callId=${payload.callId})',
      );
      await _cleanup();
      // Wait a bit to ensure cleanup is complete
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final callUtils = CallUtils();
    final existingCallDetails = await callUtils.getCallDetails();
    final storageCallStatus = existingCallDetails?.callStatus;
    final storageCallId = existingCallDetails?.callId;

    // Prefer the saved contact name over the server-provided username across
    // every incoming-call surface (stored details, in-app UI, native screen).
    final resolvedCallerName = await UserUtils()
            .preferredContactName(payload.callerId, payload.callerName) ??
        'Unknown';

    // Store call info in SharedPreferences for CallKit
    final callDetails = CallDetails(
      callId: payload.callId,
      callerId: payload.callerId,
      callerName: resolvedCallerName,
      callerProfilePic: payload.callerPfp,
      callStatus: 'ringing',
    );
    await callUtils.saveCallDetails(callDetails);

    // Set up the new incoming call state FIRST so UI can react
    _activeCall = ActiveCallState(
      callId: payload.callId!,
      userId: payload.callerId,
      userName: resolvedCallerName,
      userProfilePic: payload.callerPfp,
      callType: CallType.incoming,
      status: CallStatus.ringing,
      startTime: DateTime.now(),
    );

    debugPrint('[CALL] Set _activeCall: callId=${_activeCall!.callId}, status=${_activeCall!.status}');

    // IMPORTANT: Wait for Riverpod provider to sync state before navigation
    // The provider syncs every 200ms, but we need to wait longer to ensure sync happens
    await Future.delayed(const Duration(milliseconds: 500));

    // Verify _activeCall is still set (wasn't cleared by stale polling/handlers)
    if (_activeCall == null || _activeCall!.callId != payload.callId) {
      debugPrint('[CALL] ERROR: _activeCall was cleared before navigation! callId=${payload.callId}, _activeCall=${_activeCall?.callId}');
      return;
    }

    debugPrint('[CALL] Verified _activeCall is still set after delay: callId=${_activeCall!.callId}');

    // Show native incoming call screen (works on lock screen and in foreground)
    debugPrint('[CALL] 📱 Showing native incoming call screen for callId=${payload.callId}');

    // Show native call screen - handles both foreground and lock screen
    // Note: ringtone is handled by the CHANNEL_INCOMING notification channel on Android
    await NativeCallScreen.showIncomingCall(
      callId: payload.callId!,
      callerName: resolvedCallerName,
      callerPhoto: payload.callerPfp,
    );

    // FlutterCallkitIncoming - commented out, replaced by native call screen
    // if (isAppInForeground) {
    //   await FlutterCallkitIncoming.endAllCalls();
    //   NavigationHelper.pushNamed('/incoming-call');
    // } else {
    //   CallKitParams params = CallKitParams(...);
    //   await FlutterCallkitIncoming.showCallkitIncoming(params);
    // }

    // Start the 30-second timeout timer for incoming calls
    _startCallStartedTimer();

    // Delay status polling start to avoid 404 errors for new calls
    // Status polling will start after a delay to give the server time to create the call record
    Future.delayed(const Duration(milliseconds: 1000), () {
      // Verify call is still active before starting polling
      if (_activeCall != null && _activeCall!.callId == payload.callId) {
        debugPrint('[CALL] Starting status polling for callId=${payload.callId}');
        _startStatusPolling(payload.callId!);
      } else {
        debugPrint('[CALL] Skipping status polling - call no longer active');
      }
    });

    debugPrint(
      '[CALL] Incoming call processed: callId=${payload.callId}, callerId=${payload.callerId}',
    );
  }

  /// Handle call declined (internal helper)
  void _handleCallDeclinedInternal(Map<String, dynamic> message) async {
    final messageCallId = message['callId'];
    // Only cleanup if this matches the active call
    if (_activeCall == null || _activeCall!.callId != messageCallId) {
      debugPrint('[CALL] Ignoring call declined internal - callId mismatch or no active call. MessageCallId: $messageCallId, ActiveCallId: ${_activeCall?.callId}');
      return;
    }

    debugPrint('[CALL] Processing call declined internal for callId=$messageCallId');
    try {
      await RingtoneManager.stopRingtone();
    } catch (e) {
      await RingtoneManager.dispose();
      debugPrint('[CALL] Error stopping ringtone in declined');
    }
    _cleanup();
  }

  /// Handle call ended (internal helper)
  void _handleCallEndedInternal(Map<String, dynamic> message) async {
    final messageCallId = message['callId'];
    // Only cleanup if this matches the active call
    if (_activeCall == null || _activeCall!.callId != messageCallId) {
      debugPrint('[CALL] Ignoring call ended internal - callId mismatch or no active call. MessageCallId: $messageCallId, ActiveCallId: ${_activeCall?.callId}');
      return;
    }

    debugPrint('[CALL] Processing call ended internal for callId=$messageCallId');
    try {
      await RingtoneManager.stopRingtone();
    } catch (e) {
      await RingtoneManager.dispose();
      debugPrint('[CALL] Error stopping ringtone in ended');
    }
    _cleanup();
  }

  /// Cleanup call resources
  Future<void> _cleanup() async {
    try {
      debugPrint('[CALL] Starting cleanup...');

      // Reset termination guard
      _isTerminating = false;

      FlutterRingtonePlayer().stop();
      await RingtoneManager.stopRingtone();
      await RingtoneManager.dispose();
      
      // Stop status polling FIRST to prevent any further API calls
      _stopStatusPolling();
      debugPrint('[CALL] Status polling stopped during cleanup');

      // Stop foreground service first to remove notification
      await CallForegroundService.stopService();
      debugPrint('[CALL] Foreground service stopped');

      // Stop proximity control
      await _disableProximityControl();
      debugPrint('[CALL] Proximity control disabled');

      // Stop timers
      _callDurationTimer?.cancel();
      _callDurationTimer = null;
      _callStartedTimer?.cancel();
      _callStartedTimer = null;
      _offerRetryTimer?.cancel();
      _offerRetryTimer = null;
      _lastOfferMsg = null;
      debugPrint('[CALL] Timers cancelled');

      // Close peer connection
      await _peerConnection?.close();
      _peerConnection = null;
      debugPrint('[CALL] Peer connection closed');

      // Stop local stream
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      _localStream = null;
      _remoteStream = null;
      debugPrint('[CALL] Media streams stopped and cleared');

      // Clear call state
      final clearedCallId = _activeCall?.callId;
      _activeCall = null;
      debugPrint('[CALL] _activeCall cleared (was callId: $clearedCallId)');

      // Disable wakelock when call ends
      WakelockPlus.disable();
      debugPrint('[CALL] Wakelock disabled');
      
      // Double-check wakelock is disabled (sometimes it persists)
      await Future.delayed(const Duration(milliseconds: 100));
      if (await WakelockPlus.enabled) {
        WakelockPlus.disable();
        debugPrint('[CALL] Wakelock force-disabled after delay');
      }

      // Disable lock screen flags
      await _disableLockScreenFlags();

      // Clear SharedPreferences
      await CallUtils().clearCallDetails();
      debugPrint('[CALL] SharedPreferences cleared');

      debugPrint('[CALL] Cleanup completed successfully - _activeCall is now: ${_activeCall == null ? "null" : "NOT null (ERROR!)"}');
      
      // IMPORTANT: After cleanup, ensure state is truly null
      // Sometimes async operations might have set it again
      if (_activeCall != null) {
        debugPrint('[CALL] ERROR: _activeCall was set again during cleanup - forcing null');
        _activeCall = null;
      }
    } catch (e) {
      debugPrint('[CALL] Error during cleanup: $e');
      // Force clear active call even on error
      _activeCall = null;
      _pollingCallId = null;
      _statusPollingTimer?.cancel();
      _statusPollingTimer = null;
    }
  }

  /// Fetch call status from unprotected endpoint
  Future<Map<String, dynamic>?> _fetchCallStatus(String callId) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '${Environment.baseUrl}/call/status/$callId',
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        debugPrint(
          '[CALL] Failed to fetch call status: ${response.statusCode}',
        );
        // If call not found (404), stop polling as call no longer exists
        if (response.statusCode == 404) {
          debugPrint('[CALL] Call $callId not found (404) - stopping status polling');
          _stopStatusPolling();
        }
        return null;
      }
    } catch (e) {
      debugPrint('[CALL] Error fetching call status');
      debugPrint('error fetching call status: $e');
      // Check if it's a 404 error
      if (e is DioException && e.response?.statusCode == 404) {
        debugPrint('[CALL] Call $callId not found (404) - stopping status polling');
        _stopStatusPolling();
      }
      return null;
    }
  }

  /// Start polling for call status as fallback when WebSocket is not connected
  void _startStatusPolling(String callId) {
    if (_statusPollingTimer != null) {
      _statusPollingTimer?.cancel();
    }

    _pollingCallId = callId;
    debugPrint('[CALL] Starting status polling for callId: $callId');

    int pollCount = 0;
    const maxPolls = 15; // 30 seconds / 2 seconds = 15 polls

    _statusPollingTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      // Check if polling was stopped or call ID changed
      if (_pollingCallId == null || _pollingCallId != callId) {
        debugPrint('[CALL] Status polling stopped - callId mismatch or null. Current _pollingCallId: $_pollingCallId, Expected: $callId');
        timer.cancel();
        _statusPollingTimer = null;
        return;
      }

      // Check if active call still matches
      if (_activeCall == null || _activeCall!.callId != callId) {
        debugPrint('[CALL] Status polling stopped - active call changed or cleared. ActiveCallId: ${_activeCall?.callId}, Expected: $callId');
        timer.cancel();
        _statusPollingTimer = null;
        _pollingCallId = null;
        return;
      }

      pollCount++;

      // Stop polling after 30 seconds (15 polls)
      if (pollCount > maxPolls) {
        debugPrint('[CALL] Status polling stopped - max polls reached for callId: $callId');
        timer.cancel();
        _statusPollingTimer = null;
        _pollingCallId = null;
        return;
      }

      final statusResponse = await _fetchCallStatus(callId);
      
      // Check again if polling was stopped during fetch (e.g., by a 404 from _fetchCallStatus)
      if (_pollingCallId == null || _pollingCallId != callId) {
        debugPrint('[CALL] Status polling stopped during fetch - callId mismatch or null. Current _pollingCallId: $_pollingCallId, Expected: $callId');
        timer.cancel();
        _statusPollingTimer = null;
        return;
      }

      if (statusResponse != null && statusResponse['success'] == true) {
        final callData = statusResponse['data'];
        final status = callData['status'];

        // Verify this is still the active call before processing
        if (_activeCall == null || _activeCall!.callId != callId) {
          debugPrint('[CALL] Status polling stopped - callId mismatch or no active call after fetch. ActiveCallId: ${_activeCall?.callId}, Expected: $callId');
          timer.cancel();
          _statusPollingTimer = null;
          _pollingCallId = null;
          return;
        }

        if (status == 'declined' || status == 'ended') {
          debugPrint('[CALL] Status polling detected call $status for callId: $callId - stopping');
          timer.cancel();
          _statusPollingTimer = null;
          _pollingCallId = null;

          // Handle the call decline/end as if it came from WebSocket
          if (status == 'declined') {
            _handleCallDeclinedInternal({
              'callId': callId,
              'payload': {'reason': 'declined_via_polling'},
            });
          } else if (status == 'ended') {
            _handleCallEndedInternal({
              'callId': callId,
              'payload': {'reason': 'ended_via_polling'},
            });
          }
        }
      }
    });
  }

  /// Stop status polling
  void _stopStatusPolling() {
    if (_statusPollingTimer != null) {
      _statusPollingTimer?.cancel();
      _statusPollingTimer = null;
      _pollingCallId = null;
    }
  }

  /// Initialize proximity control for global screen lock
  Future<void> _initializeProximityControl() async {
    try {
      // Cancel existing subscription if any
      await _proximitySubscription?.cancel();

      // Start listening to proximity sensor events
      _proximitySubscription = ProximitySensor.events.listen((dynamic event) {
        bool isNear = false;
        if (event is int) {
          isNear = event > 0;
        } else if (event is double) {
          isNear = event > 0;
        } else if (event is Map) {
          isNear = event['isNear'] == true || event['near'] == true;
        } else if (event is bool) {
          isNear = event;
        }

        if (isNear) {
          _enableProximityLock();
        } else {
          _disableProximityLock();
        }
      });
    } catch (e) {
      debugPrint('[CALL] Error initializing proximity control');
    }
  }

  /// Enable proximity screen lock
  Future<void> _enableProximityLock() async {
    if (_isProximityScreenLocked) return;

    try {
      await ProximityScreenLock.setActive(true);
      _isProximityScreenLocked = true;
    } catch (e) {
      // Fallback to brightness control
      try {
        await ScreenBrightness().setScreenBrightness(0.0);
        _isProximityScreenLocked = true;
      } catch (e2) {
        debugPrint('[CALL] Error dimming screen');
      }
    }
  }

  /// Disable proximity screen lock
  Future<void> _disableProximityLock() async {
    if (!_isProximityScreenLocked) return;

    try {
      await ProximityScreenLock.setActive(false);
      _isProximityScreenLocked = false;
    } catch (e) {
      // Fallback to brightness control
      try {
        await ScreenBrightness().resetScreenBrightness();
        _isProximityScreenLocked = false;
      } catch (e2) {
        debugPrint('[CALL] Error restoring screen brightness');
      }
    }
  }

  /// Disable proximity control completely
  Future<void> _disableProximityControl() async {
    try {
      // Disable screen lock if active
      await _disableProximityLock();

      // Cancel proximity subscription
      await _proximitySubscription?.cancel();
      _proximitySubscription = null;
    } catch (e) {
      debugPrint('[CALL] Error disabling proximity control');
    }
  }

  /// Check if proximity control is active
  bool get isProximityControlActive => _proximitySubscription != null;

  /// Enable lock screen flags (show app on lock screen during calls)
  Future<void> _enableLockScreenFlags() async {
    try {
      await _lockScreenChannel.invokeMethod('enableLockScreenFlags');
      debugPrint('[CALL] Lock screen flags enabled');
    } catch (e) {
      debugPrint('[CALL] Error enabling lock screen flags: $e');
    }
  }

  /// Disable lock screen flags (hide app from lock screen when no call)
  Future<void> _disableLockScreenFlags() async {
    try {
      await _lockScreenChannel.invokeMethod('disableLockScreenFlags');
      debugPrint('[CALL] Lock screen flags disabled');
    } catch (e) {
      debugPrint('[CALL] Error disabling lock screen flags: $e');
    }
  }

  /// Dispose service
  void dispose() {
    _callInitSubscription?.cancel();
    _callInitAckSubscription?.cancel();
    _callOfferSubscription?.cancel();
    _callAnswerSubscription?.cancel();
    _callIceSubscription?.cancel();
    _callAcceptSubscription?.cancel();
    _callTerminateSubscription?.cancel();
    _callRingingSubscription?.cancel();
    _callErrorSubscription?.cancel();
    _cleanup();
  }
}
