package com.aiexch.amigo.call

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Receives the "Hang up" action from the CallStyle notification posted by
 * [StreamOngoingCallNotifier] and forwards it to Dart over a MethodChannel
 * so `StreamCallService` can call `call.leave()`.
 */
class StreamCallActionReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "StreamCallActionReceiver"

        /** Cached FlutterEngine key — the host MainActivity is responsible
         *  for putting the running engine into this slot at startup. */
        private const val ENGINE_KEY = "amigo_main_engine"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val callId = intent.getStringExtra("callId")
        Log.i(TAG, "🔘 onReceive action=${intent.action}  callId=$callId")

        if (intent.action != StreamOngoingCallNotifier.ACTION_HANGUP) {
            Log.w(TAG, "ignoring non-HANGUP action: ${intent.action}")
            return
        }

        // Lookup the running Flutter engine. If the app is killed there's no
        // engine to talk to — the broadcast is best-effort.
        val engine: FlutterEngine = FlutterEngineCache.getInstance().get(ENGINE_KEY)
            ?: run {
                Log.w(TAG, "no engine in cache — ignoring hangup (app likely killed)")
                return
            }

        Log.i(TAG, "forwarding hangup to Dart over MethodChannel")
        val channel = MethodChannel(
            engine.dartExecutor.binaryMessenger,
            StreamOngoingCallNotifier.CHANNEL_ID_DART,
        )
        channel.invokeMethod("onHangup", mapOf("callId" to callId))
    }
}
