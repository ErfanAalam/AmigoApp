package com.aiexch.amigo

import android.app.KeyguardManager
import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import com.aiexch.amigo.call.AmigoCallPlugin
import com.aiexch.amigo.call.AmigoRingtoneManager
import com.aiexch.amigo.call.StreamOngoingCallNotifier
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aiexch.amigo/lock_screen"
    private val RINGTONE_CHANNEL = "com.aiexch.amigo/stream_ringtone"
    private var lockScreenFlagsEnabled = false

    companion object {
        private const val TAG = "MainActivity"
        private const val PREFS_FILE = "FlutterSharedPreferences"
        private const val CALL_DETAILS_KEY = "flutter.current_call_details"

        // Statuses that mean a call is in flight; while any of these are set
        // the activity must be allowed to render over the keyguard so it
        // doesn't trigger the device password prompt on cold start.
        private val ACTIVE_CALL_STATUSES = setOf(
            "ringing", "accepting", "active", "in_call", "outgoing", "connecting"
        )

        /**
         * True while a Flutter engine is attached to MainActivity in this
         * process. Read from FCM service to decide whether the main
         * isolate's Stream WS will already deliver an incoming-call event;
         * when true we skip flutter_callkit_incoming on the background
         * isolate to avoid two ringtones playing in parallel.
         *
         * Cleared in onDestroy so the next FCM after a clean teardown
         * falls back to the FCM/CallKit path.
         */
        @Volatile
        var isFlutterRunning: Boolean = false
            private set
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        isFlutterRunning = true

        // Register the native call screen plugin (used by the legacy WebRTC backend).
        flutterEngine.plugins.add(AmigoCallPlugin())

        // Cache the running engine so background broadcast receivers (e.g.
        // the CallStyle notification's "Hang up" action) can talk back to
        // Dart even when the activity is paused.
        FlutterEngineCache.getInstance().put("amigo_main_engine", flutterEngine)

        // CallStyle ongoing-call notification for the Stream backend. This
        // is the truly non-dismissable layer — Stream's own foreground
        // service stays underneath for mic/audio. Dart drives it via a
        // MethodChannel.
        StreamOngoingCallNotifier.attach(applicationContext, flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableLockScreenFlags" -> {
                    enableLockScreenFlags()
                    result.success(true)
                }
                "disableLockScreenFlags" -> {
                    disableLockScreenFlags()
                    result.success(true)
                }
                "dismissKeyguard" -> {
                    // Explicit keyguard dismissal — only for user-initiated
                    // actions that need access to the rest of the app (e.g.
                    // tapping minimize during a call). On secured devices
                    // this surfaces the unlock UI; that's intentional here
                    // and not the cold-start password prompt we're avoiding.
                    requestKeyguardDismissal()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Foreground ringtone playback for the Stream backend. Dart owns the
        // call.state stream, so it drives play/stop transitions; Kotlin owns
        // the audio resources (MediaPlayer + ToneGenerator) so the
        // mutex-guarded teardown is bullet-proof against the Dart-side
        // races that plagued the old flutter_ringtone_player path.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RINGTONE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playIncoming" -> {
                        AmigoRingtoneManager.playIncoming(applicationContext)
                        result.success(true)
                    }
                    "playOutgoing" -> {
                        AmigoRingtoneManager.playOutgoing(applicationContext)
                        result.success(true)
                    }
                    "stop" -> {
                        AmigoRingtoneManager.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // CRITICAL: showWhenLocked / turnScreenOn must be set BEFORE
        // super.onCreate so the keyguard doesn't intercept the launch.
        // Otherwise tapping "Answer" on the lock screen surfaces the
        // device password prompt before MainActivity can render. We only
        // do this when a call is actually in flight (legacy native path
        // and Stream both write `flutter.current_call_details`); for
        // normal launches the device should still require unlock.
        if (isCallInFlight()) {
            applyLockScreenFlags(requestDismiss = false)
        }

        super.onCreate(savedInstanceState)

        // Reset the AudioManager mode in case a previous call session left it
        // stuck on `MODE_IN_COMMUNICATION`. Stream's WebRTC engine uses the
        // BroadcasterAudioPolicy which forces this mode while a call is
        // active; if the process was killed mid-call (or Stream's cleanup
        // missed it), the system audio mode persists and routes ALL
        // subsequent audio (including our incoming-call ringtones) through
        // the earpiece at in-call volume — which is the user-reported
        // "ringtone is buzzing in the in-ear speaker" bug.
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (am.mode != AudioManager.MODE_NORMAL) {
                Log.i("MainActivity", "Resetting audio mode (was ${am.mode}) → MODE_NORMAL")
                am.mode = AudioManager.MODE_NORMAL
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "Audio mode reset failed: ${e.message}")
        }
    }

    override fun onDestroy() {
        // Belt-and-braces: kill any ringtone if the activity is being torn
        // down. Flutter's call.service can't reliably stop the ringtone if
        // the engine is being detached, so we make sure native resources
        // don't outlive the process.
        try { AmigoRingtoneManager.stop() } catch (_: Exception) {}
        isFlutterRunning = false
        super.onDestroy()
    }

    /**
     * Display flags only — the activity renders over the keyguard but the
     * keyguard itself is not dismissed. Flutter tap input still reaches the
     * activity because `showWhenLocked` makes touches pass through.
     *
     * The previous implementation auto-dismissed the keyguard here, which on
     * secured devices triggers the device unlock UI — i.e. the password
     * prompt we are trying to avoid on cold-start accept. Dismissal is now
     * opt-in via `requestKeyguardDismissal` (exposed as `dismissKeyguard`
     * on the method channel).
     */
    private fun enableLockScreenFlags() {
        applyLockScreenFlags(requestDismiss = false)
    }

    private fun applyLockScreenFlags(requestDismiss: Boolean) {
        if (lockScreenFlagsEnabled && !requestDismiss) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        if (requestDismiss) {
            requestKeyguardDismissal()
        }

        lockScreenFlagsEnabled = true
    }

    private fun requestKeyguardDismissal() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
        }
    }

    private fun disableLockScreenFlags() {
        if (!lockScreenFlagsEnabled) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        } else {
            @Suppress("DEPRECATION")
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        lockScreenFlagsEnabled = false
    }

    private fun isCallInFlight(): Boolean {
        return try {
            val prefs = getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            val raw = prefs.getString(CALL_DETAILS_KEY, null) ?: return false
            val status = JSONObject(raw).optString("call_status", "")
            status in ACTIVE_CALL_STATUSES
        } catch (e: Exception) {
            Log.w(TAG, "isCallInFlight check failed: ${e.message}")
            false
        }
    }
}
