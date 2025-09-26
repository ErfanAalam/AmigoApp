import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/call_model.dart';
import '../services/websocket_service.dart';
import '../services/notification_service.dart';
import '../api/user.service.dart';
import '../utils/ringing_tone.dart';

class CallService extends ChangeNotifier {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Services
  final NotificationService _notificationService = NotificationService();

  // Call state
  ActiveCallState? _activeCall;
  bool _isInitialized = false;
  Timer? _callDurationTimer;
  StreamSubscription? _webSocketSubscription;

  Timer? _callStartedTimer;

  // WebRTC configuration - using Plan B for compatibility
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      // Add TURN servers here for production
      {
        'urls': 'turn:ui.gosecureserver.in:3478',
        'username': 'amigo',
        'credential': 'amigopass',
      },
    ],
    'sdpSemantics': 'plan-b', // Changed to plan-b for addStream compatibility
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
      // Setup WebSocket message listener
      _webSocketSubscription = WebSocketService().messageStream.listen(
        handleWebSocketMessage,
      );

      _isInitialized = true;
      print('[CALL] CallService initialized');
      print('[CALL] WebSocket connected: ${WebSocketService().isConnected}');
    } catch (e) {
      print('[CALL] Error initializing CallService: $e');
      throw Exception('Failed to initialize CallService: $e');
    }
  }

  /// Initiate an outgoing call
  Future<void> initiateCall(
    int calleeId,
    String calleeName,
    String? calleeProfilePic,
  ) async {
    try {
      if (!_isInitialized) await initialize();

      if (hasActiveCall) {
        throw Exception('Already in a call');
      }

      // Check if WebSocket is connected
      if (!WebSocketService().isConnected) {
        throw Exception(
          'WebSocket is not connected. Please check your connection.',
        );
      }

      // Enable wakelock
      WakelockPlus.enable();

      // Get user media
      await _setupLocalMedia();

      // Get current user info (for now using a simple approach)
      final currentUserName = await _getCurrentUserName();

      // Send call initiation message
      final message = {
        'type': 'call:init',
        'to': calleeId,
        'payload': {
          'callerName': currentUserName,
          'callerProfilePic': null, // TODO: Get from user service
        },
        'timestamp': DateTime.now().toIso8601String(),
      };
      await WebSocketService().sendMessage(message);

      // Set up local call state (will be updated when backend confirms)
      _activeCall = ActiveCallState(
        callId: 0, // Will be updated from backend response
        userId: calleeId,
        userName: calleeName,
        userProfilePic: calleeProfilePic,
        callType: CallType.outgoing,
        status: CallStatus.initiated,
        startTime: DateTime.now(),
      );

      notifyListeners();

      // Start the 30-second timeout timer
      _startCallStartedTimer();

      await RingtoneManager.playRingtone();
    } catch (e) {
      print('[CALL] Error initiating call: $e');
      await _cleanup();
      throw Exception('Failed to initiate call: $e');
    }
  }

  /// Accept an incoming call
  Future<void> acceptCall() async {
    try {
      if (_activeCall == null) {
        throw Exception('No active call to accept');
      }

      // Enable wakelock
      WakelockPlus.enable();

      // Setup local media if not already done
      if (_localStream == null) {
        await _setupLocalMedia();
      }

      // Send accept message
      final message = {
        'type': 'call:accept',
        'callId': _activeCall!.callId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await WebSocketService().sendMessage(message);

      // Cancel the call started timer since call is now accepted
      _callStartedTimer?.cancel();
      _callStartedTimer = null;

      // Update call state
      _activeCall = _activeCall!.copyWith(status: CallStatus.answered);
      // Start timer immediately when call is accepted
      _startCallTimer();
      notifyListeners();
    } catch (e) {
      print('[CALL] Error accepting call: $e');
      throw Exception('Failed to accept call: $e');
    }
  }

  /// Decline an incoming call
  Future<void> declineCall({String? reason}) async {
    try {
      if (_activeCall == null) {
        throw Exception('No active call to decline');
      }

      final message = {
        'type': 'call:decline',
        'callId': _activeCall!.callId,
        'payload': {'reason': reason ?? 'user_declined'},
        'timestamp': DateTime.now().toIso8601String(),
      };

      await WebSocketService().sendMessage(message);

      // Cancel the call started timer since call is being declined
      _callStartedTimer?.cancel();
      _callStartedTimer = null;

      await _cleanup();
      // notifyListeners();
    } catch (e) {
      print('[CALL] Error declining call: $e');
      await _cleanup();
    }
  }

  /// End the current call
  Future<void> endCall({String? reason}) async {
    try {
      if (_activeCall == null) {
        print('[CALL] No active call to end');
        return;
      }

      final message = {
        'type': 'call:end',
        'callId': _activeCall!.callId,
        'payload': {'reason': reason ?? 'user_hangup'},
        'timestamp': DateTime.now().toIso8601String(),
      };

      await WebSocketService().sendMessage(message);

      await RingtoneManager.stopRingtone();

      await _cleanup();
    } catch (e) {
      print('[CALL] Error ending call: $e');
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
      notifyListeners();
    }
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    if (_activeCall == null) return;

    final newSpeakerState = !_activeCall!.isSpeakerOn;
    await Helper.setSpeakerphoneOn(newSpeakerState);

    _activeCall = _activeCall!.copyWith(isSpeakerOn: newSpeakerState);
    notifyListeners();
  }

  /// Setup local media stream
  Future<void> _setupLocalMedia() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia(
        _mediaConstraints,
      );
    } catch (e) {
      print('[CALL] Error setting up local media: $e');
      throw Exception('Failed to access microphone: $e');
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
        notifyListeners();
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
      print('[CALL] Error creating peer connection: $e');
      throw Exception('Failed to create peer connection: $e');
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

      final message = {
        'type': 'call:offer',
        'callId': _activeCall!.callId,
        'to': _activeCall!.userId,
        'payload': {'sdp': offer.sdp, 'type': offer.type},
        'timestamp': DateTime.now().toIso8601String(),
      };

      await WebSocketService().sendMessage(message);
    } catch (e) {
      print('[CALL] Error creating offer: $e');
      throw Exception('Failed to create offer: $e');
    }
  }

  /// Handle incoming offer
  Future<void> _handleOffer(Map<String, dynamic> payload) async {
    try {
      if (_peerConnection == null) {
        await _createPeerConnection();
      }

      final offer = RTCSessionDescription(payload['sdp'], payload['type']);
      await _peerConnection!.setRemoteDescription(offer);

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      final message = {
        'type': 'call:answer',
        'callId': _activeCall!.callId,
        'to': _activeCall!.userId,
        'payload': {'sdp': answer.sdp, 'type': answer.type},
        'timestamp': DateTime.now().toIso8601String(),
      };

      await WebSocketService().sendMessage(message);
    } catch (e) {
      print('[CALL] Error handling offer: $e');
    }
  }

  /// Handle incoming answer
  Future<void> _handleAnswer(Map<String, dynamic> payload) async {
    try {
      if (_peerConnection == null) return;

      final answer = RTCSessionDescription(payload['sdp'], payload['type']);
      await _peerConnection!.setRemoteDescription(answer);
    } catch (e) {
      print('[CALL] Error handling answer: $e');
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
      print('[CALL] Error handling ICE candidate: $e');
    }
  }

  /// Send ICE candidate
  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    try {
      if (_activeCall == null) return;

      final message = {
        'type': 'call:ice',
        'callId': _activeCall!.callId,
        'to': _activeCall!.userId,
        'payload': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      await WebSocketService().sendMessage(message);
    } catch (e) {
      print('[CALL] Error sending ICE candidate: $e');
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
        notifyListeners();
      }
    });
  }

  void _startCallStartedTimer() {
    if (_callStartedTimer != null) return;

    // Start the 30-second timeout timer when call is initiated
    _callStartedTimer = Timer(const Duration(seconds: 30), () async {
      // If call is still not accepted after 30 seconds, decline it automatically
      if (_activeCall != null && _activeCall!.status != CallStatus.answered) {
        print(
          '[CALL] Call not accepted within 30 seconds, declining automatically',
        );
        declineCall(reason: 'timeout');
        await RingtoneManager.stopRingtone();
      }
    });
  }

  /// Handle WebSocket messages
  void handleWebSocketMessage(Map<String, dynamic> message) async {
    final type = message['type'] as String?;
    if (type == null) {
      return;
    }

    if (!type.startsWith('call:')) {
      // Not a call-related message - ignore silently
      return;
    }

    switch (type) {
      case 'call:init':
        // Acknowledgment from server with callId
        if (message['data']?['success'] == true) {
          final callId = message['data']['callId'];
          _activeCall = _activeCall?.copyWith(callId: callId);
          notifyListeners();
        } else {
          _cleanup();
        }
        break;

      case 'call:ringing':
        // Incoming call notification
        _handleIncomingCall(message);
        break;

      case 'call:accept':
        // Call was accepted, start WebRTC
        if (_activeCall?.callType == CallType.outgoing) {
          // Cancel the call started timer since call is now accepted
          _callStartedTimer?.cancel();
          _callStartedTimer = null;

          _activeCall = _activeCall?.copyWith(status: CallStatus.answered);
          _createOffer();
          await RingtoneManager.stopRingtone();
          // Start timer immediately when call is accepted
          _startCallTimer();
          notifyListeners();
        }
        break;

      case 'call:offer':
        _handleOffer(message['payload']);
        break;

      case 'call:answer':
        _handleAnswer(message['payload']);
        break;

      case 'call:ice':
        _handleIceCandidate(message['payload']);
        break;

      case 'call:decline':
        // Cancel the call started timer since call is being declined
        _callStartedTimer?.cancel();
        _callStartedTimer = null;
        _handleCallDeclined(message);
        break;

      case 'call:end':
        // Cancel the call started timer since call is ending
        _callStartedTimer?.cancel();
        _callStartedTimer = null;
        _handleCallEnded(message);
        break;

      case 'call:missed':
        // Cancel the call started timer since call is missed
        _callStartedTimer?.cancel();
        _callStartedTimer = null;
        _handleCallMissed(message);
        break;
    }
  }

  /// Handle incoming call
  void _handleIncomingCall(Map<String, dynamic> message) {
    final callId = message['callId'];
    final from = message['from'];
    final payload = message['payload'];

    print(
      '[CALL] Handling incoming call - callId: $callId, from: $from, payload: $payload',
    );

    // Check if we already have an active call
    if (_activeCall != null) {
      return;
    }

    _activeCall = ActiveCallState(
      callId: callId,
      userId: from,
      userName: payload['callerName'] ?? 'Unknown',
      userProfilePic: payload['callerProfilePic'],
      callType: CallType.incoming,
      status: CallStatus.ringing,
      startTime: DateTime.now(),
    );

    // Start the 30-second timeout timer for incoming calls
    _startCallStartedTimer();

    // Show incoming call notification
    _notificationService.showCallNotification(
      title:
          'Incoming ${payload['callType'] == 'video' ? 'Video' : 'Audio'} Call',
      body: '${payload['callerName'] ?? 'Unknown'} is calling you',
      data: {
        'callId': callId.toString(),
        'callerId': from,
        'callerName': payload['callerName'] ?? 'Unknown',
        'callType': payload['callType'] ?? 'audio',
        'callerProfilePic': payload['callerProfilePic'],
        'action': 'tap', // Default action for notification tap
      },
    );

    notifyListeners();
  }

  /// Handle call declined
  void _handleCallDeclined(Map<String, dynamic> message) async {
    await RingtoneManager.stopRingtone();
    _cleanup();
  }

  /// Handle call ended
  void _handleCallEnded(Map<String, dynamic> message) async {
    await RingtoneManager.stopRingtone();
    _cleanup();
  }

  /// Handle call missed
  void _handleCallMissed(Map<String, dynamic> message) {
    _cleanup();
  }

  /// Cleanup call resources
  Future<void> _cleanup() async {
    try {
      // Stop timers
      _callDurationTimer?.cancel();
      _callDurationTimer = null;
      _callStartedTimer?.cancel();
      _callStartedTimer = null;

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

      notifyListeners();
    } catch (e) {
      print('[CALL] Error during cleanup: $e');
    }
  }

  /// Get current user name from API
  Future<String> _getCurrentUserName() async {
    try {
      final userService = UserService();
      final response = await userService.getUser();

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];
        return userData['name'] ?? 'Unknown User';
      } else {
        return 'Unknown User';
      }
    } catch (e) {
      print('[CALL] Error getting current user name: $e');
      return 'Unknown User';
    }
  }

  /// Dispose service
  @override
  void dispose() {
    _webSocketSubscription?.cancel();
    _cleanup();
    super.dispose();
  }
}
