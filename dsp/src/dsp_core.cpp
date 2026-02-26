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
constexpr double kYinThreshold = 0.12;

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
    std::array<double, kHistorySize> recent_freq_hz{};
};

namespace {
inline int wrap_history_index(int head, int offset_from_oldest, int count) {
    const int oldest = (head - count + kHistorySize) % kHistorySize;
    return (oldest + offset_from_oldest) % kHistorySize;
}

double parabolic_lag_refine(const std::array<double, kMaxProcessSamples>& cmndf,
                            int lag,
                            int max_lag) {
    if (lag <= 1 || lag >= max_lag - 1) {
        return static_cast<double>(lag);
    }

    const double y0 = cmndf[lag - 1];
    const double y1 = cmndf[lag];
    const double y2 = cmndf[lag + 1];
    const double denom = 2.0 * (2.0 * y1 - y0 - y2);
    if (std::abs(denom) < 1e-12) {
        return static_cast<double>(lag);
    }
    const double delta = (y0 - y2) / denom;
    return static_cast<double>(lag) + std::clamp(delta, -0.5, 0.5);
}
}  // namespace

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

    double mean = 0.0;
    for (int i = 0; i < n; ++i) {
        mean += mono_samples[i];
    }
    mean /= static_cast<double>(n);

    std::array<double, kMaxProcessSamples> centered{};
    double energy = 0.0;
    for (int i = 0; i < n; ++i) {
        centered[i] = static_cast<double>(mono_samples[i]) - mean;
        energy += centered[i] * centered[i];
    }
    if (energy < 1e-8) {
        dsp->t_ms += (1000.0 * num_samples) / static_cast<double>(sample_rate);
        return out;
    }

    std::array<double, kMaxProcessSamples> diff{};
    std::array<double, kMaxProcessSamples> cmndf{};

    for (int lag = min_lag; lag <= max_lag; ++lag) {
        double d = 0.0;
        for (int i = 0; i < n - lag; ++i) {
            const double delta = centered[i] - centered[i + lag];
            d += delta * delta;
        }
        diff[lag] = d;
    }

    cmndf[min_lag] = 1.0;
    double running_sum = 0.0;
    for (int lag = min_lag + 1; lag <= max_lag; ++lag) {
        running_sum += diff[lag];
        if (running_sum <= 1e-12) {
            cmndf[lag] = 1.0;
            continue;
        }
        cmndf[lag] = diff[lag] * static_cast<double>(lag - min_lag) / running_sum;
    }

    int best_lag = -1;
    double best_cmndf = 1.0;
    for (int lag = min_lag + 1; lag <= max_lag; ++lag) {
        const double v = cmndf[lag];
        if (v < kYinThreshold) {
            best_lag = lag;
            while (best_lag + 1 <= max_lag && cmndf[best_lag + 1] < cmndf[best_lag]) {
                ++best_lag;
            }
            best_cmndf = cmndf[best_lag];
            break;
        }
        if (v < best_cmndf) {
            best_cmndf = v;
            best_lag = lag;
        }
    }
    if (best_lag <= 0) {
        dsp->t_ms += (1000.0 * num_samples) / static_cast<double>(sample_rate);
        return out;
    }

    const double refined_lag = parabolic_lag_refine(cmndf, best_lag, max_lag);
    const double freq = static_cast<double>(sample_rate) / refined_lag;
    if (!is_finite_positive(freq)) {
        dsp->t_ms += (1000.0 * num_samples) / static_cast<double>(sample_rate);
        return out;
    }

    const double midi_float = hz_to_midi(freq, dsp->cfg.a4_hz > 0 ? dsp->cfg.a4_hz : 440.0);
    const int nearest_midi = static_cast<int>(std::llround(midi_float));
    const double nearest_hz = midi_to_hz(nearest_midi, dsp->cfg.a4_hz > 0 ? dsp->cfg.a4_hz : 440.0);
    const double cents_error = 1200.0 * std::log2(freq / nearest_hz);
    const double periodicity_confidence = std::clamp(1.0 - best_cmndf, 0.0, 1.0);

    double stability_confidence = 1.0;
    if (dsp->history_count >= 4) {
        double sum = 0.0;
        int samples = 0;
        for (int i = 0; i < dsp->history_count; ++i) {
            const int idx = wrap_history_index(dsp->history_head, i, dsp->history_count);
            if (dsp->recent_freq_hz[idx] > 0.0) {
                sum += dsp->recent_freq_hz[idx];
                ++samples;
            }
        }
        if (samples > 0) {
            const double mean_freq = sum / static_cast<double>(samples);
            double variance = 0.0;
            for (int i = 0; i < dsp->history_count; ++i) {
                const int idx = wrap_history_index(dsp->history_head, i, dsp->history_count);
                const double f = dsp->recent_freq_hz[idx];
                if (f <= 0.0) continue;
                const double cents_delta = 1200.0 * std::log2(f / mean_freq);
                variance += cents_delta * cents_delta;
            }
            const double rms_cents = std::sqrt(variance / static_cast<double>(samples));
            stability_confidence = std::clamp(1.0 - (rms_cents / 45.0), 0.0, 1.0);
        }
    }
    const double confidence = periodicity_confidence * 0.7 + stability_confidence * 0.3;

    out.freq_hz = freq;
    out.midi_float = midi_float;
    out.nearest_midi = nearest_midi;
    out.cents_error = cents_error;
    out.confidence = confidence;

    if (std::isfinite(cents_error)) {
        dsp->recent_cents[dsp->history_head] = cents_error;
        dsp->recent_time_ms[dsp->history_head] = out.timestamp_ms;
        dsp->recent_freq_hz[dsp->history_head] = freq;
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
