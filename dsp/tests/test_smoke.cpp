#include "pt_dsp/dsp_api.h"
#include <cassert>
#include <cmath>
#include <vector>

int main() {
    DSPConfig cfg{};
    cfg.a4_hz = 440.0;
    cfg.sample_rate_hz = 48000;
    cfg.frame_size = 1024;
    cfg.hop_size = 256;

    PT_DSP* dsp = pt_dsp_create(cfg);
    assert(dsp);

    std::vector<float> buf(cfg.hop_size, 0.0f);
    auto out = pt_dsp_process(dsp, buf.data(), (int)buf.size());

    assert(out.timestamp_ms >= 0.0);
    pt_dsp_destroy(dsp);
    return 0;
}
