package com.pitchtranslator.audio

import android.app.Activity
import android.app.Application
import android.os.Bundle
import androidx.lifecycle.LifecycleOwner

class AppLifecycle(private val plugin: PitchTranslatorAudioPlugin) : Application.ActivityLifecycleCallbacks {
  override fun onActivityPaused(activity: Activity) {
    val owner = activity as? LifecycleOwner
    if (owner != null) {
      plugin.onPause(owner)
    }
  }

  override fun onActivityResumed(activity: Activity) {
    val owner = activity as? LifecycleOwner
    if (owner != null) {
      plugin.onResume(owner)
    }
  }

  override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
  override fun onActivityStarted(activity: Activity) = Unit
  override fun onActivityStopped(activity: Activity) = Unit
  override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
  override fun onActivityDestroyed(activity: Activity) = Unit
}
