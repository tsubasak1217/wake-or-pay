package com.wakeorpay.platform

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Everything Wake or Pay needs from Android that no pub package gives it:
 * sending an SMS, and placing a call with the speaker on.
 *
 * Registered as a real Flutter plugin rather than wired up in MainActivity so
 * that it also exists on the engine `android_alarm_manager_plus` starts for
 * the background isolate — spec 11.7 fires an SMS from there, and a channel
 * attached only to the UI engine would simply not answer.
 *
 * The **call** is a different matter: `ACTION_CALL` needs an Activity, so the
 * Dart side never takes that route from the background. The handler is
 * registered on both engines all the same; refusing at one clear place beats
 * a channel that is missing on one engine and present on the other.
 */
class WopPlatformPlugin : FlutterPlugin {
  private var smsChannel: MethodChannel? = null
  private var phoneChannel: MethodChannel? = null
  private var phoneStateChannel: EventChannel? = null
  private var phone: PhoneHandler? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    val context: Context = binding.applicationContext

    smsChannel = MethodChannel(binding.binaryMessenger, SmsHandler.CHANNEL).also {
      it.setMethodCallHandler(SmsHandler(context))
    }

    val handler = PhoneHandler(context)
    phone = handler
    phoneChannel = MethodChannel(binding.binaryMessenger, PhoneHandler.CHANNEL).also {
      it.setMethodCallHandler(handler)
    }
    phoneStateChannel =
      EventChannel(binding.binaryMessenger, PhoneHandler.STATE_CHANNEL).also {
        it.setStreamHandler(handler)
      }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    smsChannel?.setMethodCallHandler(null)
    smsChannel = null
    phoneChannel?.setMethodCallHandler(null)
    phoneChannel = null
    phoneStateChannel?.setStreamHandler(null)
    phoneStateChannel = null
    // Unregisters the call-state watcher: leaking one would keep a callback
    // alive against a dead engine for the rest of the process.
    phone?.dispose()
    phone = null
  }
}
