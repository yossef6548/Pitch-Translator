package com.pitchtranslator.audio

class NativeAaudioEngine(private val onFrame: (Map<String, Any?>) -> Unit) {
  companion object {
    init {
      System.loadLibrary("pt_audio_engine")
    }
  }

  private var handle: Long = 0

  @Synchronized
  fun start() {
    if (handle != 0L) return
    handle = nativeStart()
  }

  @Synchronized
  fun stop() {
    if (handle == 0L) return
    nativeStop(handle)
    handle = 0
  }

  fun isRunning(): Boolean = handle != 0L

  @Suppress("unused")
  private fun onNativeFrame(
    timestampMs: Double,
    freqHz: Double,
    midiFloat: Double,
    nearestMidi: Int,
    centsError: Double,
    confidence: Double,
    vibratoDetected: Boolean,
    vibratoRateHz: Double,
    vibratoDepthCents: Double,
  ) {
    onFrame(
      mapOf(
        "timestamp_ms" to timestampMs.toLong(),
        "freq_hz" to freqHz.takeIf { it.isFinite() },
        "midi_float" to midiFloat.takeIf { it.isFinite() },
        "nearest_midi" to nearestMidi.takeIf { it >= 0 },
        "cents_error" to centsError.takeIf { it.isFinite() },
        "confidence" to confidence.coerceIn(0.0, 1.0),
        "vibrato" to mapOf(
          "detected" to vibratoDetected,
          "rate_hz" to vibratoRateHz.takeIf { it.isFinite() },
          "depth_cents" to vibratoDepthCents.takeIf { it.isFinite() },
        ),
      )
    )
  }

  private external fun nativeStart(): Long
  private external fun nativeStop(handle: Long)
}
