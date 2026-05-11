package com.aiexch.amigo.call

import com.aiexch.amigo.R
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Shader
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class CallNotificationManager(private val context: Context) {

    companion object {
        const val CHANNEL_INCOMING = "incoming_calls"
        const val CHANNEL_ONGOING = "ongoing_calls"
        // Silent HIGH-importance channel used solely so the system fires
        // our fullScreenIntent on lock-screen wake-ups without compounding
        // the ringtone — flutter_callkit_incoming's CHANNEL_INCOMING is
        // already responsible for the audible heads-up.
        const val CHANNEL_FULLSCREEN_LAUNCHER = "incoming_calls_launcher"
        const val NOTIFICATION_INCOMING_ID = 9001
        const val NOTIFICATION_ONGOING_ID = 9002
        const val NOTIFICATION_MISSED_ID = 9003
        const val NOTIFICATION_FULLSCREEN_LAUNCHER_ID = 9004

        const val ACTION_ANSWER = "com.aiexch.amigo.call.ACTION_ANSWER"
        const val ACTION_DECLINE = "com.aiexch.amigo.call.ACTION_DECLINE"
        const val ACTION_END_CALL = "com.aiexch.amigo.call.ACTION_END_CALL"
        const val ACTION_OPEN_CALL = "com.aiexch.amigo.call.ACTION_OPEN_CALL"

        private var instance: CallNotificationManager? = null

        fun getInstance(context: Context): CallNotificationManager {
            if (instance == null) {
                instance = CallNotificationManager(context.applicationContext)
            }
            return instance!!
        }
    }

    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var ongoingStartTime: Long = 0L

    init {
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Incoming calls channel - high priority with sound and vibration
            val incomingChannel = NotificationChannel(
                CHANNEL_INCOMING,
                "Incoming Calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for incoming voice calls"
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            notificationManager.createNotificationChannel(incomingChannel)

            // Ongoing calls channel - low priority, no sound
            val ongoingChannel = NotificationChannel(
                CHANNEL_ONGOING,
                "Ongoing Calls",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notification for active voice calls"
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(ongoingChannel)

            // Silent HIGH-importance channel used only to fire
            // fullScreenIntent on lock-screen wake-ups. We deliberately set
            // sound + vibration to null so this channel's notification
            // doesn't double-ring on top of CHANNEL_INCOMING (which still
            // owns the audible heads-up via flutter_callkit_incoming).
            val launcherChannel = NotificationChannel(
                CHANNEL_FULLSCREEN_LAUNCHER,
                "Lock-screen call launcher",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Wakes the device for incoming calls so the in-app call screen can render."
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            notificationManager.createNotificationChannel(launcherChannel)
        }
    }

    /**
     * Show incoming call notification with full-screen intent
     */
    fun showIncomingCallNotification(
        callId: Int,
        callerName: String,
        callerPhoto: String?,
        callerPhone: String?
    ) {
        notificationManager.notify(NOTIFICATION_INCOMING_ID, buildIncomingCallNotification(callId, callerName, callerPhoto, callerPhone))
    }

    /**
     * Show outgoing call notification (ringing/calling state)
     */
    fun showOutgoingCallNotification(
        callId: Int,
        calleeName: String
    ) {
        // Intent to open CallActivity
        val openIntent = Intent(context, CallActivity::class.java).apply {
            putExtra(CallActivity.EXTRA_CALL_ID, callId)
            putExtra(CallActivity.EXTRA_CALLER_NAME, calleeName)
            putExtra(CallActivity.EXTRA_CALL_MODE, "outgoing")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context, 5, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Cancel call action
        val cancelIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = ACTION_END_CALL
            putExtra(CallActivity.EXTRA_CALL_ID, callId)
        }
        val cancelPendingIntent = PendingIntent.getBroadcast(
            context, 6, cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ONGOING)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("Calling $calleeName")
            .setContentText("Outgoing call...")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(openPendingIntent)
            .addAction(R.drawable.ic_call_end_custom, "Cancel", cancelPendingIntent)
            .setUsesChronometer(true)
            .setWhen(System.currentTimeMillis())
            .build()

        notificationManager.notify(NOTIFICATION_ONGOING_ID, notification)
    }

    /**
     * Show ongoing call notification with timer and end button
     */
    fun showOngoingCallNotification(
        callId: Int,
        callerName: String,
        callerPhoto: String?
    ) {
        // Dismiss incoming notification
        dismissIncomingNotification()

        ongoingStartTime = SystemClock.elapsedRealtime()

        // Intent to open CallActivity
        val openIntent = Intent(context, CallActivity::class.java).apply {
            putExtra(CallActivity.EXTRA_CALL_ID, callId)
            putExtra(CallActivity.EXTRA_CALLER_NAME, callerName)
            putExtra(CallActivity.EXTRA_CALLER_PHOTO, callerPhoto)
            putExtra(CallActivity.EXTRA_CALL_MODE, "in_call")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context, 3, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // End call action
        val endCallIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = ACTION_END_CALL
            putExtra(CallActivity.EXTRA_CALL_ID, callId)
        }
        val endCallPendingIntent = PendingIntent.getBroadcast(
            context, 4, endCallIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ONGOING)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("Call with $callerName")
            .setContentText("Ongoing call")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(openPendingIntent)
            .addAction(R.drawable.ic_call_end_custom, "End Call", endCallPendingIntent)
            .setUsesChronometer(true)
            .setWhen(System.currentTimeMillis())
            .setChronometerCountDown(false)
            .build()

        notificationManager.notify(NOTIFICATION_ONGOING_ID, notification)
    }

    /**
     * Update ongoing call notification (e.g., when mute state changes)
     */
    fun updateOngoingNotification(callerName: String, isMuted: Boolean) {
        val openIntent = Intent(context, CallActivity::class.java).apply {
            putExtra(CallActivity.EXTRA_CALL_MODE, "in_call")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context, 3, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val endCallIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = ACTION_END_CALL
        }
        val endCallPendingIntent = PendingIntent.getBroadcast(
            context, 4, endCallIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val statusText = if (isMuted) "Ongoing call (Muted)" else "Ongoing call"

        val notification = NotificationCompat.Builder(context, CHANNEL_ONGOING)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("Call with $callerName")
            .setContentText(statusText)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(openPendingIntent)
            .addAction(R.drawable.ic_call_end_custom, "End Call", endCallPendingIntent)
            .setUsesChronometer(true)
            .setWhen(System.currentTimeMillis() - (SystemClock.elapsedRealtime() - ongoingStartTime))
            .setChronometerCountDown(false)
            .build()

        notificationManager.notify(NOTIFICATION_ONGOING_ID, notification)
    }

    fun dismissIncomingNotification() {
        notificationManager.cancel(NOTIFICATION_INCOMING_ID)
    }

    fun dismissOngoingNotification() {
        notificationManager.cancel(NOTIFICATION_ONGOING_ID)
    }

    fun dismissAllNotifications() {
        notificationManager.cancel(NOTIFICATION_INCOMING_ID)
        notificationManager.cancel(NOTIFICATION_ONGOING_ID)
    }

    /**
     * Build the incoming call notification.
     * Uses CallStyle for a modern WhatsApp-like UI on Android 12+.
     * ongoing=true (can't swipe away), autoCancel=true (dismissed when action is tapped).
     */
    fun buildIncomingCallNotification(callId: Int, callerName: String, callerPhoto: String?, callerPhone: String?): Notification {
        val fullScreenIntent = Intent(context, CallActivity::class.java).apply {
            putExtra(CallActivity.EXTRA_CALL_ID, callId)
            putExtra(CallActivity.EXTRA_CALLER_NAME, callerName)
            putExtra(CallActivity.EXTRA_CALLER_PHOTO, callerPhoto)
            putExtra(CallActivity.EXTRA_CALLER_PHONE, callerPhone)
            putExtra(CallActivity.EXTRA_CALL_MODE, "incoming")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context, 0, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Answer: PendingIntent.getActivity → CallActivity with auto-accept flag.
        // This guarantees the activity starts even from terminated state on Android 14+
        // (BroadcastReceiver → startActivity can be blocked by BAL restrictions).
        val answerIntent = Intent(context, CallActivity::class.java).apply {
            putExtra(CallActivity.EXTRA_CALL_ID, callId)
            putExtra(CallActivity.EXTRA_CALLER_NAME, callerName)
            putExtra(CallActivity.EXTRA_CALLER_PHOTO, callerPhoto)
            putExtra(CallActivity.EXTRA_CALL_MODE, "in_call")
            putExtra(CallActivity.EXTRA_AUTO_ACCEPT, true)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val answerPendingIntent = PendingIntent.getActivity(
            context, 1, answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Decline: still uses BroadcastReceiver (no activity needed)
        val declineIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = ACTION_DECLINE
            putExtra(CallActivity.EXTRA_CALL_ID, callId)
        }
        val declinePendingIntent = PendingIntent.getBroadcast(
            context, 2, declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val caller = Person.Builder()
            .setName(callerName)
            .setImportant(true)
            .build()

        return NotificationCompat.Builder(context, CHANNEL_INCOMING)
            .setSmallIcon(R.drawable.ic_call)
            .setContentTitle(callerName)
            .setContentText("Incoming voice call")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(true)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .setStyle(
                NotificationCompat.CallStyle.forIncomingCall(caller, declinePendingIntent, answerPendingIntent)
            )
            .build()
    }

    /**
     * Build the ongoing (active) call notification.
     * ongoing=true, autoCancel=false — truly non-dismissible while call is active.
     */
    fun buildOngoingCallNotification(callId: Int, callerName: String, callerPhoto: String?): Notification {
        val openIntent = Intent(context, CallActivity::class.java).apply {
            putExtra(CallActivity.EXTRA_CALL_ID, callId)
            putExtra(CallActivity.EXTRA_CALLER_NAME, callerName)
            putExtra(CallActivity.EXTRA_CALLER_PHOTO, callerPhoto)
            putExtra(CallActivity.EXTRA_CALL_MODE, "in_call")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context, 3, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val endCallIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = ACTION_END_CALL
            putExtra(CallActivity.EXTRA_CALL_ID, callId)
        }
        val endCallPendingIntent = PendingIntent.getBroadcast(
            context, 4, endCallIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(context, CHANNEL_ONGOING)
            .setSmallIcon(R.drawable.ic_call)
            .setContentTitle("Call with $callerName")
            .setContentText("Ongoing call")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(openPendingIntent)
            .addAction(R.drawable.ic_call_end_custom, "End Call", endCallPendingIntent)
            .setUsesChronometer(true)
            .setWhen(System.currentTimeMillis())
            .build()
    }

    /**
     * Re-post incoming notification on low-priority CHANNEL_ONGOING (silent — call screen is visible)
     */
    fun showSilentIncomingNotification(callId: Int, callerName: String, callerPhoto: String?) {
        dismissIncomingNotification()

        val answerIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = ACTION_ANSWER
            putExtra(CallActivity.EXTRA_CALL_ID, callId)
            putExtra(CallActivity.EXTRA_CALLER_NAME, callerName)
            putExtra(CallActivity.EXTRA_CALLER_PHOTO, callerPhoto)
        }
        val answerPendingIntent = PendingIntent.getBroadcast(
            context, 1, answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val declineIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = ACTION_DECLINE
            putExtra(CallActivity.EXTRA_CALL_ID, callId)
        }
        val declinePendingIntent = PendingIntent.getBroadcast(
            context, 2, declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ONGOING)
            .setSmallIcon(R.drawable.ic_call)
            .setContentTitle(callerName)
            .setContentText("Incoming call")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(true)
            .addAction(R.drawable.ic_call_end_custom, "Decline", declinePendingIntent)
            .addAction(R.drawable.ic_call, "Answer", answerPendingIntent)
            .build()
        notificationManager.notify(NOTIFICATION_INCOMING_ID, notification)
    }

    /**
     * Show a missed call notification (dismissible)
     */
    fun showMissedCallNotification(callId: Int, callerName: String) {
        val notification = NotificationCompat.Builder(context, CHANNEL_INCOMING)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("Missed call")
            .setContentText("Missed call from $callerName")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_MISSED_CALL)
            .setAutoCancel(true)
            .setOngoing(false)
            .build()
        notificationManager.notify(NOTIFICATION_MISSED_ID, notification)
    }

    /**
     * Lock-screen launcher for the Stream backend.
     *
     * Fires a silent, HIGH-importance notification whose sole purpose is
     * `setFullScreenIntent` → MainActivity. On a locked device Android
     * launches MainActivity (which has `showWhenLocked` set in onCreate
     * once a call is in flight) and Flutter renders the in-app
     * `_RingingView`. flutter_callkit_incoming's audible heads-up still
     * runs in parallel via its own CHANNEL_INCOMING — we just suppress
     * its generic IncomingCallActivity by setting
     * `showFullScreenOnLockScreen: false` in dart-side push config.
     */
    fun showStreamFullScreenLauncher(
        callCid: String,
        callerName: String,
        callerPhoto: String?
    ) {
        val main = Intent().apply {
            setClassName(context.packageName, "${context.packageName}.MainActivity")
            putExtra("incoming_call_cid", callCid)
            putExtra("incoming_caller_name", callerName)
            if (callerPhoto != null) putExtra("incoming_caller_photo", callerPhoto)
            putExtra("incoming_backend", "stream")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val launcherPi = PendingIntent.getActivity(
            context, 7, main,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_FULLSCREEN_LAUNCHER)
            .setSmallIcon(R.drawable.ic_call)
            .setContentTitle(callerName)
            .setContentText("Incoming voice call")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(true)
            .setSilent(true)
            .setFullScreenIntent(launcherPi, true)
            .setContentIntent(launcherPi)
            .build()

        notificationManager.notify(NOTIFICATION_FULLSCREEN_LAUNCHER_ID, notification)
    }

    fun dismissStreamFullScreenLauncher() {
        notificationManager.cancel(NOTIFICATION_FULLSCREEN_LAUNCHER_ID)
    }
}
