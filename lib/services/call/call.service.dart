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
            final callDetails = await CallUtils().getCallDetails();

            await acceptCall(
              callId: callDetails?.callId,
              callerId: callDetails?.callerId,
              callerName: callDetails?.callerName,
              callerProfilePic: callDetails?.callerProfilePic,
            );

            // Navigator.popUntil(
            //   NavigationHelper.navigator!.context,
            //   (route) => route.isFirst,
            // );

            break;

          case Event.actionCallDecline:
            final callId = await CallUtils().getCallId();
            await declineCall(
              callId: callId,
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

      // Enable speaker by default for outgoing calls
      await Helper.setSpeakerphoneOn(true);

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
      // IMPORTANT: Ensure _activeCall is null before setting new call
      if (_activeCall != null) {
        debugPrint('[CALL] WARNING: _activeCall was not null before setting new call - clearing it');
        _activeCall = null;
        // Small delay to ensure state is cleared and provider syncs
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      _activeCall = ActiveCallState(
        callId: 0, // Will be updated from backend response
        userId: calleeId,
        userName: calleeName,
        userProfilePic: calleeProfilePic,
        callType: CallType.outgoing,
        status: CallStatus.initiated,
        startTime: DateTime.now(),
        isSpeakerOn: true, // Speaker enabled by default for outgoing calls
      );
      
      debugPrint('[CALL] ✅ New call state set: callId=${_activeCall!.callId}, status=${_activeCall!.status}, callType=${_activeCall!.callType}');
      debugPrint('[CALL] Provider should sync within 100ms - UI should update soon');

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

      // Enable speaker by default when call is accepted
      await Helper.setSpeakerphoneOn(true);
      // Small delay to ensure speaker is actually enabled before updating state
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Update call state with speaker enabled
      _activeCall = _activeCall!.copyWith(
        status: CallStatus.answered,
        isSpeakerOn: true,
      );
      
      debugPrint('[CALL] Call accepted - status: ${_activeCall!.status}, isSpeakerOn: ${_activeCall!.isSpeakerOn}');
      
      // Start timer immediately when call is accepted
      _startCallTimer();

      // Start foreground service to keep microphone active in background
      await CallForegroundService.startService(
        callerName: _activeCall!.userName,
      );

      await CallUtils().clearCallDetails();
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
        actualCallId = await CallUtils().getCallId();
      }

      if (actualCallId == null) {
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

      // End all CallKit calls FIRST before cleanup
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[CALL] Error ending CallKit calls: $e');
    }

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
    // For outgoing calls, we might receive accept even if callId doesn't match exactly
    // Check if we have an active outgoing call
    if (_activeCall == null) {
      debugPrint('[CALL] Ignoring call:accept - no active call');
      return;
    }

    // For outgoing calls, be more lenient with callId matching
    // The callId might be 0 initially and get updated later
    final isOutgoingCall = _activeCall!.callType == CallType.outgoing;
    final callIdMatches = payload.callId == null || 
                         _activeCall!.callId == payload.callId || 
                         _activeCall!.callId == 0;

    if (!callIdMatches && !isOutgoingCall) {
      debugPrint('[CALL] Ignoring call:accept - callId mismatch. Active: ${_activeCall!.callId}, Payload: ${payload.callId}');
      return;
    }

    debugPrint('[CALL] Handling call:accept for callId=${payload.callId ?? _activeCall!.callId}, ActiveCallId: ${_activeCall!.callId}');

    // Update callId if provided and different (or if it was 0)
    if (payload.callId != null && (_activeCall!.callId != payload.callId || _activeCall!.callId == 0)) {
      debugPrint('[CALL] Updating callId from ${_activeCall!.callId} to ${payload.callId}');
      _activeCall = _activeCall!.copyWith(callId: payload.callId);
    }

    // Cancel the call started timer since call is now accepted
    _callStartedTimer?.cancel();
    _callStartedTimer = null;

    // Stop status polling since call is now accepted
    _stopStatusPolling();

      // Enable speaker by default when call is accepted
      await Helper.setSpeakerphoneOn(true);
      // Small delay to ensure speaker is actually enabled before updating state
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Update status to answered - this is critical for UI updates
      // This works for both incoming and outgoing calls
      // IMPORTANT: Update status with speaker state in single atomic operation
    _activeCall = _activeCall!.copyWith(
      status: CallStatus.answered,
      isSpeakerOn: true,
    );
    
    // Verify state was set correctly
    if (_activeCall!.isSpeakerOn != true) {
      debugPrint('[CALL] WARNING: isSpeakerOn was not set correctly in _handleCallAccept! Retrying...');
      _activeCall = _activeCall!.copyWith(isSpeakerOn: true);
    }

    debugPrint('[CALL] Call status updated to answered for callId=${_activeCall!.callId}, isSpeakerOn=${_activeCall!.isSpeakerOn}');
    
    // Small delay to ensure UI has time to react to status change
    await Future.delayed(const Duration(milliseconds: 100));

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
    // For outgoing calls, be more lenient with callId matching
    if (_activeCall == null) {
      debugPrint('[CALL] Ignoring call:decline for callId=${payload.callId} - no active call');
      return;
    }

    final isOutgoingCall = _activeCall!.callType == CallType.outgoing;
    final callIdMatches = payload.callId == null || 
                         _activeCall!.callId == payload.callId || 
                         _activeCall!.callId == 0;

    if (!callIdMatches && !isOutgoingCall) {
      debugPrint('[CALL] Ignoring call:decline for callId=${payload.callId} - callId mismatch. Active: ${_activeCall!.callId}');
      return;
    }

    debugPrint('[CALL] Handling call:decline for callId=${payload.callId}, ActiveCallId: ${_activeCall!.callId}');
    
    // Update callId if provided and different (or if it was 0)
    if (payload.callId != null && (_activeCall!.callId != payload.callId || _activeCall!.callId == 0)) {
      debugPrint('[CALL] Updating callId from ${_activeCall!.callId} to ${payload.callId}');
      _activeCall = _activeCall!.copyWith(callId: payload.callId);
    }
    
    // IMPORTANT: Update status to declined BEFORE cleanup so UI can show it
    // This is especially important for outgoing calls where the caller needs to see "declined"
    _activeCall = _activeCall!.copyWith(status: CallStatus.declined);
    debugPrint('[CALL] Call status updated to declined for callId=${_activeCall!.callId}');
    
    // Cancel the call started timer since call is being declined
    _callStartedTimer?.cancel();
    _callStartedTimer = null;
    // Stop status polling since call is being declined
    _stopStatusPolling();
    
    // Wait a bit to allow UI to update before cleanup
    await Future.delayed(const Duration(milliseconds: 500));
    
    _handleCallDeclinedInternal(_createMessageMap(payload));
    await FlutterCallkitIncoming.endAllCalls();
  }

  /// Handle call end message
  void _handleCallEnd(CallPayload payload) async {
    // Only process if this call matches the active call
    if (_activeCall == null || _activeCall!.callId != payload.callId) {
      debugPrint('[CALL] Ignoring call:end for callId=${payload.callId} - not active call or no active call');
      return;
    }

    debugPrint('[CALL] Handling call:end for callId=${payload.callId}');
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
    // Only process if this call matches the active call
    if (_activeCall == null || _activeCall!.callId != payload.callId) {
      debugPrint('[CALL] Ignoring call:missed for callId=${payload.callId} - not active call or no active call');
      return;
    }

    debugPrint('[CALL] Handling call:missed for callId=${payload.callId}');
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

    // Store call info in SharedPreferences for CallKit
    final callDetails = CallDetails(
      callId: payload.callId,
      callerId: payload.callerId,
      callerName: payload.callerName ?? 'Unknown',
      callerProfilePic: payload.callerPfp,
      callStatus: 'ringing',
    );
    await callUtils.saveCallDetails(callDetails);

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

      // IMPORTANT: End any existing CallKit calls first to prevent green bar
      try {
        await FlutterCallkitIncoming.endAllCalls();
        debugPrint('[CALL] Ended any existing CallKit calls');
      } catch (e) {
        debugPrint('[CALL] Error ending CallKit calls: $e');
      }

      // Play ringtone for incoming call
      try {
        await RingtoneManager.playSystemRingtone();
        debugPrint('[CALL] Playing system ringtone for incoming call');
      } catch (e) {
        debugPrint('[CALL] Error playing system ringtone: $e');
      }

      // Navigate to incoming call screen
      await Future.delayed(const Duration(milliseconds: 100));
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
      debugPrint('[CALL] Error stopping ringtone in ended');
    }
    _cleanup();
  }

  /// Handle call missed (internal helper)
  void _handleCallMissedInternal(Map<String, dynamic> message) {
    final messageCallId = message['callId'];
    // Only cleanup if this matches the active call
    if (_activeCall == null || _activeCall!.callId != messageCallId) {
      debugPrint('[CALL] Ignoring call missed internal - callId mismatch or no active call. MessageCallId: $messageCallId, ActiveCallId: ${_activeCall?.callId}');
      return;
    }

    debugPrint('[CALL] Processing call missed internal for callId=$messageCallId');
    _cleanup();
  }

  /// Cleanup call resources
  Future<void> _cleanup() async {
    try {
      debugPrint('[CALL] Starting cleanup...');
      
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

      // Disable wakelock
      WakelockPlus.disable();
      debugPrint('[CALL] Wakelock disabled');

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
  void _startStatusPolling(int callId) {
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
