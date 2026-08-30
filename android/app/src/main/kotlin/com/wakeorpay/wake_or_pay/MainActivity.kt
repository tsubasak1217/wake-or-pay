package com.wakeorpay.wake_or_pay

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the `wake_or_pay/snooze` method channel (spec 12.1):
 *
 *  - Dart → native: start / update / stop the [SnoozeService], and read the
 *    session id of a cold-launch by 解除 (`consumeLaunchDismiss`).
 *  - native → Dart: `onDismiss`, when 解除 is tapped while the app is alive
 *    (singleTask means that arrives here as [onNewIntent]).
 */
/**
 * FlutterFragmentActivity, not FlutterActivity: Stripe's PaymentSheet
 * (カード人質, docs/BILLING_API.md) is an AndroidX fragment and needs a
 * FragmentManager to be shown in. Nothing else about this activity changes.
 */
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null

    /** A cold-launch 解除 session id, held until Dart asks for it. */
    private var pendingDismiss: String? = null

    /**
     * Wakes the screen and puts this activity **over** the lock screen.
     *
     * This is the whole point of the app: the alarm plugin rings by starting a
     * foreground service and firing a full-screen intent at this activity
     * (`getLaunchIntentForPackage`). Without these two flags the intent lands
     * on an activity the keyguard is entitled to keep behind it, and on a
     * sleeping phone the alarm sounds with the screen still dark — exactly the
     * bug reported against build 106.
     *
     * **Set here in code and *not* in the manifest, on purpose.** The manifest
     * attributes (`android:showWhenLocked` / `android:turnScreenOn`) are the
     * alarm package's documented setup (its help/INSTALL-ANDROID.md), but they
     * are static: declared there, the activity shows over the keyguard for
     * ever, so putting the phone to sleep with the app open and pressing power
     * again brings up the alarm list instead of the lock screen. Here it is a
     * switch instead — raised for the cold launch, and lowered again by Dart
     * over `wake_or_pay/lock_screen` as soon as the first frame finds that
     * nothing is ringing.
     *
     * [onCreate] still raises it because a full-screen intent launch needs the
     * flags *before* the first frame, and Dart is not running yet to ask.
     *
     * Note what this does *not* do: it never dismisses the keyguard. The
     * ringing screen shows on top of the lock screen; the phone stays locked
     * and nothing behind the ring screen is reachable without unlocking.
     */
    private fun showOverLockScreen() = setShowOverLockScreen(true)

    /**
     * [showOverLockScreen]'s switch, both ways. Idempotent, and safe to call
     * from the method channel at any point in the activity's life.
     */
    private fun setShowOverLockScreen(show: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(show)
            setTurnScreenOn(show)
        } else {
            // minSdk is 26, one below the API that replaced these.
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            @Suppress("DEPRECATION")
            if (show) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreen()
    }

    /**
     * Whether Android will actually let a full-screen intent take over the
     * screen — the permission that decides whether the alarm can wake anybody.
     *
     * Since Android 14 `USE_FULL_SCREEN_INTENT` is **not** granted on install
     * to an app the store has not classified as a clock or a calling app, and
     * a sideloaded build is never classified. Declaring it in the manifest is
     * not enough. When it is denied the system silently strips the intent off
     * the notification: the alarm still sounds, and the screen never comes on.
     * Below 34 the permission is granted at install and this is always true.
     */
    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.canUseFullScreenIntent()
    }

    /** Opens the single system toggle that grants the permission above. */
    private fun openFullScreenIntentSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                Uri.parse("package:$packageName"),
            )
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wake_or_pay/snooze")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val i = Intent(this, SnoozeService::class.java).apply {
                        action = SnoozeService.ACTION_START
                        putExtra(SnoozeService.EXTRA_SESSION, call.argument<String>("sessionId"))
                        putExtra(SnoozeService.EXTRA_TITLE, call.argument<String>("title"))
                        putExtra(SnoozeService.EXTRA_BODY, call.argument<String>("body"))
                    }
                    ContextCompat.startForegroundService(this, i)
                    result.success(null)
                }
                "update" -> {
                    val i = Intent(this, SnoozeService::class.java).apply {
                        action = SnoozeService.ACTION_UPDATE
                        putExtra(SnoozeService.EXTRA_BODY, call.argument<String>("body"))
                    }
                    ContextCompat.startForegroundService(this, i)
                    result.success(null)
                }
                "stop" -> {
                    val i = Intent(this, SnoozeService::class.java).apply {
                        action = SnoozeService.ACTION_STOP
                    }
                    startService(i)
                    result.success(null)
                }
                "consumeLaunchDismiss" -> {
                    result.success(pendingDismiss)
                    pendingDismiss = null
                }
                else -> result.notImplemented()
            }
        }
        // The intent that launched this engine may itself be the 解除 tap.
        intent?.getStringExtra(SnoozeService.EXTRA_SESSION)?.let { pendingDismiss = it }

        // Its own channel, not the snooze one: this is about whether the ring
        // can reach the screen at all, which is upstream of every feature.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wake_or_pay/full_screen_intent")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isGranted" -> result.success(canUseFullScreenIntent())
                    "openSettings" -> {
                        openFullScreenIntentSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Whether the app may draw over the keyguard — raised while an alarm
        // is ringing, and lowered the moment it is not. See
        // [showOverLockScreen] for why this is a switch and not a manifest
        // attribute. Window work, so it runs on the main thread.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wake_or_pay/lock_screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setShowWhenLocked" -> {
                        val show = call.argument<Boolean>("show") ?: false
                        runOnUiThread { setShowOverLockScreen(show) }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val sid = intent.getStringExtra(SnoozeService.EXTRA_SESSION) ?: return
        // The engine is up, so deliver straight away; fall back to the pending
        // slot only if the channel is somehow not wired yet.
        val ch = channel
        if (ch != null) {
            ch.invokeMethod("onDismiss", sid)
        } else {
            pendingDismiss = sid
        }
    }
}
