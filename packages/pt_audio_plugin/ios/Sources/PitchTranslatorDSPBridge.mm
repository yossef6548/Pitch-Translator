#import "PitchTranslatorDSPBridge.h"
#include "pt_dsp/dsp_api.h"

#include <algorithm>
#include <cmath>

namespace {
double sanitizeFinite(double value, double fallbackNan = NAN) {
  return std::isfinite(value) ? value : fallbackNan;
}

PTDSPFrame sanitizeFrameForBridge(const PTDSPFrame& in) {
  PTDSPFrame out = in;
  out.timestamp_ms = std::max(0.0, sanitizeFinite(out.timestamp_ms, 0.0));
  out.confidence = std::clamp(sanitizeFinite(out.confidence, 0.0), 0.0, 1.0);
  out.freq_hz = sanitizeFinite(out.freq_hz);
  out.midi_float = sanitizeFinite(out.midi_float);
  out.cents_error = sanitizeFinite(out.cents_error);
  out.vibrato_rate_hz = sanitizeFinite(out.vibrato_rate_hz);
  out.vibrato_depth_cents = sanitizeFinite(out.vibrato_depth_cents);
  if (!std::isfinite(out.freq_hz) || out.freq_hz <= 0.0) {
    out.freq_hz = NAN;
    out.midi_float = NAN;
    out.nearest_midi = -1;
    out.cents_error = NAN;
    out.confidence = 0.0;
  }
  if (!out.vibrato_detected) {
    out.vibrato_rate_hz = NAN;
    out.vibrato_depth_cents = NAN;
  }
  return out;
}
}  // namespace

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
  return sanitizeFrameForBridge(out);
}

void pt_dsp_free(void* handle) {
  if (handle == nullptr) return;
  pt_dsp_destroy(reinterpret_cast<PT_DSP*>(handle));
}
