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

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aiexch.amigo/lock_screen"
    private val RINGTONE_CHANNEL = "com.aiexch.amigo/stream_ringtone"
    private var lockScreenFlagsEnabled = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
        super.onCreate(savedInstanceState)
        // Don't toggle lock-screen flags by default; Dart enables them when the
        // Stream/WebRTC call screen mounts and disables them on dispose.

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
        super.onDestroy()
    }

    /**
     * Enable display over the lock screen. Combines:
     *   - Activity#setShowWhenLocked / setTurnScreenOn  (API 27+)
     *   - KeyguardManager#requestDismissKeyguard          (API 26+)
     *   - Legacy WindowManager flags                      (API < 27 fallback)
     *
     * The keyguard-dismiss request is what makes Stream's call screen actually
     * usable from the lock screen on modern Android — without it, taps on
     * Flutter widgets are swallowed by the keyguard.
     */
    private fun enableLockScreenFlags() {
        if (lockScreenFlagsEnabled) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }

        // Always keep the screen on regardless of API level.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Ask the system to dismiss the keyguard so user input reaches Flutter.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        }

        lockScreenFlagsEnabled = true
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
}
