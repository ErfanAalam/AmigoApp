package com.aiexch.amigo.call

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import com.aiexch.amigo.MainActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Truly non-dismissable ongoing-call notification.
 *
 * Why this exists: stream_video_flutter ships its own foreground-service
 * notification, but it's built with `setOngoing(true) + CATEGORY_CALL` and
 * **not** `Notification.CallStyle`. On Android 14+ that combination is still
 * user-dismissable; users can swipe it away (and it only re-appears when the
 * SDK pushes the next state update).
 *
 * Android requires `Notification.CallStyle.forOngoingCall(...)` to make the
 * system enforce non-dismissibility. The SDK doesn't expose a hook to inject
 * that, so we post a parallel notification on a separate channel that *uses*
 * CallStyle, and rely on Stream's own service to keep the mic foreground.
 *
 * Lifecycle is driven from Dart over the
 * `com.aiexch.amigo/stream_call_notif` MethodChannel:
 *   - `show(callId, callerName, connectedAtMs)` → post / refresh
 *   - `hide` → cancel
 *
 * The notification's "Hang up" action and body-tap both target a small
 * helper Activity (re-using MainActivity) — the `Hang up` action delivers a
 * broadcast that Dart picks up via our existing call-action channel.
 */
class StreamOngoingCallNotifier {

    companion object {
        const val CHANNEL_ID_DART = "com.aiexch.amigo/stream_call_notif"
        private const val CHANNEL_ID_NATIVE = "stream_call_ongoing_v2"
        private const val CHANNEL_NAME_NATIVE = "Ongoing Calls (sticky)"
        private const val NOTIFICATION_ID = 0xCA11

        // Action codes that the action receiver delivers back to Dart.
        const val ACTION_HANGUP = "com.aiexch.amigo.STREAM_CALL_HANGUP"
        const val ACTION_OPEN = "com.aiexch.amigo.STREAM_CALL_OPEN"

        @SuppressLint("StaticFieldLeak")
        private var instance: StreamOngoingCallNotifier? = null

        fun attach(context: Context, messenger: io.flutter.plugin.common.BinaryMessenger) {
            val notifier = instance ?: StreamOngoingCallNotifier(context.applicationContext).also {
                instance = it
            }
            MethodChannel(messenger, CHANNEL_ID_DART).setMethodCallHandler { call, result ->
                notifier.handleMethodCall(call, result)
            }
        }
    }

    private val context: Context

    private constructor(ctx: Context) {
        this.context = ctx
        ensureChannel()
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "show" -> {
                val callId = call.argument<String>("callId") ?: ""
                val callerName = call.argument<String>("callerName") ?: "Ongoing call"
                val connectedAtMs = call.argument<Long>("connectedAtMs")
                android.util.Log.i(
                    "StreamOngoingNotif",
                    "▶ show callId=$callId callerName=$callerName connectedAtMs=$connectedAtMs",
                )
                show(callId, callerName, connectedAtMs)
                result.success(true)
            }
            "hide" -> {
                android.util.Log.i("StreamOngoingNotif", "▶ hide")
                hide()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID_NATIVE) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID_NATIVE,
            CHANNEL_NAME_NATIVE,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Persistent in-call notification — cannot be dismissed during a call"
            setShowBadge(false)
            setSound(null, null)
            enableVibration(false)
            // CallStyle on this channel is what makes the notification truly
            // non-dismissable on Android 12+.
        }
        nm.createNotificationChannel(channel)
    }

    private fun show(callId: String, callerName: String, connectedAtMs: Long?) {
        // Android requires a CallStyle notification to either be a foreground
        // service notification OR have a fullScreenIntent attached, otherwise
        // NotificationManager rejects it with IllegalArgumentException. We
        // can't bind to Stream's foreground service from here, so we attach a
        // fullScreenIntent (re-using the body intent — both open MainActivity).
        val fullScreenIntent = buildContentIntent()

        val builder = NotificationCompat.Builder(context, CHANNEL_ID_NATIVE)
            .setSmallIcon(android.R.drawable.sym_call_outgoing)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentTitle(callerName)
            .setContentText("Tap to return to call")
            .setContentIntent(fullScreenIntent)
            // `false` for the second arg = don't show the heads-up banner
            // immediately (the call is already in-progress, no need to nag).
            .setFullScreenIntent(fullScreenIntent, false)
            // Anchor a chronometer to connectedAt so the system itself ticks
            // the elapsed counter — survives any kind of redraw.
            .also {
                if (connectedAtMs != null) {
                    it.setUsesChronometer(true)
                    it.setWhen(connectedAtMs)
                    it.setShowWhen(true)
                }
            }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // CallStyle requires API 31+. This is what flips the notification
            // to truly-non-dismissable.
            val person = Person.Builder()
                .setName(callerName)
                .setImportant(true)
                .build()
            val style = NotificationCompat.CallStyle.forOngoingCall(
                person,
                buildHangupIntent(callId),
            )
            builder.setStyle(style)
        } else {
            // Pre-S fallback: regular notification with a Hang up action.
            builder.addAction(
                NotificationCompat.Action.Builder(
                    android.R.drawable.sym_call_outgoing,
                    "Hang up",
                    buildHangupIntent(callId),
                ).build(),
            )
        }

        // Hand the notification to our foreground service so it owns the
        // sticky AND holds FOREGROUND_SERVICE_MICROPHONE — the latter is
        // what keeps WebRTC's mic capture alive while the user has the app
        // backgrounded. Calling `nm.notify(...)` on its own (the previous
        // approach) doesn't grant Android the foreground guarantee, so the
        // mic was being paused on minimize and the call silently dying for
        // the minimizer.
        StreamOngoingCallService.start(context, builder.build())
    }

    private fun hide() {
        StreamOngoingCallService.stop(context)

        // Reset the audio mode now that the call is over. Without this, the
        // BroadcasterAudioPolicy's MODE_IN_COMMUNICATION can persist and
        // route the *next* incoming-call ringtone through the earpiece at
        // in-call volume. We do the same on app cold-start (MainActivity)
        // and on FCM message receipt (AmigoMessagingService); doing it here
        // closes the loop end-of-call.
        try {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (am.mode != AudioManager.MODE_NORMAL) {
                Log.i("StreamOngoingNotif",
                    "Resetting audio mode (was ${am.mode}) → MODE_NORMAL after call end")
                am.mode = AudioManager.MODE_NORMAL
            }
        } catch (e: Exception) {
            Log.w("StreamOngoingNotif", "Audio mode reset on hide failed: ${e.message}")
        }
    }

    /** Tap-on-body pending intent → opens MainActivity with our action. */
    private fun buildContentIntent(): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_OPEN
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getActivity(context, 0, intent, flags)
    }

    /** Hang-up action → broadcast picked up by [StreamCallActionReceiver]. */
    private fun buildHangupIntent(callId: String): PendingIntent {
        val intent = Intent(context, StreamCallActionReceiver::class.java).apply {
            action = ACTION_HANGUP
            putExtra("callId", callId)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getBroadcast(context, 1, intent, flags)
    }
}
