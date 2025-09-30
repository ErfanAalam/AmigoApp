import 'dart:async';
import 'package:amigo/api/api_service.dart';
import 'package:amigo/utils/navigation_helper.dart';
import 'package:amigo/env.dart';
import 'package:dio/dio.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Timer? _statusPollingTimer;
  int? _pollingCallId;

  // WebRTC configuration - using Plan B for compatibility
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'}, // STUN fallback
      {
        'urls': [
          'turn:43.205.144.169:3478?transport=udp',
          'turn:43.205.144.169:3478?transport=tcp',
        ],
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
      // Setup WebSocket message listener
      _webSocketSubscription = WebSocketService().messageStream.listen(
        handleWebSocketMessage,
      );

      _isInitialized = true;

      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
        print('🔔 CallKit event received: ${event?.event}');
        print('🔔 Full event data: $event');
        print('🔔 Event type: ${event?.event.runtimeType}');
        switch (event?.event) {
          case Event.actionCallAccept:
            acceptCall();

            print(
              "--------------------------------------------------------------------------------",
            );
            final jfkdjfd = event?.body;
            print("event -> $jfkdjfd");
            print(
              "--------------------------------------------------------------------------------",
            );
            print("call accepted api request sent");

            // final res = await ApiService().authenticatedPut(
            //   '/call/accept',
            //   data: {'callId': , 'title': title},
            // );
            // print("res -> $res");

            Navigator.popUntil(
              NavigationHelper.navigator!.context,
              (route) => route.isFirst,
            );

            break;
          case Event.actionCallDecline:
            declineCall();
            print(
              "--------------------------------------------------------------------------------",
            );
            print("event -> ${event}");
            print(
              "--------------------------------------------------------------------------------",
            );
            print("call declined api request sent");
            break;
          case Event.actionCallEnded:
            endCall();
            break;
          case Event.actionCallIncoming:
            print('🔔 Incoming call event received');
            break;
          case Event.actionCallStart:
            print('🔔 Call started event received');
            break;
          case Event.actionCallToggleHold:
            print('🔔 Call toggle hold event received');
            break;
          case Event.actionCallToggleMute:
            print('🔔 Call toggle mute event received');
            break;
          case Event.actionCallToggleDmtf:
            print('🔔 Call toggle DTMF event received');
            break;
          case Event.actionCallToggleGroup:
            print('🔔 Call toggle group event received');
            break;
          case Event.actionCallToggleAudioSession:
            print('🔔 Call toggle audio session event received');
            break;
          case Event.actionDidUpdateDevicePushTokenVoip:
            print('🔔 Device push token updated event received');
            break;
          default:
            print('🔔 Unhandled CallKit event: ${event?.event}');
            print('🔔 Event data: $event');
            break;
        }
      });
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
          'callerProfilePic': calleeProfilePic,
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

      // Start status polling as fallback (will be updated when we get the actual callId)
      // Note: We'll start polling after we get the callId from the server response

      try {
        await RingtoneManager.playRingtone();
      } catch (e) {
        print('[CALL] Failed to play ringtone, using system sound: $e');
        await RingtoneManager.playSystemRingtone();
      }
    } catch (e) {
      print('[CALL] Error initiating call: $e');
      await _cleanup();
      throw Exception('Failed to initiate call: $e');
    }
  }

  /// Accept an incoming call
  Future<void> acceptCall({int? callId}) async {
    try {
      print(
        "--------------------------------------------------------------------------------",
      );
      print("recieved callId -> ${callId}");
      print(
        "--------------------------------------------------------------------------------",
      );
      if (_activeCall == null && callId == null) {
        throw Exception('No active call to accept');
      }

      if (callId != null) {
        print(
          "--------------------------------------------------------------------------------",
        );
        print("setting callId -> ${callId}");
        print(
          "--------------------------------------------------------------------------------",
        );
        _activeCall = _activeCall?.copyWith(callId: callId);
        print(
          "--------------------------------------------------------------------------------",
        );
        print("_activeCall -> ${_activeCall}");
        print(
          "--------------------------------------------------------------------------------",
        );

        // hasActiveCall is now updated and reflects the new _activeCall state
        print("hasActiveCall after update: $hasActiveCall");

        notifyListeners();
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
  Future<void> declineCall({String? reason, int? callId}) async {
    try {
      if (_activeCall == null && callId == null) {
        throw Exception('No active call to accept');
      }
      if (callId != null) {
        _activeCall = _activeCall?.copyWith(callId: callId);
        notifyListeners();
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

      try {
        await RingtoneManager.stopRingtone();
      } catch (e) {
        print('[CALL] Error stopping ringtone: $e');
      }

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
      print('[CALL] Setting up local media...');

      // Add a small delay to ensure audio system is ready
      await Future.delayed(const Duration(milliseconds: 200));

      _localStream = await navigator.mediaDevices.getUserMedia(
        _mediaConstraints,
      );
      print('[CALL] Local media setup successful');
    } catch (e) {
      print('[CALL] Error setting up local media: $e');

      // Retry once after a delay
      try {
        print('[CALL] Retrying local media setup...');
        await Future.delayed(const Duration(milliseconds: 500));

        _localStream = await navigator.mediaDevices.getUserMedia(
          _mediaConstraints,
        );
        print('[CALL] Local media setup successful on retry');
      } catch (retryError) {
        print('[CALL] Failed to setup local media even on retry: $retryError');
        throw Exception('Failed to access microphone: $retryError');
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
        try {
          await RingtoneManager.stopRingtone();
        } catch (e) {
          print('[CALL] Error stopping ringtone in timeout: $e');
        }
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

          // Start status polling as fallback when WebSocket might not be reliable
          _startStatusPolling(callId);

          notifyListeners();
        } else {
          _cleanup();
        }
        break;

      case 'call:ringing':
        // Incoming call notification
        print(
          "--------------------------------------------------------------------------------",
        );
        print("message -> ${message}");
        print(
          "--------------------------------------------------------------------------------",
        );
        _handleIncomingCall(message);
        break;

      case 'call:accept':
        // Call was accepted, start WebRTC
        if (_activeCall?.callType == CallType.outgoing) {
          // Cancel the call started timer since call is now accepted
          _callStartedTimer?.cancel();
          _callStartedTimer = null;

          // Stop status polling since call is now accepted
          _stopStatusPolling();

          _activeCall = _activeCall?.copyWith(status: CallStatus.answered);
          _createOffer();
          try {
            await RingtoneManager.stopRingtone();
          } catch (e) {
            print('[CALL] Error stopping ringtone in accept: $e');
          }
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
        // Stop status polling since call is being declined
        _stopStatusPolling();
        _handleCallDeclined(message);
        await FlutterCallkitIncoming.endAllCalls();
        break;

      case 'call:end':
        // Cancel the call started timer since call is ending
        _callStartedTimer?.cancel();
        _callStartedTimer = null;
        // Stop status polling since call is ending
        _stopStatusPolling();
        _handleCallEnded(message);
        await FlutterCallkitIncoming.endAllCalls();
        break;

      case 'call:missed':
        // Cancel the call started timer since call is missed
        _callStartedTimer?.cancel();
        _callStartedTimer = null;
        // Stop status polling since call is missed
        _stopStatusPolling();
        _handleCallMissed(message);
        await FlutterCallkitIncoming.endAllCalls();
        break;
    }
  }

  /// Handle incoming call
  void _handleIncomingCall(Map<String, dynamic> message) async {
    final callId = message['callId'];
    final from = message['from'];
    final payload = message['payload'];
    print(
      "--------------------------------------------------------------------------------",
    );
    print("📞 INCOMING CALL - callId: $callId, from: $from");
    print("payload -> ${payload}");
    print(
      "--------------------------------------------------------------------------------",
    );

    CallKitParams params = CallKitParams(
      id: callId.toString(),
      nameCaller: payload['callerName'] ?? 'Unknown',
      appName: 'amigo',
      avatar: payload['callerProfilePic'] ?? '',
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
      extra: <String, dynamic>{'userId': from},
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

    print('🔧 Showing CallKit notification for call: $callId');
    final prefs = await SharedPreferences.getInstance();
    final storageCallStatus = prefs.getString('call_status');
    print(
      "--------------------------------------------------------------------------------",
    );
    print("storageCallStatus -> ${storageCallStatus}");
    print(
      "--------------------------------------------------------------------------------",
    );
    final storageCallId = prefs.getString('current_call_id');
    print(
      "--------------------------------------------------------------------------------",
    );
    print("storageCallId -> ${storageCallId}");
    print(
      "--------------------------------------------------------------------------------",
    );
    if (storageCallStatus == 'answered' && storageCallId == callId.toString()) {
      print('✅ CallKit notification already shown for call: $callId');
    } else {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    }
    print('✅ CallKit notification shown successfully');

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

    // Start status polling as fallback for incoming calls too
    _startStatusPolling(callId);

    // CallKit notification is already shown above, no need for additional notification
    notifyListeners();
  }

  /// Handle call declined
  void _handleCallDeclined(Map<String, dynamic> message) async {
    try {
      await RingtoneManager.stopRingtone();
    } catch (e) {
      print('[CALL] Error stopping ringtone in declined: $e');
    }
    _cleanup();
  }

  /// Handle call ended
  void _handleCallEnded(Map<String, dynamic> message) async {
    try {
      await RingtoneManager.stopRingtone();
    } catch (e) {
      print('[CALL] Error stopping ringtone in ended: $e');
    }
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
        print('[CALL] Failed to fetch call status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[CALL] Error fetching call status: $e');
      return null;
    }
  }

  /// Start polling for call status as fallback when WebSocket is not connected
  void _startStatusPolling(int callId) {
    if (_statusPollingTimer != null) {
      _statusPollingTimer?.cancel();
    }

    _pollingCallId = callId;
    print('[CALL] Starting status polling for call: $callId');

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
        print('[CALL] Status polling timeout after 30 seconds, stopping...');
        timer.cancel();
        _statusPollingTimer = null;
        _pollingCallId = null;
        return;
      }

      final statusResponse = await _fetchCallStatus(callId);
      if (statusResponse != null && statusResponse['success'] == true) {
        final callData = statusResponse['data'];
        final status = callData['status'];

        print(
          '[CALL] Polling - Call status: $status (poll $pollCount/$maxPolls)',
        );

        if (status == 'declined' || status == 'ended') {
          print('[CALL] Call $status detected via polling, cleaning up...');
          timer.cancel();
          _statusPollingTimer = null;
          _pollingCallId = null;

          // Handle the call decline/end as if it came from WebSocket
          if (status == 'declined') {
            _handleCallDeclined({
              'callId': callId,
              'payload': {'reason': 'declined_via_polling'},
            });
          } else if (status == 'ended') {
            _handleCallEnded({
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
      print('[CALL] Stopping status polling');
      _statusPollingTimer?.cancel();
      _statusPollingTimer = null;
      _pollingCallId = null;
    }
  }

  /// Test method to debug ringtone issues
  Future<void> testRingtone() async {
    try {
      print('[CALL] Testing ringtone...');
      await RingtoneManager.testAudio();
      await RingtoneManager.playRingtone();
      await Future.delayed(const Duration(seconds: 3));
      await RingtoneManager.stopRingtone();
      print('[CALL] Ringtone test completed');
    } catch (e) {
      print('[CALL] Ringtone test failed: $e');
      // Try fallback
      await RingtoneManager.playSystemRingtone();
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
