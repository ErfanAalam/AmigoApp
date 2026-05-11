package com.aiexch.amigo.call

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import org.json.JSONObject

/**
 * Custom FCM messaging service that handles call notifications natively,
 * bypassing the Flutter background isolate for terminated-app scenarios
 * where MethodChannel is unavailable.
 *
 * For non-call messages, delegates to the Flutter background isolate via super.
 */
class AmigoMessagingService : FlutterFirebaseMessagingService() {

    companion object {
        private const val TAG = "AmigoMessagingService"
        // SharedPreferences file used by Flutter's shared_preferences package
        private const val PREFS_FILE = "FlutterSharedPreferences"
        // Flutter adds "flutter." prefix to all keys
        private const val CALL_DETAILS_KEY = "flutter.current_call_details"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val type = message.data["type"]
        val sender = message.data["sender"]
        Log.d(TAG, "onMessageReceived: type=$type sender=$sender")

        // For ANY incoming Stream Video push (call.ring/call.missed/etc.),
        // proactively reset Android's audio mode to NORMAL before the
        // platform notification flow runs. If a previous call session left
        // the device in MODE_IN_COMMUNICATION (Stream's BroadcasterAudioPolicy
        // sets this), the upcoming ringtone — even with USAGE_NOTIFICATION_RINGTONE
        // attributes — will route through the earpiece at in-call volume.
        // Resetting here makes the ringtone come out the loudspeaker like
        // a normal phone call.
        if (sender == "stream.video") {
            try {
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                if (am.mode != AudioManager.MODE_NORMAL) {
                    Log.i(TAG, "Resetting audio mode (was ${am.mode}) → MODE_NORMAL for Stream push")
                    am.mode = AudioManager.MODE_NORMAL
                }
            } catch (e: Exception) {
                Log.w(TAG, "Audio mode reset failed: ${e.message}")
            }

            // Mirror the call status into SharedPreferences so MainActivity's
            // pre-super.onCreate check can apply lock-screen flags before the
            // keyguard intercepts the launch from Stream's answer notification.
            val streamType = message.data["type"]
            when (streamType) {
                "call.ring" -> {
                    markStreamCallInFlight(message.data)
                    // Only fire the lock-screen launcher when the device is
                    // actually locked. On unlocked devices flutter_callkit_incoming's
                    // existing heads-up handles the UI, and we don't want a
                    // duplicate notification cluttering the tray.
                    val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                    if (km?.isKeyguardLocked == true) {
                        fireStreamFullScreenLauncher(message.data)
                    }
                }
                "call.missed", "call.ended" -> {
                    clearCallDetails()
                    try {
                        CallNotificationManager.getInstance(this)
                            .dismissStreamFullScreenLauncher()
                    } catch (_: Exception) {}
                }
            }
        }

        if (type == "call") {
            handleCallNatively(message.data)
            // Do NOT call super — prevents Flutter background isolate from running for calls,
            // which avoids the MethodChannel-unavailable crash in terminated state
        } else {
            // Chat messages, Stream Video pushes (incoming + missed + ended) all
            // go through the Flutter background isolate. The ringtone duplication
            // when the app is backgrounded is suppressed Dart-side instead — see
            // the AppLifecycleState guards around StreamCallRingtones.playIncoming
            // in stream_call.service.dart. That keeps the FCM/CallKit ringtone as
            // the audible cue for backgrounded/killed state and lets the in-app
            // ringtone play only when the user is actually looking at the app.
            super.onMessageReceived(message)
        }
    }

    private fun fireStreamFullScreenLauncher(data: Map<String, String>) {
        try {
            val callCid = data["call_cid"] ?: return
            val callerName = data["call_display_name"]
                ?: data["created_by_display_name"]
                ?: "Unknown"
            val callerPfp = data["created_by_image"]?.takeIf { it.isNotEmpty() }
            CallNotificationManager.getInstance(this)
                .showStreamFullScreenLauncher(callCid, callerName, callerPfp)
            Log.d(TAG, "fireStreamFullScreenLauncher: cid=$callCid (device locked)")
        } catch (e: Exception) {
            Log.w(TAG, "fireStreamFullScreenLauncher failed: ${e.message}")
        }
    }

