import 'dart:async';
import 'package:amigo/env.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:proximity_screen_lock/proximity_screen_lock.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../models/call.model.dart';
import '../../models/user.model.dart';
import '../../types/socket.types.dart';
import '../../utils/navigation-helper.util.dart';
import '../../utils/ringtone.util.dart';
import '../socket/websocket.service.dart';
import '../socket/ws-message.handler.dart';
import 'call-foreground.service.dart';

class CallService {
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
  Timer? _callDurationTimer;
  Timer? _callStartedTimer;
  Timer? _statusPollingTimer;
  int? _pollingCallId;

  final WebSocketService _webSocketService = WebSocketService();

  // Call stream subscriptions
  StreamSubscription<CallPayload>? _callInitSubscription;
  StreamSubscription<CallPayload>? _callInitAckSubscription;
  StreamSubscription<CallPayload>? _callOfferSubscription;
  StreamSubscription<CallPayload>? _callAnswerSubscription;
  StreamSubscription<CallPayload>? _callIceSubscription;
  StreamSubscription<CallPayload>? _callAcceptSubscription;
  StreamSubscription<CallPayload>? _callDeclineSubscription;
  StreamSubscription<CallPayload>? _callEndSubscription;
  StreamSubscription<CallPayload>? _callRingingSubscription;
  StreamSubscription<CallPayload>? _callMissedSubscription;
  StreamSubscription<CallPayload>? _callErrorSubscription;

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
  bool get isInCall => _activeCall?.status == CallStatus.answered;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// Initialize the call service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _currentUser = await UserUtils().getUserDetails();

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
      _callDeclineSubscription = handler.callDeclineStream.listen(
        _handleCallDecline,
      );
      _callEndSubscription = handler.callEndStream.listen(_handleCallEnd);
      _callRingingSubscription = handler.callRingingStream.listen(
        _handleIncomingCall,
      );
      _callMissedSubscription = handler.callMissedStream.listen(
        _handleCallMissed,
      );
      _callErrorSubscription = handler.callErrorStream.listen(_handleCallError);

