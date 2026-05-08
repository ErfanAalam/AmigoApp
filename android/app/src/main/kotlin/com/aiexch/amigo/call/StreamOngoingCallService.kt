package com.aiexch.amigo.call

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Foreground service that owns the Stream call's CallStyle notification AND
 * holds the FOREGROUND_SERVICE_MICROPHONE permission so the WebRTC mic stays
 * captured while the app is backgrounded.
 *
 * Why this exists: previously we posted the CallStyle notification with
 * `NotificationManager.notify(...)` (no FG service). That works for the
 * visual sticky, but the moment the user minimizes the app, Android starts
 * pausing background mic capture — the SFU stops getting audio, the call
 * silently dies on the minimizer's side, and the other party doesn't know.
 * Re-enabling Stream's `StreamBackgroundService.init()` solved the mic but
 * spawned a duplicate notification (the user complained). This service is
 * the in-between: single sticky (the CallStyle one we already love), and a
 * proper FG service binding underneath that keeps the mic alive.
 *
 * Lifecycle:
 *   - `start(context, notification)` from [StreamOngoingCallNotifier.show]
 *     → ContextCompat.startForegroundService → onStartCommand → startForeground
 *   - `stop(context)` from [StreamOngoingCallNotifier.hide]
 *     → service.stopSelf() (after stopForeground)
 *   - User swipes the app away from recents → onTaskRemoved → forwards to
 *     Dart over the same MethodChannel as the hang-up button so the call
 *     ends cleanly. Replaces the `setOnPlatformUiLayerDestroyed` plumbing
 *     we used to inherit from Stream's FG service.
 */
class StreamOngoingCallService : Service() {

    companion object {
        private const val TAG = "StreamOngoingCallSvc"
        const val ACTION_START = "com.aiexch.amigo.STREAM_CALL_FG_START"
        const val ACTION_STOP = "com.aiexch.amigo.STREAM_CALL_FG_STOP"
        const val EXTRA_NOTIFICATION = "notification"
        private const val ENGINE_KEY = "amigo_main_engine"

        fun start(context: Context, notification: Notification) {
            val intent = Intent(context, StreamOngoingCallService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_NOTIFICATION, notification)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, StreamOngoingCallService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (e: Exception) {
                // OK if the service isn't running.
                Log.d(TAG, "stop() — service not running: ${e.message}")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand action=${intent?.action}")
        when (intent?.action) {
            ACTION_START -> {
                val notification: Notification? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(EXTRA_NOTIFICATION, Notification::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(EXTRA_NOTIFICATION)
                }
                if (notification == null) {
                    Log.w(TAG, "ACTION_START with no notification — stopping")
                    stopSelf()
                    return START_NOT_STICKY
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        startForeground(
                            NOTIFICATION_ID,
                            notification,
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                        )
                    } else {
                        startForeground(NOTIFICATION_ID, notification)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "startForeground failed: ${e.message}")
                    stopSelf()
                }
            }
            ACTION_STOP -> {
                Log.i(TAG, "ACTION_STOP — tearing down")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.i(TAG, "onTaskRemoved — user swiped app from recents during call")
        super.onTaskRemoved(rootIntent)
        // Forward to Dart so StreamCallService can leave/end the call before
        // the process is reaped. Best-effort — the engine may not be alive.
        val engine = FlutterEngineCache.getInstance().get(ENGINE_KEY)
        if (engine != null) {
            try {
                val channel = MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    StreamOngoingCallNotifier.CHANNEL_ID_DART,
                )
                channel.invokeMethod("onTaskRemoved", null)
            } catch (e: Exception) {
                Log.w(TAG, "onTaskRemoved → Dart MethodChannel failed: ${e.message}")
            }
        }
        // Also stop ourselves so the system reclaims the FG slot.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private val NOTIFICATION_ID = 0xCA11
}
