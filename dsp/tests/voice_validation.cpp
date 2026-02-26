#include "pt_dsp/dsp_api.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <random>
#include <string>
#include <vector>

namespace {
constexpr int kSampleRate = 48000;
constexpr int kHop = 256;
constexpr double kPi = 3.141592653589793;

struct ScenarioResult {
  std::string name;
  double meanAbsCents = 0;
  double voicedConfidence = 0;
  double unvoicedConfidence = 0;
};

double midiToHz(double midi) { return 440.0 * std::pow(2.0, (midi - 69.0) / 12.0); }

std::vector<float> makeVoiceLikeSignal(double hz, double seconds, double noiseAmp, bool vibrato, bool reverb) {
  const int total = static_cast<int>(seconds * kSampleRate);
  std::vector<float> out(total, 0.0f);
  std::mt19937 rng(42);
  std::normal_distribution<float> noise(0.0f, static_cast<float>(noiseAmp));

  std::vector<float> delay(8000, 0.0f);
  int delayIdx = 0;

  for (int i = 0; i < total; ++i) {
    const double t = static_cast<double>(i) / kSampleRate;
    const double vib = vibrato ? std::sin(2.0 * kPi * 5.5 * t) * 0.015 : 0.0;
    const double f = hz * (1.0 + vib);
    const double phase = 2.0 * kPi * f * t;
    double sample = 0.7 * std::sin(phase) + 0.2 * std::sin(2.0 * phase) + 0.1 * std::sin(3.0 * phase);
    sample += 0.08 * std::sin(2.0 * kPi * 3.0 * t); // vowel/formant-ish envelope
    sample += noise(rng);

    if (reverb) {
      const float delayed = delay[delayIdx];
      const float mixed = static_cast<float>(sample) + 0.18f * delayed;
      delay[delayIdx] = mixed;
      delayIdx = (delayIdx + 1) % static_cast<int>(delay.size());
      out[i] = mixed;
    } else {
      out[i] = static_cast<float>(sample);
    }
  }

  return out;
}

ScenarioResult runScenario(const std::string& name, double hz, bool vibrato, bool reverb, double noiseAmp) {
  DSPConfig cfg{};
  cfg.a4_hz = 440.0;
  cfg.sample_rate_hz = kSampleRate;
  cfg.frame_size = 1024;
  cfg.hop_size = kHop;
  PT_DSP* dsp = pt_dsp_create(cfg);

  auto voiced = makeVoiceLikeSignal(hz, 8.0, noiseAmp, vibrato, reverb);
  std::vector<float> silence(voiced.size(), 0.0f);

  double centsSum = 0.0;
  int centsCount = 0;
  double voicedConfSum = 0.0;
  int voicedConfCount = 0;

  for (size_t i = 0; i + kHop <= voiced.size(); i += kHop) {
    auto frame = pt_dsp_process(dsp, voiced.data() + i, kHop);
    if (std::isfinite(frame.freq_hz)) {
      const double cents = 1200.0 * std::log2(frame.freq_hz / hz);
      centsSum += std::abs(cents);
      ++centsCount;
    }
    voicedConfSum += frame.confidence;
    ++voicedConfCount;
  }

  double unvoicedConfSum = 0.0;
  int unvoicedConfCount = 0;
  for (size_t i = 0; i + kHop <= silence.size(); i += kHop) {
    auto frame = pt_dsp_process(dsp, silence.data() + i, kHop);
    unvoicedConfSum += frame.confidence;
    ++unvoicedConfCount;
  }

  pt_dsp_destroy(dsp);
  return {
      name,
      centsCount == 0 ? 0.0 : centsSum / centsCount,
      voicedConfCount == 0 ? 0.0 : voicedConfSum / voicedConfCount,
      unvoicedConfCount == 0 ? 0.0 : unvoicedConfSum / unvoicedConfCount,
  };
}
}  // namespace

int main() {
  const auto start = std::chrono::steady_clock::now();

  std::vector<ScenarioResult> results;
  results.push_back(runScenario("clean_vowel_220hz", 220.0, false, false, 0.005));
  results.push_back(runScenario("noise_440hz", 440.0, false, false, 0.03));
  results.push_back(runScenario("reverb_330hz", 330.0, false, true, 0.01));
  results.push_back(runScenario("vibrato_262hz", 262.0, true, false, 0.01));
  results.push_back(runScenario("upper_voice_880hz", 880.0, true, true, 0.02));

  for (const auto& r : results) {
    std::cout << r.name
              << " mean_abs_cents=" << r.meanAbsCents
              << " voiced_conf=" << r.voicedConfidence
              << " unvoiced_conf=" << r.unvoicedConfidence << "\n";
  }

  constexpr int kThirtyMinutesFrames = (30 * 60 * kSampleRate) / kHop;
  DSPConfig cfg{};
  cfg.a4_hz = 440.0;
  cfg.sample_rate_hz = kSampleRate;
  cfg.frame_size = 1024;
  cfg.hop_size = kHop;
  PT_DSP* burn = pt_dsp_create(cfg);
  auto signal = makeVoiceLikeSignal(220.0, 2.0, 0.02, true, true);
  int xruns = 0;
  for (int i = 0; i < kThirtyMinutesFrames; ++i) {
    auto* framePtr = signal.data() + ((i * kHop) % (signal.size() - kHop));
    auto f = pt_dsp_process(burn, framePtr, kHop);
    if (!std::isfinite(f.confidence)) {
      ++xruns;
    }
  }
  pt_dsp_destroy(burn);

  const auto end = std::chrono::steady_clock::now();
  const auto elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
  std::cout << "burn_in_frames=" << kThirtyMinutesFrames << " xruns=" << xruns << " wall_ms=" << elapsedMs << "\n";

  return 0;
}
