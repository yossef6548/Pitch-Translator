package com.pitchtranslator.audio

import android.app.Activity
import android.app.Application
import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PitchTranslatorAudioPlugin :
  FlutterPlugin,
  MethodChannel.MethodCallHandler,
  EventChannel.StreamHandler,
  ActivityAware,
  DefaultLifecycleObserver {

  private lateinit var context: Context
  private var methodChannel: MethodChannel? = null
  private var frameChannel: EventChannel? = null
  private var sink: EventChannel.EventSink? = null

  private var activity: Activity? = null
  private var restartOnResume = false

  private lateinit var audioManager: AudioManager
  private val deviceCallback = object : AudioDeviceCallback() {
    override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
      if (engine.isRunning()) {
        engine.stop()
        engine.start()
      }
    }

    override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
      if (engine.isRunning()) {
        engine.stop()
        engine.start()
      }
    }
  }

  private val engine = NativeAaudioEngine { frame ->
    sink?.success(frame)
  }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    methodChannel = MethodChannel(binding.binaryMessenger, "pt/audio/control").also {
      it.setMethodCallHandler(this)
    }
    frameChannel = EventChannel(binding.binaryMessenger, "pt/audio/frames").also {
      it.setStreamHandler(this)
    }

    audioManager.registerAudioDeviceCallback(deviceCallback, null)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    audioManager.unregisterAudioDeviceCallback(deviceCallback)
    engine.stop()
    methodChannel?.setMethodCallHandler(null)
    frameChannel?.setStreamHandler(null)
    methodChannel = null
    frameChannel = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "start" -> {
        if (requestAudioFocus()) {
          engine.start()
          result.success(null)
        } else {
          result.error("focus_denied", "Unable to obtain audio focus", null)
        }
      }
      "stop" -> {
        engine.stop()
        abandonAudioFocus()
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
  }

  override fun onCancel(arguments: Any?) {
    sink = null
  }

  private fun requestAudioFocus(): Boolean {
    val result = audioManager.requestAudioFocus(
      { change ->
        if (change <= 0) {
          restartOnResume = engine.isRunning()
          engine.stop()
        }
      },
      AudioManager.STREAM_MUSIC,
      AudioManager.AUDIOFOCUS_GAIN
    )
    return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
  }

  private fun abandonAudioFocus() {
    audioManager.abandonAudioFocus(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    (activity?.application as? Application)?.registerActivityLifecycleCallbacks(AppLifecycle(this))
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivity() {
    activity = null
    restartOnResume = false
    engine.stop()
  }

  override fun onPause(owner: LifecycleOwner) {
    restartOnResume = engine.isRunning()
    engine.stop()
  }

  override fun onResume(owner: LifecycleOwner) {
    if (restartOnResume) {
      restartOnResume = false
      engine.start()
    }
  }
}
