#import "PitchTranslatorDSPBridge.h"
#include "pt_dsp/dsp_api.h"

void* pt_dsp_make(int sample_rate_hz, int hop_size) {
  DSPConfig cfg{};
  cfg.a4_hz = 440.0;
  cfg.sample_rate_hz = sample_rate_hz;
  cfg.frame_size = 1024;
  cfg.hop_size = hop_size;
  return pt_dsp_create(cfg);
}

PTDSPFrame pt_dsp_run(void* handle, const float* mono, int sample_count) {
  PTDSPFrame out{};
  if (handle == nullptr || mono == nullptr || sample_count <= 0) {
    return out;
  }

  auto* dsp = reinterpret_cast<PT_DSP*>(handle);
  const DSPFrameOutput frame = pt_dsp_process(dsp, mono, sample_count);
  out.timestamp_ms = frame.timestamp_ms;
  out.freq_hz = frame.freq_hz;
  out.midi_float = frame.midi_float;
  out.nearest_midi = frame.nearest_midi;
  out.cents_error = frame.cents_error;
  out.confidence = frame.confidence;
  out.vibrato_detected = frame.vibrato_detected;
  out.vibrato_rate_hz = frame.vibrato_rate_hz;
  out.vibrato_depth_cents = frame.vibrato_depth_cents;
  return out;
}

void pt_dsp_free(void* handle) {
  if (handle == nullptr) return;
  pt_dsp_destroy(reinterpret_cast<PT_DSP*>(handle));
}
