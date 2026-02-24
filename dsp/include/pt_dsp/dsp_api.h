#pragma once
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct DSPFrameOutput {
    double timestamp_ms;
    double freq_hz;            // use NaN when unavailable
    double midi_float;         // NaN when unavailable
    int    nearest_midi;       // -1 when unavailable
    double cents_error;        // NaN when unavailable
    double confidence;         // 0..1
    bool   vibrato_detected;
    double vibrato_rate_hz;    // NaN when unavailable
    double vibrato_depth_cents;// NaN when unavailable
} DSPFrameOutput;

typedef struct DSPConfig {
    double a4_hz;              // default 440
    int sample_rate_hz;        // preferred 48000
    int frame_size;            // e.g., 1024
    int hop_size;              // e.g., 256
} DSPConfig;

// Opaque handle
typedef struct PT_DSP PT_DSP;

PT_DSP* pt_dsp_create(DSPConfig cfg);
void    pt_dsp_destroy(PT_DSP* dsp);

// Feed hop_size mono samples (float PCM, [-1,1]).
// Must be realtime-safe: no allocations, no locks.
DSPFrameOutput pt_dsp_process(PT_DSP* dsp, const float* mono_samples, int num_samples);

#ifdef __cplusplus
}
#endif
