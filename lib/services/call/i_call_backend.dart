import '../../models/call.model.dart';

/// Common surface that every concrete call backend (WebRTC, Stream Video, …)
/// must implement. The Riverpod `CallServiceNotifier` talks only through this
/// interface, so swapping backends never touches UI code.
///
/// Both backends are kept side-by-side in the source tree — the choice happens
/// at startup via `Environment.callBackend`.
abstract class ICallBackend {
  /// Current in-flight call, or null when idle.
  ActiveCallState? get activeCall;

  bool get hasActiveCall;
  bool get isInCall;
  bool get isInitialized;

  /// One-time setup. Idempotent.
  Future<void> initialize();

  /// Place an outgoing audio call to [calleeId].
  Future<void> initiateCall(String calleeId, String calleeName, String? calleeProfilePic);

  /// Accept an incoming call.
  ///
  /// All parameters optional — the WebRTC backend uses them to recover from a
  /// killed-state launch (where SharedPreferences holds the only call info).
  /// The Stream backend ignores them and uses its own pending-call cache.
  Future<void> acceptCall({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerProfilePic,
  });

  /// Decline an incoming call or cancel an outgoing one.
  Future<void> declineCall({String? reason, String? callId});

  /// Hang up the in-progress call.
  Future<void> endCall({String? reason});

  Future<void> toggleMute();
  Future<void> toggleSpeaker();

  /// Restore call state from killed-state caches (used by WebRTC when an
  /// incoming-call notification was tapped while the app was terminated).
  /// Stream backend implements this as a no-op — its own push handler manages
  /// the equivalent flow.
  Future<void> restoreCallState(
    String callId,
    String callerId,
    String callerName,
    String? callerProfilePic,
  );
}