    private fun markStreamCallInFlight(data: Map<String, String>) {
        try {
            val callCid = data["call_cid"] ?: return
            val callerName = data["call_display_name"]
                ?: data["created_by_display_name"]
                ?: "Unknown"
            val callerPfp = data["created_by_image"]?.takeIf { it.isNotEmpty() }
            val json = JSONObject().apply {
                put("call_cid", callCid)
                put("caller_name", callerName)
                if (callerPfp != null) put("caller_profile_pic", callerPfp)
                put("call_status", "ringing")
                put("backend", "stream")
            }
            val prefs = getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            prefs.edit().putString(CALL_DETAILS_KEY, json.toString()).apply()
            Log.d(TAG, "markStreamCallInFlight: cid=$callCid")
        } catch (e: Exception) {
            Log.w(TAG, "markStreamCallInFlight failed: ${e.message}")
        }
    }

    private fun handleCallNatively(data: Map<String, String>) {
        try {
            val wsMessageStr = data["ws_message"] ?: return
            val wsMessage = JSONObject(wsMessageStr)
            val wsType = wsMessage.optString("type")
            val payload = wsMessage.optJSONObject("payload") ?: JSONObject()

            Log.d(TAG, "handleCallNatively: wsType=$wsType")

            when (wsType) {
                "call:ringing" -> {
                    val callId = payload.optLong("call_id", 0L)
                    val callerId = payload.optLong("caller_id", 0L)
                    val callerName = payload.optString("caller_name", "Unknown")
                    val callerPfp = payload.optString("caller_pfp").takeIf { it.isNotEmpty() }

                    // Save call details to SharedPreferences so Flutter can read them on resume
                    saveCallDetailsToPrefs(callId, callerId, callerName, callerPfp)

                    // Acquire a wakelock with ACQUIRE_CAUSES_WAKEUP to physically turn on the
                    // screen. FLAG_TURN_SCREEN_ON in CallActivity only works once the screen is
                    // already interactive; this wakelock bridges the gap in terminated-app state.
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    @Suppress("DEPRECATION")
                    val wakeLock = pm.newWakeLock(
                        PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                        PowerManager.ACQUIRE_CAUSES_WAKEUP or
                        PowerManager.ON_AFTER_RELEASE,
                        "amigo:incomingCall"
                    )
                    wakeLock.acquire(15_000L)

                    // Show incoming call notification (fullScreenIntent fires CallActivity)
                    val notifManager = CallNotificationManager.getInstance(this)
                    notifManager.showIncomingCallNotification(callId.toInt(), callerName, callerPfp, null)

                    // Also try starting CallActivity directly — FCM handlers have BAL privilege
                    // on most Android versions; if the system blocks it, the notification handles it.
                    try {
                        val callIntent = Intent(this, CallActivity::class.java).apply {
                            putExtra(CallActivity.EXTRA_CALL_ID, callId.toInt())
                            putExtra(CallActivity.EXTRA_CALLER_NAME, callerName)
                            putExtra(CallActivity.EXTRA_CALLER_PHOTO, callerPfp)
                            putExtra(CallActivity.EXTRA_CALL_MODE, "incoming")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        }
                        startActivity(callIntent)
                    } catch (e: Exception) {
                        Log.w(TAG, "Direct CallActivity start blocked (will use fullScreenIntent): ${e.message}")
                    }

                    // Release wakelock after 5 s — the activity holds its own from here
                    Handler(Looper.getMainLooper()).postDelayed({
                        if (wakeLock.isHeld) wakeLock.release()
                    }, 5_000L)
                }

                "call:missed" -> {
                    val callerName = payload.optString("caller_name", "Unknown")
                    val callId = payload.optLong("call_id", 0L)
                    CallNotificationManager.getInstance(this)
                        .showMissedCallNotification(callId.toInt(), callerName)
                }

                "call:terminate" -> {
                    try { CallNotificationForegroundService.stop(this) } catch (_: Exception) {}
                    CallNotificationManager.getInstance(this).dismissAllNotifications()
                    CallActivity.dismiss(this)
                    clearCallDetails()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling call FCM: ${e.message}", e)
        }
    }

    private fun clearCallDetails() {
        try {
            val prefs = getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            prefs.edit().remove(CALL_DETAILS_KEY).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing call details: ${e.message}", e)
        }
    }

    private fun saveCallDetailsToPrefs(callId: Long, callerId: Long, callerName: String, callerPfp: String?) {
        try {
            val json = JSONObject().apply {
                put("call_id", callId)
                put("caller_id", callerId)
                put("caller_name", callerName)
                if (callerPfp != null) put("caller_profile_pic", callerPfp)
                put("call_status", "ringing")
            }
            val prefs = getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            prefs.edit().putString(CALL_DETAILS_KEY, json.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving call details to prefs: ${e.message}", e)
        }
    }
}
