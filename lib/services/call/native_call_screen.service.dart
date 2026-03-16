import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Bridge service for the native Kotlin call screen.
///
/// Uses MethodChannel (Flutter → Native) and EventChannel (Native → Flutter)
/// to control the native CallActivity and receive user actions.
class NativeCallScreen {
  static const MethodChannel _methodChannel =
      MethodChannel('com.aiexch.amigo/native_call');
  static const EventChannel _eventChannel =
      EventChannel('com.aiexch.amigo/native_call_events');

  static StreamSubscription? _eventSubscription;

  // Callbacks for native events
  static Function(int callId)? onCallAccepted;
  static Function(int callId)? onCallDeclined;
  static Function(int callId)? onCallEnded;
  static Function(bool isMuted)? onMuteToggled;
  static Function(bool isSpeakerOn)? onSpeakerToggled;

  /// Initialize the event listener. Call this once at app startup.
  static void initialize() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final eventName = event['event'] as String?;
          debugPrint('[NativeCallScreen] Event received: $eventName');

          switch (eventName) {
            case 'onCallAccepted':
              final callId = event['callId'] as int? ?? 0;
              onCallAccepted?.call(callId);
              break;
            case 'onCallDeclined':
              final callId = event['callId'] as int? ?? 0;
              onCallDeclined?.call(callId);
              break;
            case 'onCallEnded':
              final callId = event['callId'] as int? ?? 0;
              onCallEnded?.call(callId);
              break;
            case 'onMuteToggled':
              final isMuted = event['isMuted'] as bool? ?? false;
              onMuteToggled?.call(isMuted);
              break;
            case 'onSpeakerToggled':
              final isSpeakerOn = event['isSpeakerOn'] as bool? ?? false;
              onSpeakerToggled?.call(isSpeakerOn);
              break;
            default:
              debugPrint('[NativeCallScreen] Unknown event: $eventName');
          }
        }
      },
      onError: (error) {
        debugPrint('[NativeCallScreen] Event stream error: $error');
      },
    );
  }

  /// Dispose event listener
  static void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  // ---- Flutter → Native methods ----

  /// Show incoming call screen (full-screen on lock screen)
  static Future<bool> showIncomingCall({
    required int callId,
    required String callerName,
    String? callerPhoto,
    String? callerPhone,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('showIncomingCall', {
        'callId': callId,
        'callerName': callerName,
        'callerPhoto': callerPhoto,
        'callerPhone': callerPhone,
      });
      return result == true;
    } catch (e) {
      debugPrint('[NativeCallScreen] Error showing incoming call: $e');
      return false;
    }
  }

  /// Show outgoing call screen
  static Future<bool> showOutgoingCall({
    required int callId,
    required String calleeName,
    String? calleePhoto,
    String? calleePhone,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('showOutgoingCall', {
        'callId': callId,
        'calleeName': calleeName,
        'calleePhoto': calleePhoto,
        'calleePhone': calleePhone,
      });
      return result == true;
    } catch (e) {
      debugPrint('[NativeCallScreen] Error showing outgoing call: $e');
      return false;
    }
  }

  /// Show call screen with specific mode
  static Future<bool> showCallScreen({
    required int callId,
    required String callerName,
    String? callerPhoto,
    String callMode = 'in_call',
    bool isMuted = false,
    bool isSpeakerOn = true,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('showCallScreen', {
        'callId': callId,
        'callerName': callerName,
        'callerPhoto': callerPhoto,
        'callMode': callMode,
        'isMuted': isMuted,
        'isSpeakerOn': isSpeakerOn,
      });
      return result == true;
    } catch (e) {
      debugPrint('[NativeCallScreen] Error showing call screen: $e');
      return false;
    }
  }

  /// Update call state on the native screen
  static Future<bool> updateCallState({
    String? callMode,
    bool? isMuted,
    bool? isSpeakerOn,
    int? duration,
  }) async {
    try {
      final args = <String, dynamic>{};
      if (callMode != null) args['callMode'] = callMode;
      if (isMuted != null) args['isMuted'] = isMuted;
      if (isSpeakerOn != null) args['isSpeakerOn'] = isSpeakerOn;
      if (duration != null) args['duration'] = duration;

      final result = await _methodChannel.invokeMethod('updateCallState', args);
      return result == true;
    } catch (e) {
      debugPrint('[NativeCallScreen] Error updating call state: $e');
      return false;
    }
  }

  /// Dismiss the call screen
  static Future<bool> dismissCallScreen() async {
    try {
      final result = await _methodChannel.invokeMethod('dismissCallScreen');
      return result == true;
    } catch (e) {
      debugPrint('[NativeCallScreen] Error dismissing call screen: $e');
      return false;
    }
  }

  /// Show ongoing call notification with timer
  static Future<bool> showOngoingNotification({
    required int callId,
    required String callerName,
    String? callerPhoto,
  }) async {
    try {
      final result =
          await _methodChannel.invokeMethod('showOngoingNotification', {
        'callId': callId,
        'callerName': callerName,
        'callerPhoto': callerPhoto,
      });
      return result == true;
    } catch (e) {
      debugPrint('[NativeCallScreen] Error showing ongoing notification: $e');
      return false;
    }
  }

  /// Update ongoing notification
  static Future<bool> updateOngoingNotification({
    required String callerName,
    bool isMuted = false,
  }) async {
    try {
      final result =
          await _methodChannel.invokeMethod('updateOngoingNotification', {
        'callerName': callerName,
        'isMuted': isMuted,
      });
      return result == true;
    } catch (e) {
      debugPrint(
          '[NativeCallScreen] Error updating ongoing notification: $e');
      return false;
    }
  }

  /// Dismiss all call notifications
  static Future<bool> dismissNotification() async {
    try {
      final result = await _methodChannel.invokeMethod('dismissNotification');
      return result == true;
    } catch (e) {
      debugPrint('[NativeCallScreen] Error dismissing notification: $e');
      return false;
    }
  }

  /// Dismiss only the incoming call notification
  static Future<bool> dismissIncomingNotification() async {
    try {
      final result =
          await _methodChannel.invokeMethod('dismissIncomingNotification');
      return result == true;
    } catch (e) {
      debugPrint(
          '[NativeCallScreen] Error dismissing incoming notification: $e');
      return false;
    }
  }

  /// Show a missed call notification in the notification panel
  static Future<bool> showMissedCallNotification({
    required int callId,
    required String callerName,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod(
        'showMissedCallNotification',
        {'callId': callId, 'callerName': callerName},
      );
      return result == true;
    } catch (e) {
      debugPrint('[NativeCallScreen] Error showing missed call notification: $e');
      return false;
    }
  }

  /// Check if the native call screen is currently showing
  static Future<bool> isCallScreenActive() async {
    try {
      final result =
          await _methodChannel.invokeMethod('isCallScreenActive');
      return result == true;
    } catch (e) {
      debugPrint('[NativeCallScreen] Error checking call screen state: $e');
      return false;
    }
  }
}
