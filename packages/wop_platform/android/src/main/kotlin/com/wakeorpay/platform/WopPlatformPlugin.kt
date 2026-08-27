package com.wakeorpay.platform

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/**
 * Everything Wake or Pay needs from Android that no pub package gives it.
 *
 * Registered as a real Flutter plugin rather than wired up in MainActivity so
 * that it also exists on the engine `android_alarm_manager_plus` starts for
 * the background isolate — spec 11.7 fires an SMS from there, and a channel
 * attached only to the UI engine would simply not answer.
 */
class WopPlatformPlugin : FlutterPlugin {
  private var smsChannel: MethodChannel? = null
  private lateinit var sms: SmsHandler

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    val context: Context = binding.applicationContext
    sms = SmsHandler(context)
    smsChannel = MethodChannel(binding.binaryMessenger, SmsHandler.CHANNEL).also {
      it.setMethodCallHandler(sms)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    smsChannel?.setMethodCallHandler(null)
    smsChannel = null
  }
}
