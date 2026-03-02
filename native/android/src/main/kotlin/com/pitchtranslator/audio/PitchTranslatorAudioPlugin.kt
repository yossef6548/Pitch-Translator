package com.pitchtranslator.audio

import android.Manifest
import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class PitchTranslatorAudioPlugin :
  FlutterPlugin,
  MethodChannel.MethodCallHandler,
  EventChannel.StreamHandler,
  ActivityAware,
  DefaultLifecycleObserver,
  PluginRegistry.RequestPermissionsResultListener {

  private lateinit var context: Context
  private var methodChannel: MethodChannel? = null
  private var frameChannel: EventChannel? = null
  private var sink: EventChannel.EventSink? = null

  private var activity: Activity? = null
  private var activityBinding: ActivityPluginBinding? = null
  private var restartOnResume = false
  private var appLifecycle: AppLifecycle? = null

  private lateinit var audioManager: AudioManager
  private var focusListener: AudioManager.OnAudioFocusChangeListener? = null
  private var pendingPermissionResult: MethodChannel.Result? = null
  private var suppressFocusLoop = false
  private val deviceRestartHandler = Handler(Looper.getMainLooper())

  private val debouncedDeviceRestart = Runnable {
    if (!engine.isRunning() || suppressFocusLoop) return@Runnable
    Log.i(TAG, "Restarting audio engine after debounced device route change")
    engine.stop()
    try {
      engine.start()
    } catch (e: IllegalArgumentException) {
      Log.e(TAG, "Failed to restart audio engine after debounced device route change", e)
    }
  }

  private val deviceCallback = object : AudioDeviceCallback() {
    override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
      scheduleDebouncedDeviceRestart()
    }

    override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
      scheduleDebouncedDeviceRestart()
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
    deviceRestartHandler.removeCallbacksAndMessages(null)
    stopEngineWithFocusRelease()
    methodChannel?.setMethodCallHandler(null)
    frameChannel?.setStreamHandler(null)
    methodChannel = null
    frameChannel = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "start" -> startWithPermissions(result)
      "stop" -> {
        stopEngineWithFocusRelease()
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
    if (engine.isRunning()) {
      stopEngineWithFocusRelease()
    }
  }

  private fun startWithPermissions(result: MethodChannel.Result) {
    if (hasRecordAudioPermission()) {
      startEngine(result)
      return
    }

    val currentActivity = activity
    if (currentActivity == null) {
      result.error("missing_activity", "Cannot request RECORD_AUDIO without an attached activity", null)
      return
    }

    if (pendingPermissionResult != null) {
      result.error("permission_in_flight", "Permission request already in progress", null)
      return
    }

    pendingPermissionResult = result
    ActivityCompat.requestPermissions(
      currentActivity,
      arrayOf(Manifest.permission.RECORD_AUDIO),
      RECORD_AUDIO_REQUEST_CODE,
    )
  }

  private fun startEngine(result: MethodChannel.Result) {
    if (requestAudioFocus()) {
      try {
        engine.start()
        result.success(null)
      } catch (error: IllegalArgumentException) {
        abandonAudioFocus()
        result.error("audio_start_failed", error.message, null)
      }
    } else {
      result.error("focus_denied", "Unable to obtain audio focus", null)
    }
  }

  private fun hasRecordAudioPermission(): Boolean {
    return ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.RECORD_AUDIO,
    ) == PackageManager.PERMISSION_GRANTED
  }

  private fun requestAudioFocus(): Boolean {
    val listener = AudioManager.OnAudioFocusChangeListener { change ->
      if (change <= 0 && engine.isRunning()) {
        restartOnResume = true
        suppressFocusLoop = true
        engine.stop()
        suppressFocusLoop = false
      }
    }
    val result = audioManager.requestAudioFocus(
      listener,
      AudioManager.STREAM_MUSIC,
      AudioManager.AUDIOFOCUS_GAIN,
    )
    if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
      focusListener = listener
    }
    return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
  }

  private fun abandonAudioFocus() {
    focusListener?.let { audioManager.abandonAudioFocus(it) }
    focusListener = null
  }

  private fun stopEngineWithFocusRelease() {
    restartOnResume = false
    engine.stop()
    abandonAudioFocus()
  }

  private fun scheduleDebouncedDeviceRestart() {
    deviceRestartHandler.removeCallbacks(debouncedDeviceRestart)
    deviceRestartHandler.postDelayed(debouncedDeviceRestart, DEVICE_RESTART_DEBOUNCE_MS)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    activityBinding = binding
    binding.addRequestPermissionsResultListener(this)
    val lifecycle = AppLifecycle(this)
    appLifecycle = lifecycle
    (activity?.application as? Application)?.registerActivityLifecycleCallbacks(lifecycle)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivity() {
    appLifecycle?.let { lifecycle ->
      (activity?.application as? Application)?.unregisterActivityLifecycleCallbacks(lifecycle)
    }
    activityBinding?.removeRequestPermissionsResultListener(this)
    activityBinding = null
    appLifecycle = null
    activity = null
    restartOnResume = false
    pendingPermissionResult = null
    stopEngineWithFocusRelease()
  }

  override fun onPause(owner: LifecycleOwner) {
    restartOnResume = engine.isRunning()
    engine.stop()
  }

  override fun onResume(owner: LifecycleOwner) {
    if (restartOnResume && hasRecordAudioPermission() && requestAudioFocus()) {
      restartOnResume = false
      try {
        engine.start()
      } catch (e: IllegalArgumentException) {
        Log.e(TAG, "Failed to restart audio engine on resume", e)
        stopEngineWithFocusRelease()
      }
    }
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray,
  ): Boolean {
    if (requestCode != RECORD_AUDIO_REQUEST_CODE) {
      return false
    }
    val pending = pendingPermissionResult ?: return true
    pendingPermissionResult = null

    val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
    if (!granted) {
      pending.error("permission_denied", "RECORD_AUDIO permission denied", null)
      return true
    }

    startEngine(pending)
    return true
  }

  companion object {
    private const val RECORD_AUDIO_REQUEST_CODE = 34127
    private const val DEVICE_RESTART_DEBOUNCE_MS = 300L
    private const val TAG = "PTAudioPlugin"
  }
}
