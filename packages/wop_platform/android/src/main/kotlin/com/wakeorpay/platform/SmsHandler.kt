package com.wakeorpay.platform

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Sending one text message from the user's own number, per spec 11.5.
 *
 * `SmsManager` directly rather than an `ACTION_SENDTO` intent: the point of
 * this route is that it goes out while the phone's owner is asleep, and an
 * intent would open the messaging app and wait for a tap that is not coming.
 *
 * Long messages are split with `divideMessage` and sent as a multipart, which
 * is what a custom Japanese message needs — the single-part limit is 70
 * characters once the body leaves GSM-7 for UCS-2, and a body cut at 70 is a
 * message that says half of something.
 */
class SmsHandler(private val context: Context) : MethodChannel.MethodCallHandler {
  companion object {
    const val CHANNEL = "com.wakeorpay.platform/sms"
    private const val TAG = "WopSms"
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "send" -> send(call, result)
      else -> result.notImplemented()
    }
  }

  private fun send(call: MethodCall, result: MethodChannel.Result) {
    val to = call.argument<String>("to")?.trim().orEmpty()
    val body = call.argument<String>("body")?.trim().orEmpty()
    if (to.isEmpty() || body.isEmpty()) {
      result.error("invalid", "empty recipient or body", null)
      return
    }
    // Checked here as well as in Dart: the background isolate cannot show a
    // permission dialog, so it has to be able to fail cleanly instead.
    if (context.checkSelfPermission(Manifest.permission.SEND_SMS)
      != PackageManager.PERMISSION_GRANTED
    ) {
      result.error("permission", "SEND_SMS is not granted", null)
      return
    }

    val manager = smsManager()
    if (manager == null) {
      result.error("unavailable", "no SmsManager on this device", null)
      return
    }

    try {
      val parts = manager.divideMessage(body)
      if (parts.size <= 1) {
        manager.sendTextMessage(to, null, body, null, null)
      } else {
        manager.sendMultipartTextMessage(to, null, parts, null, null)
      }
      result.success(null)
    } catch (e: Throwable) {
      // Includes the IllegalArgumentException a malformed number gives, and
      // the SecurityException a revoked permission gives between the check
      // above and the call itself.
      Log.w(TAG, "sendTextMessage failed", e)
      result.error("failed", e.message ?: e.javaClass.simpleName, null)
    }
  }

  /**
   * `SmsManager.getDefault()` is deprecated from API 31 and returns the
   * wrong subscription on a dual-SIM phone; the system service is the
   * replacement. A tablet with no telephony has neither, hence the null.
   */
  private fun smsManager(): SmsManager? = try {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      context.getSystemService(SmsManager::class.java)
    } else {
      @Suppress("DEPRECATION")
      SmsManager.getDefault()
    }
  } catch (e: Throwable) {
    Log.w(TAG, "no SmsManager", e)
    null
  }
}
