import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call_model.dart';
import '../services/call.service.dart';

/// State class for CallService
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
  bool get isInCall => activeCall?.status == CallStatus.answered;
}

/// Riverpod provider for CallService
final callServiceProvider =
    NotifierProvider<CallServiceNotifier, CallServiceState>(
      () => CallServiceNotifier(),
    );

/// Riverpod Notifier for CallService
class CallServiceNotifier extends Notifier<CallServiceState> {
  final CallService _callService = CallService();
  Timer? _durationUpdateTimer;

  @override
  CallServiceState build() {
    // Initialize
    _callService.initialize().then((_) {
      _syncState();
      _startDurationUpdates();
    });

    // Also start timer immediately to catch any existing calls
    _startDurationUpdates();

    return CallServiceState();
  }

  void _syncState() {
    state = CallServiceState(
      activeCall: _callService.activeCall,
      isInitialized: _callService.isInitialized,
    );
  }

  /// Start periodic updates to sync duration changes
  void _startDurationUpdates() {
    // Don't cancel if already running - just let it continue
    if (_durationUpdateTimer != null && _durationUpdateTimer!.isActive) {
      return;
    }
    
    _durationUpdateTimer?.cancel();
    
    // Update every 200ms to catch state changes quickly
    // This ensures we catch state changes from _handleCallAccept, CallKit, etc. immediately
    _durationUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      // Always sync state to catch any updates from CallService
      // This is important because CallService can be updated directly (e.g., from CallKit)
      // or from websocket handlers (_handleCallAccept, etc.)
      _syncState();
    });
  }
  
  /// Manually sync state (useful when CallService updates state directly)
  /// This should be called whenever CallService state might have changed
  void syncState() {
    _syncState();
    // Restart duration updates if there's an active call
    if (_callService.hasActiveCall && _callService.isInCall) {
      _startDurationUpdates();
    }
  }

  /// Cleanup method to be called when provider is disposed
  void cleanup() {
    _durationUpdateTimer?.cancel();
    _durationUpdateTimer = null;
  }

  // Delegate methods to CallService and sync state after each operation
  Future<void> initialize() async {
    await _callService.initialize();
    _syncState();
    _startDurationUpdates();
  }

  Future<void> initiateCall(
    int calleeId,
    String calleeName,
    String? calleeProfilePic,
  ) async {
    await _callService.initiateCall(calleeId, calleeName, calleeProfilePic);
    _syncState();
  }

  Future<void> restoreCallState(
    int callId,
    int callerId,
    String callerName,
    String? callerProfilePic,
  ) async {
    await _callService.restoreCallState(
      callId,
      callerId,
      callerName,
      callerProfilePic,
    );
    _syncState();
  }

  Future<void> acceptCall({
    int? callId,
    int? callerId,
    String? callerName,
    String? callerProfilePic,
  }) async {
    await _callService.acceptCall(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerProfilePic: callerProfilePic,
    );
    _syncState();
    _startDurationUpdates();
  }

  Future<void> declineCall({String? reason, int? callId}) async {
    await _callService.declineCall(reason: reason, callId: callId);
    _syncState();
  }

  Future<void> endCall({String? reason}) async {
    await _callService.endCall(reason: reason);
    _syncState();
    _durationUpdateTimer?.cancel();
    _durationUpdateTimer = null;
  }

  Future<void> toggleMute() async {
    await _callService.toggleMute();
    _syncState();
  }

  Future<void> toggleSpeaker() async {
    await _callService.toggleSpeaker();
    _syncState();
  }

  ActiveCallState? get activeCall => _callService.activeCall;
  bool get hasActiveCall => _callService.hasActiveCall;
  bool get isInCall => _callService.isInCall;
  MediaStream? get localStream => _callService.localStream;
  MediaStream? get remoteStream => _callService.remoteStream;
}
