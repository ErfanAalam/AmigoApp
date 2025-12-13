import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call.model.dart';
import '../services/call/call.service.dart';

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
    // Initialize asynchronously but don't block build
    _callService
        .initialize()
        .then((_) {
          _syncState();
          _startDurationUpdates();
        })
        .catchError((e) {
          debugPrint('[CallProvider] Error initializing CallService: $e');
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
    // IMPORTANT: Always restart the timer to ensure it keeps running
    // Even if it's already running, restart it to ensure it doesn't stop
    // This is critical after cleanup when state is cleared and new calls start
    _durationUpdateTimer?.cancel();
    _durationUpdateTimer = null;

    // Update every 100ms to catch state changes more quickly
    // This ensures we catch state changes from _handleCallAccept, CallKit, etc. immediately
    // Reduced from 200ms to 100ms for faster UI updates when calls are accepted/declined
    // IMPORTANT: Keep timer running even when there's no active call to catch new calls immediately
    _durationUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      // Always sync state to catch any updates from CallService
      // This is important because CallService can be updated directly (e.g., from CallKit)
      // or from websocket handlers (_handleCallAccept, etc.)
      // This ensures UI updates even after cleanup when a new call starts
      _syncState();
    });
  }

  /// Manually sync state (useful when CallService updates state directly)
  /// This should be called whenever CallService state might have changed
  void syncState() {
    _syncState();
    // Always restart duration updates to ensure we catch all state changes
    // This is important after cleanup when timer might have stopped
    _startDurationUpdates();
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
    // Sync state immediately and restart timer to ensure UI updates
    _syncState();
    _startDurationUpdates(); // Ensure timer is running for new call
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
    // Sync state immediately after ending call to ensure UI updates
    _syncState();
    // Wait a bit and sync again to catch any delayed cleanup
    Future.delayed(const Duration(milliseconds: 300), () {
      _syncState();
      // IMPORTANT: Restart timer after cleanup to catch new calls
      _startDurationUpdates();
    });
    // Don't cancel timer - keep it running to catch new calls immediately
    // The timer will continue syncing even when there's no active call
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
