package com.wakeorpay.platform

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Placing a call from the user's own number and putting it on the speaker,
 * per spec 11.5.
 *
 * **Nothing is played into the call.** The whole point is that the contact's
 * own voice comes out of the sleeper's phone; an automated message would just
 * be the app talking to itself.
 *
 * `ACTION_CALL` rather than `ACTION_DIAL`: dialling would open the dialer and
 * wait for a tap from somebody who is asleep. It needs `CALL_PHONE`, and it
 * can only be started with an Activity in the foreground — which is why spec
 * 11.7's background isolate never takes this route.
 *
 * The speakerphone is **best effort** throughout. There is no API that
 * promises it, the audio route is decided by the telephony stack, and every
 * failure here is logged and swallowed: a call that rings on the earpiece is
 * still a call that woke somebody.
 */
class PhoneHandler(private val context: Context) :
  MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

  companion object {
    const val CHANNEL = "com.wakeorpay.platform/phone"
    const val STATE_CHANNEL = "com.wakeorpay.platform/phone/state"
    private const val TAG = "WopPhone"

    /** How often to try the speaker, and for how long. */
    private const val SPEAKER_RETRY_MS = 500L
    private const val SPEAKER_ATTEMPTS = 20
  }

  private val main = Handler(Looper.getMainLooper())
  private var events: EventChannel.EventSink? = null

  private var listening = false
  private var offHook = false
  private var callback: TelephonyCallback? = null
  private var legacyListener: PhoneStateListener? = null

  // ---------------------------------------------------------------- method

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "call" -> place(call, result)
      else -> result.notImplemented()
    }
  }

  private fun place(call: MethodCall, result: MethodChannel.Result) {
    val to = call.argument<String>("to")?.trim().orEmpty()
    if (to.isEmpty()) {
      result.error("invalid", "empty number", null)
      return
    }
    if (context.checkSelfPermission(Manifest.permission.CALL_PHONE)
      != PackageManager.PERMISSION_GRANTED
    ) {
      result.error("permission", "CALL_PHONE is not granted", null)
      return
    }
    val telephony = context.getSystemService(TelephonyManager::class.java)
    if (telephony == null ||
      telephony.phoneType == TelephonyManager.PHONE_TYPE_NONE
    ) {
      result.error("unavailable", "no telephony on this device", null)
      return
    }

    // fromParts, not parse: a number is not a URL and must not be escaped as
    // one — a `#` in it would otherwise become a fragment and be dropped.
    val intent = Intent(Intent.ACTION_CALL, Uri.fromParts("tel", to, null))
      .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    try {
      context.startActivity(intent)
    } catch (e: Throwable) {
      Log.w(TAG, "ACTION_CALL failed", e)
      result.error("failed", e.message ?: e.javaClass.simpleName, null)
      return
    }

    startWatching()
    // Straight away as well as on OFFHOOK: on some builds the audio mode is
    // already IN_CALL before the state callback arrives.
    scheduleSpeakerphone(0)
    result.success(null)
  }

  // ------------------------------------------------------------ speaker

  private fun scheduleSpeakerphone(attempt: Int) {
    if (attempt >= SPEAKER_ATTEMPTS) return
    main.postDelayed({
      val done = try {
        enableSpeakerphone()
      } catch (e: Throwable) {
        Log.w(TAG, "speakerphone attempt $attempt failed", e)
        false
      }
      if (!done) scheduleSpeakerphone(attempt + 1)
    }, SPEAKER_RETRY_MS)
  }

  /** True once the speaker is actually on; false means "try again later". */
  private fun enableSpeakerphone(): Boolean {
    val audio = context.getSystemService(AudioManager::class.java) ?: return false
    // Before the call connects there is no communication route to move, and
    // setting the flag then is silently undone when it does.
    if (audio.mode != AudioManager.MODE_IN_CALL &&
      audio.mode != AudioManager.MODE_IN_COMMUNICATION
    ) {
      return false
    }
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val speaker = audio.availableCommunicationDevices
        .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
      speaker != null && audio.setCommunicationDevice(speaker)
    } else {
      @Suppress("DEPRECATION")
      run {
        audio.isSpeakerphoneOn = true
        audio.isSpeakerphoneOn
      }
    }
  }

  private fun releaseSpeakerphone() {
    val audio = context.getSystemService(AudioManager::class.java) ?: return
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        audio.clearCommunicationDevice()
      } else {
        @Suppress("DEPRECATION")
        run { audio.isSpeakerphoneOn = false }
      }
    } catch (e: Throwable) {
      Log.w(TAG, "could not put the speaker back", e)
    }
  }

  // -------------------------------------------------------- call state

  /**
   * Watches for the call going off hook and back to idle.
   *
   * The Dart side turns the alarm sound off while this is true and back on
   * when it goes false, per spec 11.5 — the sleeper cannot hear whoever picks
   * up over their own alarm.
   *
   * Needs `READ_PHONE_STATE`, which is asked for beside `CALL_PHONE`. Without
   * it this simply never registers: the call still goes out, the alarm keeps
   * ringing, and a line in the log says why.
   */
  private fun startWatching() {
    if (listening) return
    val telephony = context.getSystemService(TelephonyManager::class.java) ?: return
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
          override fun onCallStateChanged(state: Int) = handleState(state)
        }
        callback = cb
        telephony.registerTelephonyCallback(context.mainExecutor, cb)
      } else {
        @Suppress("DEPRECATION")
        val listener = object : PhoneStateListener() {
          @Deprecated("Replaced by TelephonyCallback on API 31+")
          override fun onCallStateChanged(state: Int, phoneNumber: String?) =
            handleState(state)
        }
        legacyListener = listener
        @Suppress("DEPRECATION")
        telephony.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
      }
      listening = true
    } catch (e: Throwable) {
      // A SecurityException here means READ_PHONE_STATE was refused. The call
      // is already placed; all that is lost is pausing the alarm.
      Log.w(TAG, "cannot watch the call state", e)
    }
  }

  private fun stopWatching() {
    val telephony = context.getSystemService(TelephonyManager::class.java)
    try {
      val cb = callback
      val listener = legacyListener
      if (cb != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        telephony?.unregisterTelephonyCallback(cb)
      } else if (listener != null) {
        @Suppress("DEPRECATION")
        telephony?.listen(listener, PhoneStateListener.LISTEN_NONE)
      }
    } catch (e: Throwable) {
      Log.w(TAG, "could not unregister the call state watcher", e)
    }
    callback = null
    legacyListener = null
    listening = false
  }

  private fun handleState(state: Int) {
    when (state) {
      TelephonyManager.CALL_STATE_OFFHOOK -> {
        if (offHook) return
        offHook = true
        emit(true)
        // The moment that actually matters: the audio mode is IN_CALL now.
        scheduleSpeakerphone(0)
      }
      TelephonyManager.CALL_STATE_IDLE -> {
        if (!offHook) return
        offHook = false
        releaseSpeakerphone()
        emit(false)
        stopWatching()
      }
    }
  }

  // ----------------------------------------------------------- events

  private fun emit(inCall: Boolean) = main.post {
    try {
      events?.success(inCall)
    } catch (e: Throwable) {
      Log.w(TAG, "could not report the call state", e)
    }
  }

  override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
    events = sink
    // Whoever just attached needs to know where things stand, not only what
    // changes next: the ring screen is rebuilt often.
    emit(offHook)
  }

  override fun onCancel(arguments: Any?) {
    events = null
  }

  fun dispose() {
    stopWatching()
    events = null
  }
}
