package com.pitchtranslator.audio

import android.app.Activity
import android.app.Application
import android.os.Bundle

class AppLifecycle(private val plugin: PitchTranslatorAudioPlugin) : Application.ActivityLifecycleCallbacks {
  override fun onActivityPaused(activity: Activity) {
    plugin.onPause(object : androidx.lifecycle.LifecycleOwner {
      override val lifecycle = androidx.lifecycle.LifecycleRegistry(this)
    })
  }

  override fun onActivityResumed(activity: Activity) {
    plugin.onResume(object : androidx.lifecycle.LifecycleOwner {
      override val lifecycle = androidx.lifecycle.LifecycleRegistry(this)
    })
  }

  override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
  override fun onActivityStarted(activity: Activity) = Unit
  override fun onActivityStopped(activity: Activity) = Unit
  override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
  override fun onActivityDestroyed(activity: Activity) = Unit
}
