package com.aiexch.amigo.call

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Foreground service that wraps the call notification to make it non-dismissible on Android 14+.
 * FLAG_ONGOING_EVENT alone is not enough on Android 14+ without a foreground service.
 */
class CallNotificationForegroundService : Service() {

    companion object {
        private const val TAG = "CallNotifFgService"
        const val ACTION_INCOMING = "incoming"
        const val ACTION_ONGOING = "ongoing"
        const val ACTION_STOP = "stop"
        private const val NOTIFICATION_ID = CallNotificationManager.NOTIFICATION_INCOMING_ID

        fun start(context: Context, action: String, callId: Int = 0, name: String = "", photo: String? = null, phone: String? = null) {
            val intent = Intent(context, CallNotificationForegroundService::class.java).apply {
                this.action = action
                putExtra("callId", callId)
                putExtra("name", name)
                putExtra("photo", photo)
                putExtra("phone", phone)
            }
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, CallNotificationForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_STOP
        Log.d(TAG, "onStartCommand: action=$action")

        val notifManager = CallNotificationManager.getInstance(this)

        when (action) {
            ACTION_INCOMING -> {
                val callId = intent?.getIntExtra("callId", 0) ?: 0
                val name = intent?.getStringExtra("name") ?: "Unknown"
                val photo = intent?.getStringExtra("photo")
                val phone = intent?.getStringExtra("phone")
                val notification = notifManager.buildIncomingCallNotification(callId, name, photo, phone)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            }
            ACTION_ONGOING -> {
                val callId = intent?.getIntExtra("callId", 0) ?: 0
                val name = intent?.getStringExtra("name") ?: "Unknown"
                val photo = intent?.getStringExtra("photo")
                val ongoingNotifId = CallNotificationManager.NOTIFICATION_ONGOING_ID
                val notification = notifManager.buildOngoingCallNotification(callId, name, photo)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(ongoingNotifId, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                } else {
                    startForeground(ongoingNotifId, notification)
                }
            }
            ACTION_STOP -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
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
}
