import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'stream_call.service.dart';

/// Dart-side client for `StreamOngoingCallNotifier` (native Kotlin).
///
/// The native side posts a `Notification.CallStyle.forOngoingCall` notification
/// — the only kind Android 12+ guarantees the user can't swipe away. We layer
/// it on top of Stream's own foreground-service notification (which we keep
/// for mic/audio capture in background).
///
/// Lifecycle:
///   - [show] is called when the call enters the answered state.
///   - [hide] is called on disconnect.
///   - The "Hang up" action button on the notification routes back here via
///     `onHangup`, which calls `streamCall.leave()`.
class StreamCallStyleNotifier {
  StreamCallStyleNotifier._();
  static final StreamCallStyleNotifier instance = StreamCallStyleNotifier._();

  static const _channel = MethodChannel('com.aiexch.amigo/stream_call_notif');
  bool _wired = false;

  void _ensureWired() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onHangup':
          debugPrint('[STREAM-CALL-NOTIF] onHangup from notification');
          try {
            final c = StreamCallService().streamCall;
            await c?.leave();
          } catch (e) {
            debugPrint('[STREAM-CALL-NOTIF] leave failed: $e');
          }
          break;
      }
    });
  }

  Future<void> show({
    required String callId,
    required String callerName,
    required DateTime connectedAt,
  }) async {
    _ensureWired();
    try {
      await _channel.invokeMethod('show', {
        'callId': callId,
        'callerName': callerName,
        'connectedAtMs': connectedAt.millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[STREAM-CALL-NOTIF] show failed: $e');
    }
  }

  Future<void> hide() async {
    _ensureWired();
    try {
      await _channel.invokeMethod('hide');
    } catch (e) {
      debugPrint('[STREAM-CALL-NOTIF] hide failed: $e');
    }
  }
}
