package com.wakeorpay.wake_or_pay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * The スヌーズ中 foreground service — spec 12.1 (revised).
 *
 * It owns a single ongoing, high-importance notification for the whole snooze,
 * carrying the 解除 action. Tapping the body or the action launches
 * [MainActivity] with the session id; Dart settles it.
 *
 * The reliability the plain notification lacked comes from an **in-process**
 * receiver for `ACTION_USER_PRESENT` / `ACTION_SCREEN_ON`: a manifest-declared
 * USER_PRESENT receiver no longer fires on Android 8+, but one registered from
 * a running service does. On unlock it re-raises the notification so it can
 * surface as heads-up (OEM-dependent; the ongoing notification itself is the
 * guarantee, the heads-up is the enhancement).
 *
 * No money logic lives here: the body text — including the running loss — is
 * computed in Dart and pushed in via [ACTION_UPDATE].
 */
class SnoozeService : Service() {
    companion object {
        const val CHANNEL_ID = "wake_or_pay_snooze"
        const val NOTIF_ID = 4711
        const val ACTION_START = "com.wakeorpay.snooze.START"
        const val ACTION_UPDATE = "com.wakeorpay.snooze.UPDATE"
        const val ACTION_STOP = "com.wakeorpay.snooze.STOP"
        const val EXTRA_SESSION = "sessionId"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
    }

    private var sessionId: String? = null
    private var title: String = "スヌーズ中"
    private var body: String = ""
    private var receiver: BroadcastReceiver? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                // Only when the phone is actually interactive: a heads-up on a
                // dark screen is nothing, and USER_PRESENT is the unlock we want.
                if (!pm.isInteractive) return
                reraise()
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        registerReceiver(r, filter)
        receiver = r
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelfCompat()
                return START_NOT_STICKY
            }
            else -> {
                intent?.getStringExtra(EXTRA_SESSION)?.let { sessionId = it }
                intent?.getStringExtra(EXTRA_TITLE)?.let { title = it }
                intent?.getStringExtra(EXTRA_BODY)?.let { body = it }
                startForegroundCompat()
            }
        }
        return START_STICKY
    }

    /** Re-post so the ongoing note can surface as heads-up on unlock. */
    private fun reraise() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, build())
    }

    private fun launchPendingIntent(): PendingIntent {
        val i = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_SESSION, sessionId)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(this, 0, i, flags)
    }

    private fun build(): Notification {
        val pi = launchPendingIntent()
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setOngoing(true)
            .setOnlyAlertOnce(false)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setContentIntent(pi)
            .addAction(R.drawable.ic_stat_notify, "解除", pi)
            .build()
    }

    private fun startForegroundCompat() {
        val n = build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    private fun stopSelfCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "スヌーズ中",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "スヌーズ中の再鳴動と早期解除"
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    override fun onDestroy() {
        receiver?.let { r -> runCatching { unregisterReceiver(r) } }
        receiver = null
        super.onDestroy()
    }
}
