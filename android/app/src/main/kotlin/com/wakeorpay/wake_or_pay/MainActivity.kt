package com.wakeorpay.wake_or_pay

import android.content.Intent
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
