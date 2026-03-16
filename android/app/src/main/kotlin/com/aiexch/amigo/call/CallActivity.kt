package com.aiexch.amigo.call

import com.aiexch.amigo.R
import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.os.Handler
import android.os.Looper
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Shader
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.view.WindowManager
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.Chronometer
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.app.Activity
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.concurrent.thread

class CallActivity : Activity() {

    companion object {
        private const val TAG = "CallActivity"
        private const val PREFS_FILE = "FlutterSharedPreferences"
        private const val CALL_DETAILS_KEY = "flutter.current_call_details"

        const val EXTRA_CALL_ID = "call_id"
        const val EXTRA_CALLER_NAME = "caller_name"
        const val EXTRA_CALLER_PHOTO = "caller_photo"
        const val EXTRA_CALLER_PHONE = "caller_phone"
        const val EXTRA_CALL_MODE = "call_mode"  // "incoming", "outgoing", "in_call"
        const val EXTRA_IS_MUTED = "is_muted"
        const val EXTRA_IS_SPEAKER_ON = "is_speaker_on"
        const val EXTRA_CALL_DURATION = "call_duration"
        const val EXTRA_AUTO_ACCEPT = "auto_accept"

        const val ACTION_UPDATE_STATE = "com.aiexch.amigo.call.UPDATE_STATE"
        const val ACTION_DISMISS = "com.aiexch.amigo.call.DISMISS"

        private var instance: CallActivity? = null

        fun isActive(): Boolean = instance != null

        fun updateState(
            context: Context,
            mode: String?,
            isMuted: Boolean?,
            isSpeakerOn: Boolean?,
            duration: Long?
        ) {
            val intent = Intent(ACTION_UPDATE_STATE).apply {
                setPackage(context.packageName)
                mode?.let { putExtra(EXTRA_CALL_MODE, it) }
                isMuted?.let { putExtra(EXTRA_IS_MUTED, it) }
                isSpeakerOn?.let { putExtra(EXTRA_IS_SPEAKER_ON, it) }
                duration?.let { putExtra(EXTRA_CALL_DURATION, it) }
            }
            context.sendBroadcast(intent)
        }

        fun dismiss(context: Context) {
            val intent = Intent(ACTION_DISMISS).apply {
                setPackage(context.packageName)
            }
            context.sendBroadcast(intent)
        }
    }

    // Views
    private lateinit var btnMinimize: FrameLayout
    private lateinit var statusBadge: TextView
    private lateinit var callTypeLabel: TextView
    private lateinit var avatar: ImageView
    private lateinit var avatarPlaceholder: FrameLayout
    private lateinit var avatarInitial: TextView
    private lateinit var callerNameView: TextView
    private lateinit var callStatusText: TextView
    private lateinit var durationTimer: Chronometer
    private lateinit var controlsRow: LinearLayout
    private lateinit var incomingActions: LinearLayout
    private lateinit var endCallContainer: LinearLayout
    private lateinit var btnMute: FrameLayout
    private lateinit var btnSpeaker: FrameLayout
    private lateinit var btnEndCallRow: FrameLayout
    private lateinit var btnDecline: FrameLayout
    private lateinit var btnAccept: FrameLayout
    private lateinit var btnEndCall: FrameLayout
    private lateinit var iconMute: ImageView
    private lateinit var iconSpeaker: ImageView
    private lateinit var labelMute: TextView
    private lateinit var labelSpeaker: TextView
    private lateinit var endCallLabel: TextView
    private lateinit var pulseRing1: View
    private lateinit var pulseRing2: View

    // State
    private var callId: Int = 0
    private var callerName: String = "Unknown"
    private var callerPhoto: String? = null
    private var callMode: String = "incoming" // incoming, outgoing, in_call
    private var isMuted: Boolean = false
    private var isSpeakerOn: Boolean = false
    private var timerBase: Long = 0L
    private var pulseAnimator: AnimatorSet? = null
    private var isFinishing: Boolean = false

