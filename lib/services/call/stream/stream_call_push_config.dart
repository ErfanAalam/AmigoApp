import 'package:stream_video_push_notification/stream_video_push_notification.dart';

/// Single source of truth for the look of the Stream Video incoming-call /
/// missed-call notifications. Used by both the foreground client init in
/// `StreamCallService` and the cold-path bootstrap in `stream_call.fcm.dart`
/// so the notification looks the same in either entry path.
StreamVideoPushConfiguration get amigoStreamPushConfiguration =>
    const StreamVideoPushConfiguration(
      android: AndroidPushConfiguration(
        // Show the heads-up + full-screen incoming-call UI even when the
        // device is locked. Without this the user only sees a heads-up banner
        // and has to unlock first.
        showFullScreenOnLockScreen: true,

        // Distinct channels so users can independently silence missed calls
        // without losing live ring sounds.
        incomingCallNotificationChannelName: 'Incoming Calls',
        missedCallNotificationChannelName: 'Missed Calls',

        incomingCallNotification: IncomingCallNotificationParams(
          textAccept: 'Answer',
          textDecline: 'Decline',
          showCallHandle: false,
          fullScreenBackgroundColor: '#0F1B33',
          fullScreenTextColor: '#FFFFFF',
        ),

        missedCallNotification: MissedCallNotificationParams(
          showNotification: true,
          showCallbackButton: true,
          subtitle: 'Tap to call back',
          callbackText: 'Call back',
        ),
      ),
      ios: IOSPushConfiguration(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        includesCallsInRecents: true,
      ),
    );
