#include "pt_dsp/dsp_api.h"
#include <cmath>
#include <new>

struct PT_DSP {
    DSPConfig cfg{};
    double t_ms = 0.0;
};

PT_DSP* pt_dsp_create(DSPConfig cfg) {
    PT_DSP* p = new (std::nothrow) PT_DSP();
    if (!p) return nullptr;
    p->cfg = cfg;
    p->t_ms = 0.0;
    return p;
}

void pt_dsp_destroy(PT_DSP* dsp) {
    delete dsp;
}

DSPFrameOutput pt_dsp_process(PT_DSP* dsp, const float* /*mono_samples*/, int num_samples) {
    // TODO: implement real pitch detection + confidence + vibrato detection
    DSPFrameOutput out{};
    out.timestamp_ms = dsp ? dsp->t_ms : 0.0;

    // placeholders: "no pitch"
    out.freq_hz = NAN;
    out.midi_float = NAN;
    out.nearest_midi = -1;
    out.cents_error = NAN;
    out.confidence = 0.0;
    out.vibrato_detected = false;
    out.vibrato_rate_hz = NAN;
    out.vibrato_depth_cents = NAN;

    if (dsp) {
        // advance time by hop duration
        const double hop_ms = (1000.0 * num_samples) / (double)std::max(1, dsp->cfg.sample_rate_hz);
        dsp->t_ms += hop_ms;
    }
    return out;
}
