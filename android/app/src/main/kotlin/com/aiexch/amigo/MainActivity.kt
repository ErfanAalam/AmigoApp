package com.aiexch.amigo

import android.app.KeyguardManager
import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.util.Log
import android.view.KeyEvent
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

    /// Proximity wake lock held during audio calls. We keep a reference so
    /// release is idempotent and we can clean up in onDestroy. Created
    /// lazily in [acquireProximityLock] because some devices don't have a
    /// proximity sensor, and creating a WakeLock for an unsupported level
    /// would log a warning we don't need.
    private var proximityWakeLock: PowerManager.WakeLock? = null

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
                "setCallScreenMode" -> {
                    // Per-call screen behavior. See [setCallScreenMode] for
                    // the per-mode contract. Driven from Dart's
                    // _ActiveCallView so the mode tracks the live state of
                    // the call (audio ↔ video on user toggle, none on
                    // dispose).
                    val mode = call.argument<String>("mode")
                    if (mode.isNullOrEmpty()) {
                        result.error(
                            "MISSING_ARG",
                            "setCallScreenMode requires a non-empty 'mode' string",
                            null,
                        )
                    } else {
                        setCallScreenMode(mode)
                        result.success(true)
                    }
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
                    "playBusy" -> {
                        AmigoRingtoneManager.playBusy()
                        result.success(true)
                    }
                    "playOneShot" -> {
                        // Transient signaling sound (connect / disconnect
                        // beep). The flutter asset path comes through as
                        // `asset`; we resolve it inside the manager via
                        // FlutterInjector so this works in release builds.
                        val asset = call.argument<String>("asset")
                        if (asset.isNullOrEmpty()) {
                            result.error(
                                "MISSING_ARG",
                                "playOneShot requires a non-empty 'asset' string",
                                null,
                            )
                        } else {
                            AmigoRingtoneManager.playOneShot(applicationContext, asset)
                            result.success(true)
                        }
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

    /**
     * Intercept volume-up / volume-down key presses while a call ringtone is
     * playing and treat them as "silence the ringer" instead of letting the
     * OS adjust stream volume. Standard phone-app behaviour — first press of
     * either volume button mutes the ring without rejecting the call.
     *
     * We consume only the DOWN event of the keypress when ringing; the UP
     * event is also consumed so the OS doesn't deliver a stray half-press
     * (which on some OEMs surfaces a volume HUD slider on a now-silent ring).
     * When no ringtone is active we return super so the OS handles volume
     * normally — e.g. during a connected call, volume keys still adjust the
     * in-call audio stream as expected.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        if (code == KeyEvent.KEYCODE_VOLUME_DOWN || code == KeyEvent.KEYCODE_VOLUME_UP) {
            if (AmigoRingtoneManager.isRinging()) {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    Log.i(TAG, "volume key while ringing — silencing ringtone")
                    try {
                        AmigoRingtoneManager.stop()
                    } catch (e: Exception) {
                        Log.w(TAG, "stop ringtone failed: ${e.message}")
                    }
                }
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onDestroy() {
        // Belt-and-braces: kill any ringtone if the activity is being torn
        // down. Flutter's call.service can't reliably stop the ringtone if
        // the engine is being detached, so we make sure native resources
        // don't outlive the process.
        try { AmigoRingtoneManager.stop() } catch (_: Exception) {}
        // Release the proximity wake lock if Dart didn't get a chance to
        // (e.g. the process is being killed). System WakeLock leaks survive
        // the activity and keep the proximity sensor pinned on; explicit
        // cleanup here prevents that.
        try { releaseProximityLock() } catch (_: Exception) {}
        try {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } catch (_: Exception) {}
        isFlutterRunning = false
        super.onDestroy()
    }

    /**
     * Per-call screen behavior driven from Dart's `_ActiveCallView`.
     *
     *  - 'audio'  — acquire PROXIMITY_SCREEN_OFF_WAKE_LOCK so holding the
     *               phone to the ear turns the screen off (and back on when
     *               pulled away). Clear FLAG_KEEP_SCREEN_ON so it doesn't
     *               compete with the proximity lock.
     *  - 'video'  — release proximity (the user is looking at the screen)
     *               and add FLAG_KEEP_SCREEN_ON so the idle daemon doesn't
     *               dim during a long video call. Same mechanism a video
     *               player uses.
     *  - 'none'   — release both. Called on _ActiveCallView dispose so the
     *               post-call UI behaves normally.
     *
     * Idempotent: re-acquiring a held wake lock is a no-op; clearing an
     * already-cleared flag likewise. Safe to call any → any.
     */
    private fun setCallScreenMode(mode: String) {
        Log.i(TAG, "setCallScreenMode($mode)")
        when (mode) {
            "audio" -> {
                acquireProximityLock()
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
            "video" -> {
                releaseProximityLock()
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
            "none" -> {
                releaseProximityLock()
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
            else -> Log.w(TAG, "setCallScreenMode: unknown mode '$mode'")
        }
    }

    private fun acquireProximityLock() {
        if (proximityWakeLock?.isHeld == true) return
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) {
                Log.w(TAG, "proximity wake lock unsupported on this device — skipping")
                return
            }
            val wl = pm.newWakeLock(
                PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
                "Amigo:call:proximity",
            )
            // Not reference-counted — we own this lock 1:1 with the active
            // _ActiveCallView. Multiple acquire() calls in a row should NOT
            // require matching release() calls; the held-check at the top
            // already gates re-acquisition.
            wl.setReferenceCounted(false)
            wl.acquire()
            proximityWakeLock = wl
            Log.i(TAG, "proximity wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "acquireProximityLock failed: ${e.message}", e)
        }
    }

    private fun releaseProximityLock() {
        val wl = proximityWakeLock ?: return
        try {
            if (wl.isHeld) {
                // No RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY: when the user hangs
                // up while still holding the phone to their ear, we want the
                // screen to come back on immediately so they see the
                // post-call UI / unlock prompt. Waiting for the sensor to
                // clear would leave them staring at a black screen.
                wl.release()
                Log.i(TAG, "proximity wake lock released")
            }
        } catch (e: Exception) {
            Log.w(TAG, "releaseProximityLock failed: ${e.message}")
        } finally {
            proximityWakeLock = null
        }
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
