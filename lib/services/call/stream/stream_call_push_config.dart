import 'package:stream_video_push_notification/stream_video_push_notification.dart';

/// Single source of truth for the look of the Stream Video incoming-call /
/// missed-call notifications. Used by both the foreground client init in
/// `StreamCallService` and the cold-path bootstrap in `stream_call.fcm.dart`
/// so the notification looks the same in either entry path.
StreamVideoPushConfiguration get amigoStreamPushConfiguration =>
    const StreamVideoPushConfiguration(
      android: AndroidPushConfiguration(
        // Disable flutter_callkit_incoming's generic IncomingCallActivity on
        // lock screen. We instead fire our own fullScreenIntent (see
        // CallNotificationManager.showStreamFullScreenLauncher) that launches
        // MainActivity, so the lock-screen ringing UI is the same Flutter
        // `_RingingView` users see in-app. The CallStyle heads-up still
        // works for unlocked devices.
        showFullScreenOnLockScreen: false,

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

        // Missed-call notification UX:
        //  - Subtitle is the row body the user reads at a glance — keep it
        //    short and active.
        //  - `callbackText` is the action button label. Material guidelines
        //    keep these to one short verb phrase.
        //  - `id: null` means the SDK derives a stable id per-call from the
        //    call cid, so multiple missed calls stack as separate
        //    notifications instead of replacing each other (the previous
        //    behaviour was a single "Missed call" entry that overwrote
        //    every prior one — users only saw the most recent missed call
        //    when they finally checked the tray).
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
