package com.aiexch.amigo.call

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter plugin for native call screen management.
 *
 * MethodChannel (Flutter → Native): com.aiexch.amigo/native_call
 * EventChannel (Native → Flutter): com.aiexch.amigo/native_call_events
 */
class AmigoCallPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    companion object {
        private const val TAG = "AmigoCallPlugin"
        private const val METHOD_CHANNEL = "com.aiexch.amigo/native_call"
        private const val EVENT_CHANNEL = "com.aiexch.amigo/native_call_events"

        private var eventSink: EventChannel.EventSink? = null
        private var applicationContext: Context? = null

        /**
         * Send an event from native to Flutter.
         * Called by CallActivity, CallActionReceiver, etc.
         */
        fun sendEvent(eventName: String, data: Map<String, Any?>) {
            val eventData = HashMap<String, Any?>()
            eventData["event"] = eventName
            eventData.putAll(data)

            Log.d(TAG, "Sending event to Flutter: $eventName, data: $data")

            // Post to main thread to ensure thread safety
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                try {
                    eventSink?.success(eventData)
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending event to Flutter: ${e.message}")
                }
            }
        }
    }

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var activity: Activity? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        applicationContext = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.d(TAG, "EventChannel: Flutter started listening")
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                Log.d(TAG, "EventChannel: Flutter stopped listening")
            }
        })

        Log.d(TAG, "Plugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        context = null
        Log.d(TAG, "Plugin detached from engine")
    }

    // ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: activity?.applicationContext
        if (ctx == null) {
            result.error("NO_CONTEXT", "No application context available", null)
            return
        }

        when (call.method) {
            "showIncomingCall" -> {
                val callId = call.argument<Int>("callId") ?: 0
                val callerName = call.argument<String>("callerName") ?: "Unknown"
                val callerPhoto = call.argument<String>("callerPhoto")
                val callerPhone = call.argument<String>("callerPhone")

                Log.d(TAG, "showIncomingCall: callId=$callId, name=$callerName")

                // Show incoming call notification (for lock screen / background)
                val notifManager = CallNotificationManager.getInstance(ctx)
                notifManager.showIncomingCallNotification(callId, callerName, callerPhoto, callerPhone)

                // Try to start FGS for extra non-dismissibility, but don't crash if it fails
                try {
                    CallNotificationForegroundService.start(ctx, CallNotificationForegroundService.ACTION_INCOMING, callId, callerName, callerPhoto, callerPhone)
                } catch (e: Exception) {
                    Log.w(TAG, "FGS start failed (notification still shown): ${e.message}")
                }

                // Also launch CallActivity directly if possible
                launchCallActivity(ctx, callId, callerName, callerPhoto, callerPhone, "incoming")

                result.success(true)
            }

            "showOutgoingCall" -> {
                val callId = call.argument<Int>("callId") ?: 0
                val calleeName = call.argument<String>("calleeName") ?: "Unknown"
                val calleePhoto = call.argument<String>("calleePhoto")
                val calleePhone = call.argument<String>("calleePhone")

                Log.d(TAG, "showOutgoingCall: callId=$callId, name=$calleeName")

                // Show outgoing call notification
                CallNotificationManager.getInstance(ctx).showOutgoingCallNotification(callId, calleeName)

                launchCallActivity(ctx, callId, calleeName, calleePhoto, calleePhone, "outgoing")

                result.success(true)
            }

            "showCallScreen" -> {
                val callId = call.argument<Int>("callId") ?: 0
                val callerName = call.argument<String>("callerName") ?: "Unknown"
                val callerPhoto = call.argument<String>("callerPhoto")
                val callMode = call.argument<String>("callMode") ?: "in_call"
                val isMuted = call.argument<Boolean>("isMuted") ?: false
                val isSpeakerOn = call.argument<Boolean>("isSpeakerOn") ?: true

                Log.d(TAG, "showCallScreen: callId=$callId, mode=$callMode")

                launchCallActivity(ctx, callId, callerName, callerPhoto, null, callMode, isMuted, isSpeakerOn)

                result.success(true)
            }

            "updateCallState" -> {
                val callMode = call.argument<String>("callMode")
                val isMuted = if (call.hasArgument("isMuted")) call.argument<Boolean>("isMuted") else null
                val isSpeakerOn = if (call.hasArgument("isSpeakerOn")) call.argument<Boolean>("isSpeakerOn") else null
                val duration = if (call.hasArgument("duration")) call.argument<Int>("duration")?.toLong() else null

                Log.d(TAG, "updateCallState: mode=$callMode, muted=$isMuted, speaker=$isSpeakerOn, duration=$duration")

                // Update CallActivity via broadcast
                CallActivity.updateState(ctx, callMode, isMuted, isSpeakerOn, duration)

                result.success(true)
            }

            "showOngoingNotification" -> {
                val callId = call.argument<Int>("callId") ?: 0
                val callerName = call.argument<String>("callerName") ?: "Unknown"
                val callerPhoto = call.argument<String>("callerPhoto")

                Log.d(TAG, "showOngoingNotification: name=$callerName")

                val notifManager = CallNotificationManager.getInstance(ctx)
                notifManager.showOngoingCallNotification(callId, callerName, callerPhoto)

                // Try to switch FGS to ongoing, but don't crash if it fails
                try {
                    CallNotificationForegroundService.start(ctx, CallNotificationForegroundService.ACTION_ONGOING, callId, callerName, callerPhoto)
                } catch (e: Exception) {
                    Log.w(TAG, "FGS ongoing start failed: ${e.message}")
                }

                result.success(true)
            }

            "updateOngoingNotification" -> {
                val callerName = call.argument<String>("callerName") ?: "Unknown"
                val isMuted = call.argument<Boolean>("isMuted") ?: false

                CallNotificationManager.getInstance(ctx).updateOngoingNotification(callerName, isMuted)
                result.success(true)
            }

            "dismissNotification" -> {
                try { CallNotificationForegroundService.stop(ctx) } catch (_: Exception) {}
                CallNotificationManager.getInstance(ctx).dismissAllNotifications()
                result.success(true)
            }

            "dismissIncomingNotification" -> {
                CallNotificationManager.getInstance(ctx).dismissIncomingNotification()
                result.success(true)
            }

            "dismissCallScreen" -> {
                Log.d(TAG, "dismissCallScreen")
                try { CallNotificationForegroundService.stop(ctx) } catch (_: Exception) {}
                CallActivity.dismiss(ctx)
                CallNotificationManager.getInstance(ctx).dismissAllNotifications()
                result.success(true)
            }

            "showMissedCallNotification" -> {
                val callId = call.argument<Int>("callId") ?: 0
                val callerName = call.argument<String>("callerName") ?: "Unknown"
                Log.d(TAG, "showMissedCallNotification: callId=$callId, name=$callerName")
                CallNotificationManager.getInstance(ctx).showMissedCallNotification(callId, callerName)
                result.success(true)
            }

            "isCallScreenActive" -> {
                result.success(CallActivity.isActive())
            }

            else -> result.notImplemented()
        }
    }

    private fun launchCallActivity(
        ctx: Context,
        callId: Int,
        name: String,
        photo: String?,
        phone: String?,
        mode: String,
        isMuted: Boolean = false,
        isSpeakerOn: Boolean = true
    ) {
        val intent = Intent(ctx, CallActivity::class.java).apply {
            putExtra(CallActivity.EXTRA_CALL_ID, callId)
            putExtra(CallActivity.EXTRA_CALLER_NAME, name)
            putExtra(CallActivity.EXTRA_CALLER_PHOTO, photo)
            putExtra(CallActivity.EXTRA_CALLER_PHONE, phone)
            putExtra(CallActivity.EXTRA_CALL_MODE, mode)
            putExtra(CallActivity.EXTRA_IS_MUTED, isMuted)
            putExtra(CallActivity.EXTRA_IS_SPEAKER_ON, isSpeakerOn)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (mode == "incoming") {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            } else {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
        }
        ctx.startActivity(intent)
    }
}
