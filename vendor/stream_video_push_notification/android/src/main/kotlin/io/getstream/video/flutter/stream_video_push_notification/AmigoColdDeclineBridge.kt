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
        // The cid travels inside a HashMap<String, Any?> serialized under
        // `IncomingCallConstants.EXTRA_CALL_EXTRA` (see Call.toBundle:
        // `bundle.putSerializable(EXTRA_CALL_EXTRA, extra)` where `extra`
        // is the Dart-side `{'callCid': callCid}` map). It is NOT a plain
        // string key on the bundle. Old code tried `getString("callCid")`
        // / `getBundle("extra")` and silently bailed every time.
        val cid = extractCallCid(data)
        if (cid.isNullOrBlank()) {
            // Help the next bug-hunt: dump every key so we can see what
            // the SDK actually delivered.
            val keys = data.keySet().joinToString(",")
            Log.w(TAG, "no call_cid in decline data; cannot notify backend (bundle keys=[$keys])")
            return
        }
        notifyDeclineWithCid(context, cid)
    }

    @Suppress("UNCHECKED_CAST", "DEPRECATION")
    private fun extractCallCid(data: Bundle): String? {
        // 1) Canonical path: HashMap under EXTRA_CALL_EXTRA → "callCid".
        try {
            val extras = data.getSerializable(IncomingCallConstants.EXTRA_CALL_EXTRA)
            if (extras is HashMap<*, *>) {
                val v = extras["callCid"]
                if (v is String && v.isNotBlank()) return v
            }
        } catch (e: Exception) {
            Log.w(TAG, "extras serializable read failed: ${e.message}")
        }
        // 2) Fallbacks for older payloads / belt-and-braces in case the
        //    SDK shape changes.
        data.getString("callCid")?.takeIf { it.isNotBlank() }?.let { return it }
        data.getString("call_cid")?.takeIf { it.isNotBlank() }?.let { return it }
        // The handle field gets populated from `created_by_id` on the Dart
        // side — not the cid, but log it so the bug-hunt is easier next time.
        val handle = data.getString(IncomingCallConstants.EXTRA_CALL_HANDLE)
        Log.d(TAG, "no canonical cid; EXTRA_CALL_HANDLE=$handle")
        return null
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
