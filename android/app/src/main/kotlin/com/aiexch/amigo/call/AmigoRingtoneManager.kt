package com.aiexch.amigo.call

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector

/**
 * Foreground-state ringtone playback for Stream calls.
 *
 * The Stream Flutter SDK only handles audio when the app is killed (the
 * incoming-call notification channel plays a sound at the OS level). When
 * the app is in the foreground we drive playback ourselves; this module
 * is the single source of truth for that.
 *
 *   - playIncoming() — phone's default ringtone, looped, ringtone-style
 *     audio attributes so it routes through the speaker at ringer volume.
 *   - playOutgoing() — TONE_SUP_RINGTONE via ToneGenerator, the standard
 *     telephony ringback ("turr.. turr..") cadence. ToneGenerator handles
 *     the loop internally; we just start and stop.
 *   - stop() — kills both. Always safe to call. Idempotent.
 *
 * All three are synchronized on a single mutex so transitions never race.
 * The previous flutter_ringtone_player implementation occasionally left the
 * ringtone playing forever — its stop() didn't actually wait for the play
 * Future, so a play that resolved AFTER stop kept the audio alive. The
 * synchronized block here makes that impossible.
 */
object AmigoRingtoneManager {
    private const val TAG = "AmigoRingtone"

    private val lock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var mediaPlayer: MediaPlayer? = null
    private var toneGenerator: ToneGenerator? = null

    // Force-stop fail-safe. If a call somehow gets into a state where the
    // stop signal never lands (Dart crashed, channel disconnected, …) we
    // still cap how long we'll hold a ringtone for. 90s is well past any
    // sane ring timeout (Stream's own timeout is ~30s).
    private var watchdog: Runnable? = null
    private var outgoingRetrigger: Runnable? = null
    private const val WATCHDOG_MS = 90_000L

