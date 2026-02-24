#include "pt_dsp/dsp_api.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <new>

namespace {
constexpr int kMaxProcessSamples = 4096;
constexpr int kMinFreqHz = 80;
constexpr int kMaxFreqHz = 1100;
constexpr int kHistorySize = 64;

inline double hz_to_midi(double hz, double a4_hz) {
    return 69.0 + 12.0 * std::log2(hz / a4_hz);
}

inline double midi_to_hz(double midi, double a4_hz) {
    return a4_hz * std::pow(2.0, (midi - 69.0) / 12.0);
}

inline bool is_finite_positive(double v) {
    return std::isfinite(v) && v > 0.0;
}
}  // namespace

struct PT_DSP {
    DSPConfig cfg{};
    double t_ms = 0.0;
    std::array<double, kHistorySize> recent_cents{};
    std::array<double, kHistorySize> recent_time_ms{};
    int history_count = 0;
    int history_head = 0;
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

DSPFrameOutput pt_dsp_process(PT_DSP* dsp, const float* mono_samples, int num_samples) {
    DSPFrameOutput out{};
    out.freq_hz = NAN;
    out.midi_float = NAN;
    out.nearest_midi = -1;
    out.cents_error = NAN;
    out.confidence = 0.0;
    out.vibrato_detected = false;
    out.vibrato_rate_hz = NAN;
    out.vibrato_depth_cents = NAN;

    if (!dsp || !mono_samples || num_samples <= 0) {
        out.timestamp_ms = 0.0;
        return out;
    }

    out.timestamp_ms = dsp->t_ms;
    const int sample_rate = std::max(1, dsp->cfg.sample_rate_hz);
    const int n = std::min(num_samples, kMaxProcessSamples);

    const int min_lag = std::max(1, sample_rate / kMaxFreqHz);
    const int max_lag = std::min(n - 1, sample_rate / kMinFreqHz);
    if (min_lag >= max_lag) {
        dsp->t_ms += (1000.0 * num_samples) / static_cast<double>(sample_rate);
        return out;
    }

    double energy = 0.0;
    for (int i = 0; i < n; ++i) {
        energy += mono_samples[i] * mono_samples[i];
    }
    if (energy < 1e-8) {
        dsp->t_ms += (1000.0 * num_samples) / static_cast<double>(sample_rate);
        return out;
    }

    double best_corr = -1e30;
    int best_lag = -1;
    for (int lag = min_lag; lag <= max_lag; ++lag) {
        double corr = 0.0;
        for (int i = 0; i < n - lag; ++i) {
            corr += mono_samples[i] * mono_samples[i + lag];
        }
        if (corr > best_corr) {
            best_corr = corr;
            best_lag = lag;
        }
    }

    if (best_lag <= 0) {
        dsp->t_ms += (1000.0 * num_samples) / static_cast<double>(sample_rate);
        return out;
    }

    const double freq = static_cast<double>(sample_rate) / static_cast<double>(best_lag);
    if (!is_finite_positive(freq)) {
        dsp->t_ms += (1000.0 * num_samples) / static_cast<double>(sample_rate);
        return out;
    }

    const double midi_float = hz_to_midi(freq, dsp->cfg.a4_hz > 0 ? dsp->cfg.a4_hz : 440.0);
    const int nearest_midi = static_cast<int>(std::llround(midi_float));
    const double nearest_hz = midi_to_hz(nearest_midi, dsp->cfg.a4_hz > 0 ? dsp->cfg.a4_hz : 440.0);
    const double cents_error = 1200.0 * std::log2(freq / nearest_hz);
    const double confidence = std::clamp(best_corr / energy, 0.0, 1.0);

    out.freq_hz = freq;
    out.midi_float = midi_float;
    out.nearest_midi = nearest_midi;
    out.cents_error = cents_error;
    out.confidence = confidence;

    if (std::isfinite(cents_error)) {
        dsp->recent_cents[dsp->history_head] = cents_error;
        dsp->recent_time_ms[dsp->history_head] = out.timestamp_ms;
        dsp->history_head = (dsp->history_head + 1) % kHistorySize;
        dsp->history_count = std::min(kHistorySize, dsp->history_count + 1);
    }

    if (dsp->history_count >= 8) {
        double min_c = 1e9;
        double max_c = -1e9;
        double oldest_t = out.timestamp_ms;
        for (int i = 0; i < dsp->history_count; ++i) {
            min_c = std::min(min_c, dsp->recent_cents[i]);
            max_c = std::max(max_c, dsp->recent_cents[i]);
            oldest_t = std::min(oldest_t, dsp->recent_time_ms[i]);
        }
        const double duration_s = std::max(1e-6, (out.timestamp_ms - oldest_t) / 1000.0);
        const double depth = (max_c - min_c) * 0.5;
        const double cycles_estimate = std::max(0.0, (max_c - min_c) / 20.0);
        const double rate_hz = cycles_estimate / duration_s;

        if (depth > 2.0 && rate_hz >= 3.0 && rate_hz <= 9.0) {
            out.vibrato_detected = true;
            out.vibrato_depth_cents = depth;
            out.vibrato_rate_hz = rate_hz;
        }
    }

    dsp->t_ms += (1000.0 * num_samples) / static_cast<double>(sample_rate);
    return out;
}
