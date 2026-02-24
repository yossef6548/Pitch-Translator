#include "pt_dsp/dsp_api.h"

#include <cassert>
#include <cmath>
#include <vector>

int main() {
    DSPConfig cfg{};
    cfg.a4_hz = 440.0;
    cfg.sample_rate_hz = 48000;
    cfg.frame_size = 1024;
    cfg.hop_size = 1024;

    PT_DSP* dsp = pt_dsp_create(cfg);
    assert(dsp);

    std::vector<float> buf(cfg.hop_size, 0.0f);
    for (int i = 0; i < cfg.hop_size; ++i) {
        const double t = static_cast<double>(i) / cfg.sample_rate_hz;
        buf[i] = static_cast<float>(0.7 * std::sin(2.0 * M_PI * 440.0 * t));
    }

    auto out = pt_dsp_process(dsp, buf.data(), static_cast<int>(buf.size()));

    assert(out.timestamp_ms >= 0.0);
    assert(std::isfinite(out.freq_hz));
    assert(std::abs(out.freq_hz - 440.0) < 15.0);
    assert(out.nearest_midi == 69);
    assert(out.confidence > 0.2);

    pt_dsp_destroy(dsp);
    return 0;
}
