import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../env.dart';
import '../models/call.model.dart';
import '../services/call/call.service.dart';
import '../services/call/i_call_backend.dart';
import '../services/call/stream/stream_call.service.dart';

/// State exposed to widgets watching [callServiceProvider].
class CallServiceState {
  final ActiveCallState? activeCall;
  final bool isInitialized;

  CallServiceState({this.activeCall, this.isInitialized = false});

  CallServiceState copyWith({
    ActiveCallState? activeCall,
    bool? isInitialized,
  }) {
    return CallServiceState(
      activeCall: activeCall ?? this.activeCall,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  bool get hasActiveCall => activeCall != null;
  bool get isInCall =>
      activeCall?.status == CallStatus.answered ||
      activeCall?.status == CallStatus.connecting;
}

/// Riverpod provider — the rest of the app talks to this; it forwards every
/// operation to whichever [ICallBackend] implementation is currently selected
/// (`Environment.callBackend`).
///
/// To switch providers at runtime later (e.g. an in-app toggle), call
/// [CallServiceNotifier.swapBackend].
final callServiceProvider =
    NotifierProvider<CallServiceNotifier, CallServiceState>(
      () => CallServiceNotifier(),
    );

class CallServiceNotifier extends Notifier<CallServiceState> {
  late ICallBackend _backend;
  Timer? _durationUpdateTimer;

  @override
  CallServiceState build() {
    _backend = _createBackend();

    _backend
        .initialize()
        .then((_) {
          _syncState();
          _startDurationUpdates();
        })
        .catchError((e) {
          debugPrint('[CallProvider] Backend init failed: $e');
        });

    _startDurationUpdates();
    return CallServiceState();
  }

  ICallBackend _createBackend() {
    debugPrint('[STREAM-CALL] CallProvider._createBackend: '
        'Environment.callBackend="${Environment.callBackend}"');
    switch (Environment.callBackend) {
      case 'stream':
        debugPrint('[STREAM-CALL] CallProvider → StreamCallService');
        return StreamCallService();
      case 'webrtc':
      default:
        debugPrint('[STREAM-CALL] CallProvider → CallService (WebRTC)');
        return CallService();
    }
  }

  /// Hot-swap the backend. The previous backend's active call is dropped.
  Future<void> swapBackend(ICallBackend next) async {
    _backend = next;
    await _backend.initialize();
    _syncState();
  }

  void _syncState() {
    state = CallServiceState(
      activeCall: _backend.activeCall,
      isInitialized: _backend.isInitialized,
    );
  }

  void _startDurationUpdates() {
    _durationUpdateTimer?.cancel();
    _durationUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _syncState();
    });
  }

  void syncState() {
    _syncState();
    _startDurationUpdates();
  }

  void cleanup() {
    _durationUpdateTimer?.cancel();
    _durationUpdateTimer = null;
  }

  // ---- Public surface (unchanged for existing callers) -------------------

  Future<void> initialize() async {
    await _backend.initialize();
    _syncState();
    _startDurationUpdates();
  }

  Future<void> initiateCall(
    String calleeId,
    String calleeName,
    String? calleeProfilePic, {
    bool video = false,
  }) async {
    await _backend.initiateCall(
      calleeId,
      calleeName,
      calleeProfilePic,
      video: video,
    );
    _syncState();
    _startDurationUpdates();
  }

  Future<void> restoreCallState(
    String callId,
    String callerId,
    String callerName,
    String? callerProfilePic,
  ) async {
    await _backend.restoreCallState(callId, callerId, callerName, callerProfilePic);
    _syncState();
  }

  Future<void> acceptCall({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerProfilePic,
  }) async {
    await _backend.acceptCall(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerProfilePic: callerProfilePic,
    );
    _syncState();
    _startDurationUpdates();
  }

  Future<void> declineCall({String? reason, String? callId}) async {
    await _backend.declineCall(reason: reason, callId: callId);
    _syncState();
  }

  Future<void> endCall({String? reason}) async {
    await _backend.endCall(reason: reason);
    _syncState();
    Future.delayed(const Duration(milliseconds: 300), () {
      _syncState();
      _startDurationUpdates();
    });
  }

  Future<void> toggleMute() async {
    await _backend.toggleMute();
    _syncState();
  }

  Future<void> toggleSpeaker() async {
    await _backend.toggleSpeaker();
    _syncState();
  }

  ActiveCallState? get activeCall => _backend.activeCall;
  bool get hasActiveCall => _backend.hasActiveCall;
  bool get isInCall => _backend.isInCall;

  // WebRTC-only — Stream backend hides media streams behind its own widgets.
  MediaStream? get localStream =>
      _backend is CallService ? (_backend as CallService).localStream : null;
  MediaStream? get remoteStream =>
      _backend is CallService ? (_backend as CallService).remoteStream : null;
}
