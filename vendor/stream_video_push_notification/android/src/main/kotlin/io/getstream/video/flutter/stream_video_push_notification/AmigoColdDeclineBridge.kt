package io.getstream.video.flutter.stream_video_push_notification

import android.content.Context
import android.os.Bundle
import android.util.Log
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * [AMIGO-PATCH] Cold-state decline bridge.
 *
 * When the user taps the Decline action on an incoming-call notification
 * while the app is in killed state, no Flutter isolate is alive to call
 * Stream's `call.reject()` — so the caller stays in a ringing-limbo until
 * Stream's natural ring timeout fires. To bridge that gap, we fire a
 * fire-and-forget HTTP POST from native Kotlin to our own backend's
 * `/call/stream/decline-cold` endpoint, which then performs the reject
 * server-side (it holds the API secret and can mint a one-shot JWT for
 * the user without needing the user's Stream token).
 *
 * Backend URL + the user's id are read from Flutter's SharedPreferences
 * (`flutter.stream_user_id` and `flutter.stream_backend_base`), which our
 * Dart-side token loader writes after every credentials fetch. If either
 * is missing we silently drop the request — better than crashing the
 * notification flow.
 */
object AmigoColdDeclineBridge {
    private const val TAG = "AmigoColdDecline"
    private const val PREFS_FILE = "FlutterSharedPreferences"
    private const val USER_ID_KEY = "flutter.stream_user_id"
    private const val BACKEND_BASE_KEY = "flutter.stream_backend_base"

    private val executor = Executors.newSingleThreadExecutor()

    fun notifyDecline(context: Context, data: Bundle) {
        val callCid = (data.getString("callCid") ?: data.getString("call_cid"))
        if (callCid.isNullOrBlank()) {
            // Stream's notification data uses "extra.callCid" — pull from
            // the inner extras Bundle if present.
            val extras = data.getBundle("extra")
            val nestedCid = extras?.getString("callCid")
            if (nestedCid.isNullOrBlank()) {
                Log.w(TAG, "no call_cid in decline data; cannot notify backend")
                return
            }
            return notifyDeclineWithCid(context, nestedCid)
        }
        notifyDeclineWithCid(context, callCid)
    }

    private fun notifyDeclineWithCid(context: Context, callCid: String) {
        val prefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        val userId = prefs.getString(USER_ID_KEY, null)
        val backendBase = prefs.getString(BACKEND_BASE_KEY, null)
        if (userId.isNullOrBlank() || backendBase.isNullOrBlank()) {
            Log.w(TAG, "missing prefs (user_id=$userId base=$backendBase) — skip cold decline")
            return
        }
        val url = "$backendBase/call/stream/decline-cold"
        val payload = "{\"call_cid\":\"$callCid\",\"user_id\":\"$userId\"}"
        Log.i(TAG, "notifying backend: POST $url cid=$callCid user=$userId")
        executor.submit {
            try {
                val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    doOutput = true
                    connectTimeout = 5_000
                    readTimeout = 5_000
                    setRequestProperty("Content-Type", "application/json")
                }
                OutputStreamWriter(conn.outputStream).use { it.write(payload) }
                val code = conn.responseCode
                Log.i(TAG, "backend response: $code")
                conn.disconnect()
            } catch (e: Exception) {
                Log.w(TAG, "cold decline notify failed: ${e.message}")
            }
        }
    }
}