    fun playIncoming(context: Context) {
        synchronized(lock) {
            Log.i(TAG, "playIncoming")
            stopInternal()

            // Reset audio mode in case a previous call session left us
            // stuck in MODE_IN_COMMUNICATION — that mode forces our
            // ringtone to play through the earpiece at low volume, which
            // is the "buzzing in earpiece" bug users hit before.
            try {
                val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                if (am.mode != AudioManager.MODE_NORMAL) {
                    Log.i(TAG, "resetting audio mode ${am.mode} → MODE_NORMAL")
                    am.mode = AudioManager.MODE_NORMAL
                }
                Log.i(TAG, "ringer mode=${am.ringerMode} ringVol=${am.getStreamVolume(AudioManager.STREAM_RING)}/${am.getStreamMaxVolume(AudioManager.STREAM_RING)}")
            } catch (e: Exception) {
                Log.w(TAG, "audio mode reset failed: ${e.message}")
            }

            // Resolve a usable URI in three tiers. Some OEM Androids
            // return null for getActualDefaultRingtoneUri when the user
            // is on a work profile or "Silent" tone is selected; falling
            // back through TYPE_NOTIFICATION → TYPE_ALARM keeps us audible
            // instead of failing open with no sound at all.
            val uri: Uri? =
                RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            Log.i(TAG, "incoming ringtone uri=$uri")
            if (uri == null) {
                Log.e(TAG, "no ringtone URI available — incoming ring will be silent")
                return
            }

            try {
                val mp = MediaPlayer()
                mp.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setLegacyStreamType(AudioManager.STREAM_RING)
                        .build()
                )
                mp.isLooping = true
                mp.setDataSource(context, uri)
                // setOnErrorListener surfaces decoder/IO failures so a
                // dead MediaPlayer doesn't keep its native resources tied
                // up and silently never play. We tear it down on error so
                // the next playIncoming() can retry with a fresh instance.
                mp.setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error what=$what extra=$extra")
                    synchronized(lock) { stopInternal() }
                    true
                }
                mp.prepare()
                mp.start()
                Log.i(TAG, "MediaPlayer started, isPlaying=${mp.isPlaying}")
                mediaPlayer = mp
                armWatchdog(context)
            } catch (e: Exception) {
                Log.e(TAG, "playIncoming failed: ${e.message}", e)
                stopInternal()
            }
        }
    }

    fun playOutgoing(context: Context) {
        synchronized(lock) {
            Log.i(TAG, "playOutgoing")
            stopInternal()

            try {
                // STREAM_MUSIC, NOT STREAM_VOICE_CALL: ToneGenerator on
                // STREAM_VOICE_CALL only produces audible output when the
                // device is in MODE_IN_COMMUNICATION, but we play ringback
                // BEFORE the SFU connects (i.e. while still in MODE_NORMAL),
                // which silently dropped all audio in the previous build.
                // STREAM_MUSIC plays through the standard media path and
                // is always audible. Volume 0-100 is ToneGenerator's own
                // scale, separate from the device's media-volume slider.
                val tg = ToneGenerator(AudioManager.STREAM_MUSIC, 80)
                // TONE_SUP_RINGTONE has the classic "ring-ring..ring-ring"
                // cadence baked in. Duration is the cap for ONE call to
                // startTone — the hardware decoder loops the cadence
                // until that many ms have elapsed. We re-arm every 30s
                // via the Handler so a long ring doesn't go silent.
                tg.startTone(ToneGenerator.TONE_SUP_RINGTONE, 30_000)
                toneGenerator = tg
                Log.i(TAG, "ToneGenerator started on STREAM_MUSIC, mode=${(context.getSystemService(Context.AUDIO_SERVICE) as AudioManager).mode}")
                armWatchdog(context)
                scheduleOutgoingRetrigger(context)
            } catch (e: Exception) {
                Log.e(TAG, "playOutgoing failed: ${e.message}", e)
                stopInternal()
            }
        }
    }

    private fun scheduleOutgoingRetrigger(context: Context) {
        outgoingRetrigger?.let { mainHandler.removeCallbacks(it) }
        val r = Runnable {
            synchronized(lock) {
                val tg = toneGenerator ?: return@synchronized
                try {
                    tg.stopTone()
                    tg.startTone(ToneGenerator.TONE_SUP_RINGTONE, 30_000)
                    Log.i(TAG, "outgoing retrigger")
                    scheduleOutgoingRetrigger(context)
                } catch (e: Exception) {
                    Log.w(TAG, "retrigger failed: ${e.message}")
                }
            }
        }
        outgoingRetrigger = r
        mainHandler.postDelayed(r, 28_000L)
    }

    fun stop() {
        synchronized(lock) {
            Log.i(TAG, "stop")
            stopInternal()
        }
    }

    /**
     * Self-releasing one-shot for short signaling sounds (call-connected and
     * call-disconnected beeps).
     *
     * Deliberately does NOT touch the looping ringtone state (mediaPlayer /
     * toneGenerator / watchdog) — the beep is transient and must coexist
     * with whatever else is playing (e.g. a still-fading outgoing tone). Each
     * invocation gets its own MediaPlayer that releases itself on completion
     * or error; there is no shared state to leak.
     *
     * Audio attributes:
     *  - USAGE_VOICE_COMMUNICATION_SIGNALLING + CONTENT_TYPE_SONIFICATION
     *    routes the beep through the in-call audio path, so it follows
     *    whatever output the call is using (earpiece / BT / wired / speaker)
     *    and doesn't grab persistent audio focus from the Stream WebRTC
     *    session.
     *
     * @param assetKey the flutter asset path, e.g.
     *   "assets/sounds/call_connected_beep.mp3". We resolve it through
     *   FlutterInjector so this works in both debug and release builds
     *   (where the asset lives inside the APK under a hashed key).
     */
    fun playOneShot(context: Context, assetKey: String) {
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            val lookupKey = loader.getLookupKeyForAsset(assetKey)
            val afd = context.assets.openFd(lookupKey)
            val mp = MediaPlayer()
            try {
                mp.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION_SIGNALLING)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            } finally {
                // MediaPlayer dup's the FD inside setDataSource — safe to
                // close the AssetFileDescriptor immediately. Closing in
                // `finally` so we don't leak if setDataSource threw.
                try { afd.close() } catch (_: Exception) {}
            }
            mp.setOnCompletionListener {
                try { it.release() } catch (_: Exception) {}
                Log.i(TAG, "playOneShot completed: $assetKey")
            }
            mp.setOnErrorListener { player, what, extra ->
                Log.w(TAG, "playOneShot MediaPlayer error " +
                        "what=$what extra=$extra ($assetKey)")
                try { player.release() } catch (_: Exception) {}
                true
            }
            mp.prepare()
            mp.start()
            Log.i(TAG, "playOneShot started: $assetKey")
        } catch (e: Exception) {
            Log.e(TAG, "playOneShot failed for $assetKey: ${e.message}", e)
        }
    }

    private fun stopInternal() {
        mediaPlayer?.let {
            try {
                if (it.isPlaying) it.stop()
            } catch (_: Exception) {}
            try { it.reset() } catch (_: Exception) {}
            try { it.release() } catch (_: Exception) {}
        }
        mediaPlayer = null

        toneGenerator?.let {
            try { it.stopTone() } catch (_: Exception) {}
            try { it.release() } catch (_: Exception) {}
        }
        toneGenerator = null

        watchdog?.let { mainHandler.removeCallbacks(it) }
        watchdog = null
        outgoingRetrigger?.let { mainHandler.removeCallbacks(it) }
        outgoingRetrigger = null
    }

    private fun armWatchdog(context: Context) {
        watchdog?.let { mainHandler.removeCallbacks(it) }
        val r = Runnable {
            Log.w(TAG, "watchdog fired — force-stopping ringtone")
            synchronized(lock) { stopInternal() }
        }
        watchdog = r
        mainHandler.postDelayed(r, WATCHDOG_MS)
    }
}