    private val stateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_UPDATE_STATE -> {
                    intent.getStringExtra(EXTRA_CALL_MODE)?.let { newMode ->
                        if (newMode != callMode) {
                            callMode = newMode
                            runOnUiThread { updateUI() }
                        }
                    }
                    if (intent.hasExtra(EXTRA_IS_MUTED)) {
                        isMuted = intent.getBooleanExtra(EXTRA_IS_MUTED, false)
                        runOnUiThread { updateToggleStates() }
                    }
                    if (intent.hasExtra(EXTRA_IS_SPEAKER_ON)) {
                        isSpeakerOn = intent.getBooleanExtra(EXTRA_IS_SPEAKER_ON, false)
                        runOnUiThread { updateToggleStates() }
                    }
                    if (intent.hasExtra(EXTRA_CALL_DURATION)) {
                        val duration = intent.getLongExtra(EXTRA_CALL_DURATION, 0)
                        runOnUiThread { updateDuration(duration) }
                    }
                }

                ACTION_DISMISS -> {
                    if (!isFinishing) {
                        isFinishing = true
                        runOnUiThread { finishWithAnimation() }
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show on lock screen
        setupLockScreenFlags()

        setContentView(R.layout.activity_call)

        // Parse intent extras
        parseIntent(intent)

        // Bind views
        bindViews()

        // Apply real status-bar height as top padding (fixes black bar on edge-to-edge)
        applyStatusBarInset()

        // Set up click listeners
        setupListeners()

        // Update UI based on initial mode
        updateUI()

        // Handle auto-accept from notification Answer button
        if (intent?.getBooleanExtra(EXTRA_AUTO_ACCEPT, false) == true) {
            handleAutoAccept()
        }

        // Load avatar
        loadAvatar()

        // Register broadcast receiver
        val filter = IntentFilter().apply {
            addAction(ACTION_UPDATE_STATE)
            addAction(ACTION_DISMISS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stateReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(stateReceiver, filter)
        }

        instance = this

        // Once call screen is visible for incoming calls, downgrade notification to silent
        // so it no longer makes noise / shows a banner while the UI is right in front of the user
        if (callMode == "incoming") {
            Handler(Looper.getMainLooper()).postDelayed({
                if (!isFinishing) {
                    try {
                        CallNotificationManager.getInstance(this)
                            .showSilentIncomingNotification(callId, callerName, callerPhoto)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to show silent notification: ${e.message}")
                    }
                }
            }, 500)
        }

        // Entrance animation
        playEntranceAnimation()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        parseIntent(intent)
        updateUI()
        loadAvatar()

        if (intent.getBooleanExtra(EXTRA_AUTO_ACCEPT, false)) {
            handleAutoAccept()
        }
    }

    private fun handleAutoAccept() {
        logToFile("handleAutoAccept: callId=$callId")
        Log.d(TAG, "Auto-accepting call from notification button")
        // Stop FGS + dismiss notification
        try {
            CallNotificationForegroundService.stop(this)
        } catch (_: Exception) {
        }
        CallNotificationManager.getInstance(this).dismissIncomingNotification()
        setCallStatus("accepting")

        // Accept via HTTP API so the caller is notified immediately
        if (callId != 0) acceptCallViaApi(callId)

        // Notify Flutter if running
        AmigoCallPlugin.sendEvent("onCallAccepted", mapOf("callId" to callId))

        // Launch MainActivity so Flutter starts and reads "accepting" status
        launchMainActivity()
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        pulseAnimator?.cancel()
        try {
            unregisterReceiver(stateReceiver)
        } catch (_: Exception) {
        }
    }

    override fun onBackPressed() {
        // In incoming mode, don't allow back press
        if (callMode == "incoming") return
        // In other modes, minimize to app
        minimizeToApp()
    }

    private fun setupLockScreenFlags() {
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

        // Edge-to-edge: gradient extends behind status bar
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        window.navigationBarColor = android.graphics.Color.parseColor("#0A0A0F")
    }

    private fun applyStatusBarInset() {
        val topBar = findViewById<View>(R.id.topBar)
        val sidePad = dpToPx(20)
        ViewCompat.setOnApplyWindowInsetsListener(topBar) { v, insets ->
            val statusBarTop = insets.getInsets(WindowInsetsCompat.Type.statusBars()).top
            v.setPadding(sidePad, dpToPx(8), sidePad, dpToPx(8))
            val lp = v.layoutParams as? android.view.ViewGroup.MarginLayoutParams
            lp?.topMargin = statusBarTop
            v.layoutParams = lp
            insets
        }
        // Request insets immediately in case the view is already laid out
        ViewCompat.requestApplyInsets(topBar)
    }

    private fun dpToPx(dp: Int): Int = (dp * resources.displayMetrics.density).toInt()

    private fun parseIntent(intent: Intent?) {
        intent?.let {
            callId = it.getIntExtra(EXTRA_CALL_ID, 0)
            callerName = it.getStringExtra(EXTRA_CALLER_NAME) ?: "Unknown"
            callerPhoto = it.getStringExtra(EXTRA_CALLER_PHOTO)
            callMode = it.getStringExtra(EXTRA_CALL_MODE) ?: "incoming"
            isMuted = it.getBooleanExtra(EXTRA_IS_MUTED, false)
            isSpeakerOn = it.getBooleanExtra(EXTRA_IS_SPEAKER_ON, false)
        }
    }

    private fun bindViews() {
        btnMinimize = findViewById(R.id.btnMinimize)
        statusBadge = findViewById(R.id.statusBadge)
        callTypeLabel = findViewById(R.id.callTypeLabel)
        avatar = findViewById(R.id.avatar)
        avatarPlaceholder = findViewById(R.id.avatarPlaceholder)
        avatarInitial = findViewById(R.id.avatarInitial)
        callerNameView = findViewById(R.id.callerName)
        callStatusText = findViewById(R.id.callStatusText)
        durationTimer = findViewById(R.id.durationTimer)
        controlsRow = findViewById(R.id.controlsRow)
        incomingActions = findViewById(R.id.incomingActions)
        endCallContainer = findViewById(R.id.endCallContainer)
        btnMute = findViewById(R.id.btnMute)
        btnSpeaker = findViewById(R.id.btnSpeaker)
        btnEndCallRow = findViewById(R.id.btnEndCallRow)
        btnDecline = findViewById(R.id.btnDecline)
        btnAccept = findViewById(R.id.btnAccept)
        btnEndCall = findViewById(R.id.btnEndCall)
        iconMute = findViewById(R.id.iconMute)
        iconSpeaker = findViewById(R.id.iconSpeaker)
        labelMute = findViewById(R.id.labelMute)
        labelSpeaker = findViewById(R.id.labelSpeaker)
        endCallLabel = findViewById(R.id.endCallLabel)
        pulseRing1 = findViewById(R.id.pulseRing1)
        pulseRing2 = findViewById(R.id.pulseRing2)

        // Set caller name
        callerNameView.text = callerName

        // Set avatar initial
        val initial = if (callerName.isNotEmpty()) callerName[0].uppercase() else "?"
        avatarInitial.text = initial

        // Make avatar circular
        avatar.clipToOutline = true
        avatar.outlineProvider = CircleOutlineProvider()
        avatarPlaceholder.clipToOutline = true
        avatarPlaceholder.outlineProvider = CircleOutlineProvider()
    }

    private fun setupListeners() {
        btnMinimize.setOnClickListener { minimizeToApp() }

        btnAccept.setOnClickListener {
            animateButtonPress(it) {
                // Perform native actions so this works even without Flutter
                try {
                    CallNotificationForegroundService.stop(this)
                } catch (_: Exception) {
                }
                CallNotificationManager.getInstance(this).dismissIncomingNotification()
                setCallStatus("accepting")

                // Accept via HTTP API so the caller is notified immediately
                if (callId != 0) acceptCallViaApi(callId)

                // Switch to in_call mode
                callMode = "in_call"
                updateUI()

                // Notify Flutter if running
                AmigoCallPlugin.sendEvent("onCallAccepted", mapOf("callId" to callId))

                // Launch MainActivity so Flutter starts and reads "accepting" status
                launchMainActivity()
            }
        }

        btnDecline.setOnClickListener {
            animateButtonPress(it) {
                // Perform native actions
                try {
                    CallNotificationForegroundService.stop(this)
                } catch (_: Exception) {
                }
                CallNotificationManager.getInstance(this).dismissAllNotifications()

                // Notify Flutter if running
                AmigoCallPlugin.sendEvent("onCallDeclined", mapOf("callId" to callId))

                // Decline via HTTP API so caller is notified even without Flutter
                if (callId != 0) declineCallViaApi(callId)

                clearCallDetails()
                finishWithAnimation()
            }
        }

        btnEndCall.setOnClickListener {
            animateButtonPress(it) {
                // Perform native actions
                try {
                    CallNotificationForegroundService.stop(this)
                } catch (_: Exception) {
                }
                CallNotificationManager.getInstance(this).dismissAllNotifications()
                clearCallDetails()

                // Notify Flutter if running
                AmigoCallPlugin.sendEvent("onCallEnded", mapOf("callId" to callId))

                finishWithAnimation()
            }
        }

        btnMute.setOnClickListener {
            isMuted = !isMuted
            updateToggleStates()
            AmigoCallPlugin.sendEvent("onMuteToggled", mapOf("isMuted" to isMuted))
        }

        btnSpeaker.setOnClickListener {
            isSpeakerOn = !isSpeakerOn
            updateToggleStates()
            AmigoCallPlugin.sendEvent("onSpeakerToggled", mapOf("isSpeakerOn" to isSpeakerOn))
        }

        btnEndCallRow.setOnClickListener {
            animateButtonPress(it) {
                try {
                    CallNotificationForegroundService.stop(this)
                } catch (_: Exception) {
                }
                CallNotificationManager.getInstance(this).dismissAllNotifications()
                clearCallDetails()
                AmigoCallPlugin.sendEvent("onCallEnded", mapOf("callId" to callId))
                finishWithAnimation()
            }
        }
    }

    private fun updateUI() {
        callerNameView.text = callerName

        when (callMode) {
            "incoming" -> showIncomingMode()
            "outgoing" -> showOutgoingMode()
            "connecting" -> showConnectingMode()
            "in_call" -> showInCallMode()
        }

        updateToggleStates()
    }

    private fun showIncomingMode() {
        callTypeLabel.text = "Incoming Voice Call"
        callStatusText.text = "Audio Call"
        callStatusText.visibility = View.VISIBLE
        durationTimer.visibility = View.GONE

        btnMinimize.visibility = View.GONE
        statusBadge.visibility = View.GONE
        controlsRow.visibility = View.GONE
        incomingActions.visibility = View.VISIBLE
        endCallContainer.visibility = View.GONE

        startPulseAnimation()
    }

    private fun showOutgoingMode() {
        callTypeLabel.text = "Outgoing Call"
        callStatusText.text = "Calling..."
        callStatusText.visibility = View.VISIBLE
        durationTimer.visibility = View.GONE

        btnMinimize.visibility = View.VISIBLE
        statusBadge.text = "  Calling  "
        statusBadge.visibility = View.VISIBLE
        controlsRow.visibility = View.GONE
        incomingActions.visibility = View.GONE
        endCallContainer.visibility = View.VISIBLE
        endCallLabel.text = "Cancel"

        startPulseAnimation()
    }

    private fun showConnectingMode() {
        callTypeLabel.text = "Audio Call"
        callStatusText.text = "Configuring call..."
        callStatusText.visibility = View.VISIBLE
        durationTimer.visibility = View.GONE

        btnMinimize.visibility = View.VISIBLE
        statusBadge.text = "  Connecting  "
        statusBadge.visibility = View.VISIBLE
        controlsRow.visibility = View.GONE
        incomingActions.visibility = View.GONE
        endCallContainer.visibility = View.VISIBLE
        endCallLabel.text = "End Call"

        stopPulseAnimation()
    }

    private fun showInCallMode() {
        callTypeLabel.text = "Audio Call"
        callStatusText.visibility = View.GONE

        // Show and start timer
        durationTimer.visibility = View.VISIBLE
        if (timerBase == 0L) {
            timerBase = SystemClock.elapsedRealtime()
        }
        durationTimer.base = timerBase
        durationTimer.start()

        btnMinimize.visibility = View.VISIBLE
        statusBadge.text = "  Connected  "
        statusBadge.visibility = View.VISIBLE
        controlsRow.visibility = View.VISIBLE
        incomingActions.visibility = View.GONE
        endCallContainer.visibility = View.GONE

        stopPulseAnimation()

        // Animate controls appearing
        controlsRow.alpha = 0f
        controlsRow.translationY = 30f
        controlsRow.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(400)
            .setInterpolator(OvershootInterpolator(1.2f))
            .start()
    }

    private fun updateToggleStates() {
        // Mute
        iconMute.setImageResource(if (isMuted) R.drawable.ic_mic_off else R.drawable.ic_mic)
        btnMute.setBackgroundResource(if (isMuted) R.drawable.bg_button_circle_active else R.drawable.bg_button_circle)
        labelMute.text = if (isMuted) "Unmute" else "Mute"

        // Speaker
        iconSpeaker.setImageResource(if (isSpeakerOn) R.drawable.ic_volume_up else R.drawable.ic_volume_off)
        btnSpeaker.setBackgroundResource(if (isSpeakerOn) R.drawable.bg_button_circle_active else R.drawable.bg_button_circle)
        labelSpeaker.text = if (isSpeakerOn) "Speaker" else "Speaker"
    }

    private fun updateDuration(durationSeconds: Long) {
        if (callMode == "in_call" && durationTimer.visibility == View.VISIBLE) {
            timerBase = SystemClock.elapsedRealtime() - (durationSeconds * 1000)
            durationTimer.base = timerBase
        }
    }

    private fun loadAvatar() {
        val photoUrl = callerPhoto
        if (photoUrl.isNullOrEmpty()) {
            avatar.visibility = View.GONE
            avatarPlaceholder.visibility = View.VISIBLE
            val initial = if (callerName.isNotEmpty()) callerName[0].uppercase() else "?"
            avatarInitial.text = initial
            return
        }

        avatar.visibility = View.VISIBLE
        avatarPlaceholder.visibility = View.GONE

        // Load avatar asynchronously
        thread {
            try {
                val url = URL(photoUrl)
                val connection = url.openConnection() as HttpURLConnection
                connection.doInput = true
                connection.connectTimeout = 5000
                connection.readTimeout = 5000
                connection.connect()
                val input = connection.inputStream
                val bitmap = BitmapFactory.decodeStream(input)
                input.close()

                if (bitmap != null) {
                    val circularBitmap = getCircularBitmap(bitmap)
                    runOnUiThread {
                        if (!isDestroyed) {
                            avatar.setImageBitmap(circularBitmap)
                        }
                    }
                } else {
                    showPlaceholder()
                }
            } catch (e: Exception) {
                showPlaceholder()
            }
        }
    }

    private fun showPlaceholder() {
        runOnUiThread {
            if (!isDestroyed) {
                avatar.visibility = View.GONE
                avatarPlaceholder.visibility = View.VISIBLE
            }
        }
    }

    private fun getCircularBitmap(bitmap: Bitmap): Bitmap {
        val size = minOf(bitmap.width, bitmap.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint().apply {
            isAntiAlias = true
            shader = BitmapShader(
                Bitmap.createScaledBitmap(bitmap, size, size, true),
                Shader.TileMode.CLAMP,
                Shader.TileMode.CLAMP
            )
        }
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        return output
    }

    // ---- Animations ----

    private fun playEntranceAnimation() {
        val content = findViewById<View>(android.R.id.content)
        content.alpha = 0f
        content.animate()
            .alpha(1f)
            .setDuration(300)
            .start()

        // Avatar scale-in
        val avatarContainer = findViewById<FrameLayout>(R.id.avatarContainer)
        avatarContainer.scaleX = 0.6f
        avatarContainer.scaleY = 0.6f
        avatarContainer.alpha = 0f
        avatarContainer.animate()
            .scaleX(1f)
            .scaleY(1f)
            .alpha(1f)
            .setDuration(500)
            .setInterpolator(OvershootInterpolator(1.5f))
            .setStartDelay(150)
            .start()

        // Name fade in
        callerNameView.alpha = 0f
        callerNameView.translationY = 20f
        callerNameView.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(400)
            .setStartDelay(300)
            .start()

        // Buttons slide up
        val buttonsDelay = 400L
        listOf(incomingActions, endCallContainer).forEach { view ->
            view.alpha = 0f
            view.translationY = 60f
            view.animate()
                .alpha(1f)
                .translationY(0f)
                .setDuration(500)
                .setInterpolator(OvershootInterpolator(1.0f))
                .setStartDelay(buttonsDelay)
                .start()
        }
    }

    private fun startPulseAnimation() {
        pulseAnimator?.cancel()

        val ring1Scale = ObjectAnimator.ofFloat(pulseRing1, View.SCALE_X, 0.75f, 1.15f).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            interpolator = AccelerateDecelerateInterpolator()
        }
        val ring1ScaleY = ObjectAnimator.ofFloat(pulseRing1, View.SCALE_Y, 0.75f, 1.15f).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            interpolator = AccelerateDecelerateInterpolator()
        }
        val ring1Alpha = ObjectAnimator.ofFloat(pulseRing1, View.ALPHA, 0.6f, 0f).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
        }

        val ring2Scale = ObjectAnimator.ofFloat(pulseRing2, View.SCALE_X, 0.75f, 1.15f).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            interpolator = AccelerateDecelerateInterpolator()
            startDelay = 800
        }
        val ring2ScaleY = ObjectAnimator.ofFloat(pulseRing2, View.SCALE_Y, 0.75f, 1.15f).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            interpolator = AccelerateDecelerateInterpolator()
            startDelay = 800
        }
        val ring2Alpha = ObjectAnimator.ofFloat(pulseRing2, View.ALPHA, 0.4f, 0f).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            startDelay = 800
        }

        pulseAnimator = AnimatorSet().apply {
            playTogether(ring1Scale, ring1ScaleY, ring1Alpha, ring2Scale, ring2ScaleY, ring2Alpha)
            start()
        }
    }

    private fun stopPulseAnimation() {
        pulseAnimator?.cancel()
        pulseRing1.alpha = 0f
        pulseRing2.alpha = 0f
    }

    private fun animateButtonPress(view: View, action: () -> Unit) {
        view.animate()
            .scaleX(0.85f)
            .scaleY(0.85f)
            .setDuration(100)
            .withEndAction {
                view.animate()
                    .scaleX(1f)
                    .scaleY(1f)
                    .setDuration(150)
                    .setInterpolator(OvershootInterpolator(2f))
                    .withEndAction { action() }
                    .start()
            }
            .start()
    }

    private fun finishWithAnimation() {
        val content = findViewById<View>(android.R.id.content)
        content.animate()
            .alpha(0f)
            .setDuration(250)
            .withEndAction { finish() }
            .start()
        overridePendingTransition(0, 0)
    }

    private fun minimizeToApp() {
        // Launch the main Flutter activity
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        launchIntent?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            startActivity(it)
        }
        // Don't finish - keep the activity in the back stack
    }

    private fun setCallStatus(status: String) {
        try {
            val prefs = getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            val existing = prefs.getString(CALL_DETAILS_KEY, null)
            val json = if (existing != null) {
                try {
                    JSONObject(existing).put("call_status", status)
                } catch (_: Exception) {
                    JSONObject().put("call_id", callId).put("call_status", status)
                }
            } else {
                JSONObject().put("call_id", callId).put("call_status", status)
            }
            prefs.edit().putString(CALL_DETAILS_KEY, json.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error setting call status: ${e.message}")
        }
    }

    private fun clearCallDetails() {
        try {
            val prefs = getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            prefs.edit().remove(CALL_DETAILS_KEY).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing call details: ${e.message}")
        }
    }

    private fun acceptCallViaApi(callId: Int) {
        val baseUrl = try {
            val prefs = getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            prefs.getString("flutter.api_base_url", null)
        } catch (_: Exception) {
            null
        }
        logToFile("acceptCallViaApi: baseUrl=$baseUrl callId=$callId")
        if (baseUrl == null) return

        thread {
            try {
                val urlStr = "$baseUrl/call/accept/$callId"
                logToFile("acceptCallViaApi: connecting to $urlStr")
                val conn = URL(urlStr).openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.connectTimeout = 5000
                conn.readTimeout = 5000
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.outputStream.use { it.write("{}".toByteArray()) }
                val code = conn.responseCode
                val body = try {
                    conn.inputStream.bufferedReader().readText()
                } catch (_: Exception) {
                    try {
                        conn.errorStream?.bufferedReader()?.readText()
                    } catch (_: Exception) {
                        "<no body>"
                    }
                }
                logToFile("acceptCallViaApi: response code=$code body=$body")
                Log.d(TAG, "Accept API response: $code for callId=$callId")
                conn.disconnect()
            } catch (e: Exception) {
                logToFile("acceptCallViaApi: EXCEPTION ${e.javaClass.simpleName}: ${e.message}")
                Log.e(TAG, "Error accepting call via API: ${e.message}")
            }
        }
    }

    private fun declineCallViaApi(callId: Int) {
        val baseUrl = try {
            val prefs = getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
            prefs.getString("flutter.api_base_url", null)
        } catch (_: Exception) {
            null
        }
        logToFile("declineCallViaApi: baseUrl=$baseUrl callId=$callId")
        if (baseUrl == null) return

        thread {
            try {
                val urlStr = "$baseUrl/call/decline/$callId"
                logToFile("declineCallViaApi: connecting to $urlStr")
                val conn = URL(urlStr).openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.connectTimeout = 5000
                conn.readTimeout = 5000
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.outputStream.use { it.write("{}".toByteArray()) }
                val code = conn.responseCode
                val body = try {
                    conn.inputStream.bufferedReader().readText()
                } catch (_: Exception) {
                    try {
                        conn.errorStream?.bufferedReader()?.readText()
                    } catch (_: Exception) {
                        "<no body>"
                    }
                }
                logToFile("declineCallViaApi: response code=$code body=$body")
                Log.d(TAG, "Decline API response: $code for callId=$callId")
                conn.disconnect()
            } catch (e: Exception) {
                logToFile("declineCallViaApi: EXCEPTION ${e.javaClass.simpleName}: ${e.message}")
                Log.e(TAG, "Error declining call via API: ${e.message}")
            }
        }
    }

    private fun launchMainActivity() {
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            }
            launchIntent?.let { startActivity(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Error launching main activity: ${e.message}")
        }
    }

    private fun logToFile(message: String) {
        try {
            val ts = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date())
            val line = "[$ts] $message\n"
            Log.d(TAG, message)
            val dir = getExternalFilesDir(null) ?: filesDir
            val file = File(dir, "call_debug.log")
            file.appendText(line)
        } catch (_: Exception) {
        }
    }

    // Custom outline provider for circular clipping
    private class CircleOutlineProvider : android.view.ViewOutlineProvider() {
        override fun getOutline(view: View, outline: android.graphics.Outline) {
            outline.setOval(0, 0, view.width, view.height)
        }
    }
}
