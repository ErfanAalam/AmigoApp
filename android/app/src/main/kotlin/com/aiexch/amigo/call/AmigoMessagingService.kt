package com.aiexch.amigo.call

import android.content.Context
import android.content.Intent
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
        Log.d(TAG, "onMessageReceived: type=$type")

        if (type == "call") {
            handleCallNatively(message.data)
            // Do NOT call super — prevents Flutter background isolate from running for calls,
            // which avoids the MethodChannel-unavailable crash in terminated state
        } else {
            // Chat messages and other types handled by Flutter
            super.onMessageReceived(message)
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
