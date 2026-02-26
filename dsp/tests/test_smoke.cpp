#include "pt_dsp/dsp_api.h"

#include <cassert>
#include <cmath>
#include <vector>

namespace {
std::vector<float> make_sine(int sample_rate, int size, double freq_hz, double amplitude) {
    std::vector<float> buf(size, 0.0f);
    for (int i = 0; i < size; ++i) {
        const double t = static_cast<double>(i) / sample_rate;
        buf[i] = static_cast<float>(amplitude * std::sin(2.0 * M_PI * freq_hz * t));
    }
    return buf;
}
}

int main() {
    DSPConfig cfg{};
    cfg.a4_hz = 440.0;
    cfg.sample_rate_hz = 48000;
    cfg.frame_size = 1024;
    cfg.hop_size = 1024;

    PT_DSP* dsp = pt_dsp_create(cfg);
    assert(dsp);

    auto buf = make_sine(cfg.sample_rate_hz, cfg.hop_size, 440.0, 0.7);
    auto out = pt_dsp_process(dsp, buf.data(), static_cast<int>(buf.size()));

    assert(out.timestamp_ms >= 0.0);
    assert(std::isfinite(out.freq_hz));
    assert(std::abs(out.freq_hz - 440.0) < 3.5);
    assert(out.nearest_midi == 69);
    assert(out.confidence > 0.7);

    // Add light harmonic/noise contamination and ensure tracker remains robust.
    for (int i = 0; i < cfg.hop_size; ++i) {
        const double t = static_cast<double>(i) / cfg.sample_rate_hz;
        buf[i] = static_cast<float>(0.6 * std::sin(2.0 * M_PI * 329.63 * t) +
                                    0.15 * std::sin(2.0 * M_PI * 659.26 * t) +
                                    0.05 * std::sin(2.0 * M_PI * 1000.0 * t));
    }

    auto noisy_out = pt_dsp_process(dsp, buf.data(), static_cast<int>(buf.size()));
    assert(std::isfinite(noisy_out.freq_hz));
    assert(std::abs(noisy_out.freq_hz - 329.63) < 6.5);
    assert(noisy_out.confidence > 0.5);

    std::vector<float> dc_buf(cfg.hop_size, 0.1f);
    auto dc_out = pt_dsp_process(dsp, dc_buf.data(), static_cast<int>(dc_buf.size()));
    assert(!std::isfinite(dc_out.freq_hz));
    assert(dc_out.nearest_midi == -1);
    assert(dc_out.confidence == 0.0);

    pt_dsp_destroy(dsp);
    return 0;
}