      _isInitialized = true;

      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
        switch (event?.event) {
          case Event.actionCallAccept:
            // Get call details from event or SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            final callIdStr = prefs.getString('current_call_id');
            final callerIdStr = prefs.getString('current_caller_id');
            final callerName = prefs.getString('current_caller_name');
            final callerProfilePic = prefs.getString(
              'current_caller_profile_pic',
            );

            await acceptCall(
              callId: callIdStr != null ? int.tryParse(callIdStr) : null,
              callerId: callerIdStr != null ? int.tryParse(callerIdStr) : null,
              callerName: callerName,
              callerProfilePic: callerProfilePic,
            );

            // Navigator.popUntil(
            //   NavigationHelper.navigator!.context,
            //   (route) => route.isFirst,
            // );

            break;

          case Event.actionCallDecline:
            final prefs = await SharedPreferences.getInstance();
            final callIdStr = prefs.getString('current_call_id');
            await declineCall(
              callId: callIdStr != null ? int.tryParse(callIdStr) : null,
            );
            break;

          case Event.actionCallEnded:
            endCall();
            break;

          default:
            debugPrint('🔔 Unhandled CallKit event: ${event?.event}');
            break;
        }
      });
    } catch (e) {
      debugPrint('[CALL] Error initializing CallService');
    }
  }

  /// Initiate an outgoing call
  Future<void> initiateCall(
    int calleeId,
    String calleeName,
    String? calleeProfilePic,
  ) async {
    try {
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

      if (hasActiveCall) {
        debugPrint('[CALL] Already has active call, cannot initiate new call');
        return;
      }

      // Check if WebSocket is connected
      if (!_webSocketService.isConnected) {
        debugPrint('[CALL] WebSocket not connected, connecting...');
        await _webSocketService.connect();
        // Wait for connection to stabilize
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Verify WebSocket is still connected
      if (!_webSocketService.isConnected) {
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

      // Enable wakelock
      await WakelockPlus.enable();

      // Get user media
      await _setupLocalMedia();

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
        await _webSocketService.sendMessage(wsmsg);
        debugPrint('[CALL] Call init message sent successfully');
      } catch (e) {
        debugPrint('❌ Error sending call:init: $e');
        await _cleanup();
        rethrow;
      }

      // Set up local call state AFTER successfully sending message
      // This will be updated when backend confirms via call:init:ack or call:ringing
      _activeCall = ActiveCallState(
        callId: 0, // Will be updated from backend response
        userId: calleeId,
        userName: calleeName,
        userProfilePic: calleeProfilePic,
        callType: CallType.outgoing,
        status: CallStatus.initiated,
        startTime: DateTime.now(),
      );

      // Start the 30-second timeout timer
      _startCallStartedTimer();

      // Start status polling as fallback (will be updated when we get the actual callId)
      // Note: We'll start polling after we get the callId from the server response

      try {
        await RingtoneManager.playRingtone();
      } catch (e) {
        await RingtoneManager.playSystemRingtone();
      }
    } catch (e) {
      debugPrint('[CALL] Failed to initiate call: $e');
      await _cleanup();
      rethrow;
    }
  }

  /// Restore call state from SharedPreferences
  Future<void> restoreCallState(
    int callId,
    int callerId,
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
    int? callId,
    int? callerId,
    String? callerName,
    String? callerProfilePic,
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

      // Enable wakelock
      WakelockPlus.enable();

      // Enable global proximity control for screen lock
      _initializeProximityControl();

      // Setup local media if not already done
      if (_localStream == null) {
        await _setupLocalMedia();
      }

      if (_currentUser == null) return;

      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      final callAcceptPayload = CallPayload(
        callId: _activeCall!.callId,
        callerId: _activeCall!.userId, // Use caller from active call
        calleeId: _currentUser!.id,
        timestamp: DateTime.now(),
      );

      final wsmsg = WSMessage(
        type: WSMessageType.callAccept,
        payload: callAcceptPayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      _webSocketService.sendMessage(wsmsg).catchError((e) {
        debugPrint('❌ Error sending call:accept: $e');
      });

      // Cancel the call started timer since call is now accepted
      _callStartedTimer?.cancel();
      _callStartedTimer = null;

      // Update call state
      _activeCall = _activeCall!.copyWith(status: CallStatus.answered);
      // Start timer immediately when call is accepted
      _startCallTimer();

      // Start foreground service to keep microphone active in background
      await CallForegroundService.startService(
        callerName: _activeCall!.userName,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_call_id');
      await prefs.remove('current_caller_id');
      await prefs.remove('current_caller_name');
      await prefs.remove('current_caller_profile_pic');
      await prefs.remove('call_status');
    } catch (e) {
      debugPrint('[CALL] Error accepting call');
    }
  }

  /// Decline an incoming call or cancel an outgoing call
  Future<void> declineCall({String? reason, int? callId}) async {
    try {
      // Get callId from parameter, active call, or SharedPreferences
      int? actualCallId = callId;

      if (actualCallId == null && _activeCall != null) {
        actualCallId = _activeCall!.callId;
      }

      if (actualCallId == null) {
        final prefs = await SharedPreferences.getInstance();
        final callIdStr = prefs.getString('current_call_id');
        if (callIdStr != null) {
          actualCallId = int.tryParse(callIdStr);
        }
      }

      if (actualCallId == null) {
        debugPrint('[CALL] No callId available to decline');
        await _cleanup();
        return;
      }

      // If we have callId but no active call, try to restore from SharedPreferences
      if (_activeCall == null) {
        final prefs = await SharedPreferences.getInstance();
        final callerIdStr = prefs.getString('current_caller_id');
        final callerName = prefs.getString('current_caller_name');
        final callerProfilePic = prefs.getString('current_caller_profile_pic');

        if (callerIdStr != null && callerName != null) {
          await restoreCallState(
            actualCallId,
            int.parse(callerIdStr),
            callerName,
            callerProfilePic,
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
      int? actualCallerId;
      int? actualCalleeId;

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
        final prefs = await SharedPreferences.getInstance();
        final callerIdStr = prefs.getString('current_caller_id');
        if (callerIdStr != null) {
          actualCallerId = int.tryParse(callerIdStr);
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
        type: WSMessageType.callDecline,
        payload: callDeclinePayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      // Send decline message and wait for it
      try {
        await _webSocketService.sendMessage(wsmsg);
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
        debugPrint('[CALL] Error stopping ringtone in decline: $e');
      }

      // End all CallKit calls
      await FlutterCallkitIncoming.endAllCalls();

      // Clean up state
      await _cleanup();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_call_id');
      await prefs.remove('current_caller_id');
      await prefs.remove('current_caller_name');
      await prefs.remove('current_caller_profile_pic');
      await prefs.remove('call_status');
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
        type: WSMessageType.callEnd,
        payload: callEndPayload,
        wsTimestamp: DateTime.now(),
      ).toJson();

      _webSocketService.sendMessage(wsmsg).catchError((e) {
        debugPrint('❌ Error sending call:end: $e');
      });

      try {
        await RingtoneManager.stopRingtone();
      } catch (e) {
        debugPrint('[CALL] Error stopping ringtone: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_call_id');
      await prefs.remove('current_caller_id');
      await prefs.remove('current_caller_name');
      await prefs.remove('current_caller_profile_pic');
      await prefs.remove('call_status');

      await _cleanup();
    } catch (e) {
      debugPrint('[CALL] Error ending call');
      await _cleanup();
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
    }
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    if (_activeCall == null) return;

    final newSpeakerState = !_activeCall!.isSpeakerOn;
    await Helper.setSpeakerphoneOn(newSpeakerState);

    _activeCall = _activeCall!.copyWith(isSpeakerOn: newSpeakerState);
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
        // Timer is now started when call is accepted, not when connection is established
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

      _webSocketService.sendMessage(wsmsg).catchError((e) {
        debugPrint('❌ Error sending call:offer: $e');
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

      _webSocketService.sendMessage(wsmsg).catchError((e) {
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

      _webSocketService.sendMessage(wsmsg).catchError((e) {
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

  /// Helper to create message map for methods that expect it
  Map<String, dynamic> _createMessageMap(CallPayload payload) {
    final payloadMap = _payloadDataToMap(payload);
    return {
      'callId': payload.callId,
      'payload': payloadMap ?? {},
      if (payloadMap != null) ...payloadMap,
    };
  }

  /// Handle call init message
  void _handleCallInit(CallPayload payload) async {
    final payloadMap = _payloadDataToMap(payload);
    if (payloadMap?['success'] == true || payload.data?['success'] == true) {
      final callId = payload.callId;
      if (callId != null) {
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
    if (callId != null) {
      _activeCall = _activeCall?.copyWith(callId: callId);
      _startStatusPolling(callId);
    }
  }

  /// Handle call accept message
  void _handleCallAccept(CallPayload payload) async {
    if (_activeCall == null) return;

    // Update callId if provided
    if (payload.callId != null) {
      _activeCall = _activeCall!.copyWith(callId: payload.callId);
    }

    // Cancel the call started timer since call is now accepted
    _callStartedTimer?.cancel();
    _callStartedTimer = null;

    // Stop status polling since call is now accepted
    _stopStatusPolling();

    // Update status to answered - this is critical for UI updates
    _activeCall = _activeCall!.copyWith(status: CallStatus.answered);

    // Enable global proximity control
    _initializeProximityControl();

    try {
      await RingtoneManager.stopRingtone();
    } catch (e) {
      debugPrint('[CALL] Error stopping ringtone in accept');
    }

    // Start timer immediately when call is accepted
    // This sets the startTime and starts updating duration every second
    _startCallTimer();

    // Start foreground service to keep microphone active in background
    await CallForegroundService.startService(callerName: _activeCall!.userName);

    // For outgoing calls, create offer immediately
    // For incoming calls, wait for offer from caller
    if (_activeCall!.callType == CallType.outgoing) {
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

  /// Handle call decline message
  void _handleCallDecline(CallPayload payload) async {
    // Cancel the call started timer since call is being declined
    _callStartedTimer?.cancel();
    _callStartedTimer = null;
    // Stop status polling since call is being declined
    _stopStatusPolling();
    _handleCallDeclinedInternal(_createMessageMap(payload));
    await FlutterCallkitIncoming.endAllCalls();
  }

  /// Handle call end message
  void _handleCallEnd(CallPayload payload) async {
    // Cancel the call started timer since call is ending
    _callStartedTimer?.cancel();
    _callStartedTimer = null;
    // Stop status polling since call is ending
    _stopStatusPolling();
    _handleCallEndedInternal(_createMessageMap(payload));
    await FlutterCallkitIncoming.endAllCalls();
  }

  /// Handle call missed message
  void _handleCallMissed(CallPayload payload) async {
    // Cancel the call started timer since call is missed
    _callStartedTimer?.cancel();
    _callStartedTimer = null;
    // Stop status polling since call is missed
    _stopStatusPolling();
    _handleCallMissedInternal(_createMessageMap(payload));
    await FlutterCallkitIncoming.endAllCalls();
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
    } catch (e) {
      debugPrint('[CALL] Error stopping ringtone in error handler: $e');
    }

    // Stop timers
    _callStartedTimer?.cancel();
    _callStartedTimer = null;
    _stopStatusPolling();

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
      final context = NavigationHelper.navigatorKey.currentContext!;

      // Special handling for USER_BUSY - might be stale backend state
      if (errorCode == 'USER_BUSY') {
        errorMessage =
            'User is busy. If this persists, please restart the app.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: const Color(0xFFEF4444), // Red color
          duration: const Duration(seconds: 4),
        ),
      );
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

    // If we already have an active call, check if it's the same call or a stale one
    if (_activeCall != null) {
      // If it's the same call, don't process again
      if (_activeCall!.callId == payload.callId) {
        debugPrint('[CALL] Already processing this incoming call');
        return;
      }
      // If it's a different call, clean up the stale one first
      debugPrint(
        '[CALL] Cleaning up stale call before processing new incoming call',
      );
      await _cleanup();
    }

    final prefs = await SharedPreferences.getInstance();
    final storageCallStatus = prefs.getString('call_status');
    final storageCallId = prefs.getString('current_call_id');

    // Store call info in SharedPreferences for CallKit
    await prefs.setString('current_call_id', payload.callId.toString());
    await prefs.setString('current_caller_id', payload.callerId.toString());
    await prefs.setString(
      'current_caller_name',
      payload.callerName ?? 'Unknown',
    );
    if (payload.callerPfp != null) {
      await prefs.setString('current_caller_profile_pic', payload.callerPfp!);
    }
    await prefs.setString('call_status', 'ringing');

    // Set up the new incoming call state FIRST so UI can react
    _activeCall = ActiveCallState(
      callId: payload.callId!,
      userId: payload.callerId,
      userName: payload.callerName ?? 'Unknown',
      userProfilePic: payload.callerPfp,
      callType: CallType.incoming,
      status: CallStatus.ringing,
      startTime: DateTime.now(),
    );

    // Check if app is in foreground - if so, navigate to incoming call screen instead of showing notification
    // The navigator being available indicates the app is in foreground
    final bool isAppInForeground =
        NavigationHelper.navigator != null &&
        NavigationHelper.navigatorKey.currentContext != null;

    debugPrint('[CALL] Incoming call - isAppInForeground: $isAppInForeground');

    if (isAppInForeground) {
      // App is in foreground - show incoming call screen directly
      debugPrint(
        '[CALL] 📱 App is in foreground - navigating to incoming call screen',
      );

      // Play ringtone for incoming call
      try {
        await RingtoneManager.playRingtone();
      } catch (e) {
        await RingtoneManager.playSystemRingtone();
      }

      // Navigate to incoming call screen
      NavigationHelper.pushNamed('/incoming-call');
    } else {
      // App is in background or closed - show CallKit notification
      debugPrint(
        '[CALL] 📱 App is NOT in foreground - showing CallKit notification',
      );

      CallKitParams params = CallKitParams(
        id: payload.callId.toString(),
        nameCaller: payload.callerName ?? 'Unknown',
        appName: 'amigo',
        avatar: payload.callerPfp ?? '',
        handle: '1234567890',
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
        extra: <String, dynamic>{'userId': payload.calleeId},
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

      // Show CallKit notification if not already answered
      if (storageCallStatus != 'answered' &&
          storageCallId != payload.callId.toString()) {
        await FlutterCallkitIncoming.showCallkitIncoming(params);
      }
    }

    // Start the 30-second timeout timer for incoming calls
    _startCallStartedTimer();

    // Start status polling as fallback for incoming calls too
    _startStatusPolling(payload.callId!);

    debugPrint(
      '[CALL] Incoming call processed: callId=${payload.callId}, callerId=${payload.callerId}',
    );
  }

  /// Handle call declined (internal helper)
  void _handleCallDeclinedInternal(Map<String, dynamic> message) async {
    try {
      await RingtoneManager.stopRingtone();
    } catch (e) {
      debugPrint('[CALL] Error stopping ringtone in declined');
    }
    _cleanup();
  }

  /// Handle call ended (internal helper)
  void _handleCallEndedInternal(Map<String, dynamic> message) async {
    try {
      await RingtoneManager.stopRingtone();
    } catch (e) {
      debugPrint('[CALL] Error stopping ringtone in ended');
    }
    _cleanup();
  }

  /// Handle call missed (internal helper)
  void _handleCallMissedInternal(Map<String, dynamic> message) {
    _cleanup();
  }

  /// Cleanup call resources
  Future<void> _cleanup() async {
    try {
      // Stop foreground service first to remove notification
      await CallForegroundService.stopService();

      // Stop proximity control
      await _disableProximityControl();

      // Stop timers
      _callDurationTimer?.cancel();
      _callDurationTimer = null;
      _callStartedTimer?.cancel();
      _callStartedTimer = null;

      // Stop status polling
      _stopStatusPolling();

      // Close peer connection
      await _peerConnection?.close();
      _peerConnection = null;

      // Stop local stream
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      _localStream = null;
      _remoteStream = null;

      // Clear call state
      _activeCall = null;

      // Disable wakelock
      WakelockPlus.disable();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_call_id');
      await prefs.remove('current_caller_id');
      await prefs.remove('current_caller_name');
      await prefs.remove('current_caller_profile_pic');
      await prefs.remove('call_status');
    } catch (e) {
      debugPrint('[CALL] Error during cleanup');
    }
  }

  /// Fetch call status from unprotected endpoint
  Future<Map<String, dynamic>?> _fetchCallStatus(int callId) async {
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
        return null;
      }
    } catch (e) {
      debugPrint('[CALL] Error fetching call status');
      return null;
    }
  }

  /// Start polling for call status as fallback when WebSocket is not connected
  void _startStatusPolling(int callId) {
    if (_statusPollingTimer != null) {
      _statusPollingTimer?.cancel();
    }

    _pollingCallId = callId;

    int pollCount = 0;
    const maxPolls = 15; // 30 seconds / 2 seconds = 15 polls

    _statusPollingTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      if (_pollingCallId == null) {
        timer.cancel();
        return;
      }

      pollCount++;

      // Stop polling after 30 seconds (15 polls)
      if (pollCount > maxPolls) {
        timer.cancel();
        _statusPollingTimer = null;
        _pollingCallId = null;
        return;
      }

      final statusResponse = await _fetchCallStatus(callId);
      if (statusResponse != null && statusResponse['success'] == true) {
        final callData = statusResponse['data'];
        final status = callData['status'];

        if (status == 'declined' || status == 'ended') {
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

  /// Dispose service
  void dispose() {
    _callInitSubscription?.cancel();
    _callInitAckSubscription?.cancel();
    _callOfferSubscription?.cancel();
    _callAnswerSubscription?.cancel();
    _callIceSubscription?.cancel();
    _callAcceptSubscription?.cancel();
    _callDeclineSubscription?.cancel();
    _callEndSubscription?.cancel();
    _callRingingSubscription?.cancel();
    _callMissedSubscription?.cancel();
    _callErrorSubscription?.cancel();
    _cleanup();
  }
}
