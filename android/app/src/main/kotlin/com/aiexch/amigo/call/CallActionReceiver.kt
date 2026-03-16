package com.aiexch.amigo.call

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.concurrent.thread

/**
 * Handles notification action buttons (Answer, Decline, End Call)
 */
class CallActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CallActionReceiver"
        private const val PREFS_FILE = "FlutterSharedPreferences"
        private const val CALL_DETAILS_KEY = "flutter.current_call_details"
        private const val BASE_URL_KEY = "flutter.api_base_url"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val callId = intent.getIntExtra(CallActivity.EXTRA_CALL_ID, 0)
        val notificationManager = CallNotificationManager.getInstance(context)

        logToFile(context, "onReceive: action=${intent.action} callId=$callId")

        when (intent.action) {
            CallNotificationManager.ACTION_ANSWER -> {
                logToFile(context, "ACTION_ANSWER received for callId=$callId")
                // Stop FGS + dismiss notification
                try { CallNotificationForegroundService.stop(context) } catch (_: Exception) {}
                notificationManager.dismissIncomingNotification()

                // Mark call as "accepting" in SharedPrefs so Flutter auto-accepts on startup
                setCallStatus(context, callId, "accepting")

                // Accept via HTTP API so the caller is notified immediately,
                // even if Flutter isn't running (terminated state).
                if (callId != 0) {
                    logToFile(context, "Calling acceptCallViaApi for callId=$callId")
                    acceptCallViaApi(context, callId)
                } else {
                    logToFile(context, "callId is 0, skipping acceptCallViaApi")
                }

                // Launch CallActivity in in_call mode with auto-accept flag
                val callIntent = Intent(context, CallActivity::class.java).apply {
                    putExtra(CallActivity.EXTRA_CALL_ID, callId)
                    putExtra(CallActivity.EXTRA_CALLER_NAME, intent.getStringExtra(CallActivity.EXTRA_CALLER_NAME))
                    putExtra(CallActivity.EXTRA_CALLER_PHOTO, intent.getStringExtra(CallActivity.EXTRA_CALLER_PHOTO))
                    putExtra(CallActivity.EXTRA_CALL_MODE, "in_call")
                    putExtra(CallActivity.EXTRA_AUTO_ACCEPT, true)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                context.startActivity(callIntent)

                // If Flutter is running, notify it directly
                AmigoCallPlugin.sendEvent("onCallAccepted", mapOf("callId" to callId))

                // Also launch MainActivity so Flutter starts (if terminated) and reads "accepting" status
                launchMainActivity(context)
            }

            CallNotificationManager.ACTION_DECLINE -> {
                // Stop foreground service
                try { CallNotificationForegroundService.stop(context) } catch (_: Exception) {}
                notificationManager.dismissIncomingNotification()
                CallActivity.dismiss(context)

                // Notify Flutter if running
                AmigoCallPlugin.sendEvent("onCallDeclined", mapOf("callId" to callId))

                // Decline via HTTP API so the caller is notified immediately,
                // even if Flutter isn't running (terminated state).
                if (callId != 0) {
                    declineCallViaApi(context, callId)
                }

                // Clear call details AFTER reading base URL for API call
                clearCallDetails(context)
            }

            CallNotificationManager.ACTION_END_CALL -> {
                try { CallNotificationForegroundService.stop(context) } catch (_: Exception) {}
                notificationManager.dismissAllNotifications()
                clearCallDetails(context)
                CallActivity.dismiss(context)
                AmigoCallPlugin.sendEvent("onCallEnded", mapOf("callId" to callId))
            }
        }
    }

    /** Accept the call via a direct HTTP POST to the backend. */
    private fun acceptCallViaApi(context: Context, callId: Int) {
        val baseUrl = getBaseUrl(context)
        logToFile(context, "acceptCallViaApi: baseUrl=$baseUrl callId=$callId")
        if (baseUrl == null) {
            logToFile(context, "acceptCallViaApi: baseUrl is null, aborting")
            return
        }
        thread {
            try {
                val urlStr = "$baseUrl/call/accept/$callId"
                logToFile(context, "acceptCallViaApi: connecting to $urlStr")
                val url = URL(urlStr)
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.connectTimeout = 5000
                conn.readTimeout = 5000
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.outputStream.use { it.write("{}".toByteArray()) }
                val code = conn.responseCode
                val body = try { conn.inputStream.bufferedReader().readText() } catch (_: Exception) {
                    try { conn.errorStream?.bufferedReader()?.readText() } catch (_: Exception) { "<no body>" }
                }
                logToFile(context, "acceptCallViaApi: response code=$code body=$body")
                Log.d(TAG, "Accept API response: $code for callId=$callId")
                conn.disconnect()
            } catch (e: Exception) {
                logToFile(context, "acceptCallViaApi: EXCEPTION ${e.javaClass.simpleName}: ${e.message}")
                Log.e(TAG, "Error accepting call via API: ${e.message}")
            }
        }
    }

    /** Decline the call via a direct HTTP POST to the backend. */
    private fun declineCallViaApi(context: Context, callId: Int) {
        val baseUrl = getBaseUrl(context) ?: return
        thread {
            try {
                val url = URL("$baseUrl/call/decline/$callId")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.connectTimeout = 5000
                conn.readTimeout = 5000
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.outputStream.use { it.write("{}".toByteArray()) }
                val code = conn.responseCode
                Log.d(TAG, "Decline API response: $code for callId=$callId")
                conn.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "Error declining call via API: ${e.message}")
            }
        }
    }

    private fun getBaseUrl(context: Context): String? {
        return try {
            val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            val url = prefs.getString(BASE_URL_KEY, null)
            logToFile(context, "getBaseUrl: key=$BASE_URL_KEY value=$url")
            url
        } catch (e: Exception) {
            logToFile(context, "getBaseUrl: EXCEPTION ${e.message}")
            Log.e(TAG, "Error reading base URL: ${e.message}")
            null
        }
    }

    private fun logToFile(context: Context, message: String) {
        try {
            val ts = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date())
            val line = "[$ts] $message\n"
            Log.d(TAG, message)
            val dir = context.getExternalFilesDir(null) ?: context.filesDir
            val file = File(dir, "call_debug.log")
            file.appendText(line)
        } catch (_: Exception) {}
    }

    /** Update the call_status field in the shared call-details blob used by Flutter. */
    private fun setCallStatus(context: Context, callId: Int, status: String) {
        try {
            val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            val existing = prefs.getString(CALL_DETAILS_KEY, null)
            val json = if (existing != null) {
                try { JSONObject(existing).put("call_status", status) }
                catch (_: Exception) { JSONObject().put("call_id", callId).put("call_status", status) }
            } else {
                JSONObject().put("call_id", callId).put("call_status", status)
            }
            prefs.edit().putString(CALL_DETAILS_KEY, json.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error setting call status: ${e.message}")
        }
    }

    private fun clearCallDetails(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            prefs.edit().remove(CALL_DETAILS_KEY).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing call details: ${e.message}")
        }
    }

    private fun launchMainActivity(context: Context) {
        try {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            }
            launchIntent?.let { context.startActivity(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Error launching main activity: ${e.message}")
        }
    }
}
