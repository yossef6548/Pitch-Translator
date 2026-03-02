#include "pt_dsp/dsp_api.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <random>
#include <sstream>
#include <string>
#include <vector>

namespace {
constexpr double kPi = 3.141592653589793;

struct FixtureSpec {
  std::string name;
  double expectedHz = 0.0;
  double baseHz = 0.0;
  double durationSeconds = 0.0;
  double vibratoDepth = 0.0;
  double vibratoRateHz = 0.0;
  double noiseAmp = 0.0;
  double amplitude = 0.0;
};

struct ValidationGate {
  double maxMeanAbsCents = 450.0;
  double minVoicedConfidence = 0.70;
  double maxUnvoicedConfidence = 0.03;
};

struct WavData {
  int sampleRate = 0;
  std::vector<float> mono;
};

bool splitFixtureLine(const std::string& line, std::vector<std::string>* out) {
  out->clear();
  std::stringstream ss(line);
  std::string item;
  while (std::getline(ss, item, ',')) {
    out->push_back(item);
  }
  return out->size() == 8;
}

bool loadFixtures(const std::string& path, std::vector<FixtureSpec>* fixtures) {
  std::ifstream in(path);
  if (!in) return false;

  fixtures->clear();
  std::string line;
  while (std::getline(in, line)) {
    if (line.empty() || line[0] == '#') continue;
    std::vector<std::string> fields;
    if (!splitFixtureLine(line, &fields)) return false;

    FixtureSpec f;
    f.name = fields[0];
    f.expectedHz = std::stod(fields[1]);
    f.baseHz = std::stod(fields[2]);
    f.durationSeconds = std::stod(fields[3]);
    f.vibratoDepth = std::stod(fields[4]);
    f.vibratoRateHz = std::stod(fields[5]);
    f.noiseAmp = std::stod(fields[6]);
    f.amplitude = std::stod(fields[7]);
    fixtures->push_back(f);
  }

  return !fixtures->empty();
}

std::vector<float> synthesizeFixture(const FixtureSpec& fixture, int sampleRate) {
  const int total = static_cast<int>(fixture.durationSeconds * sampleRate);
  std::vector<float> out(total, 0.0f);
  std::mt19937 rng(42);
  std::normal_distribution<float> noise(0.0f, static_cast<float>(fixture.noiseAmp));

  for (int i = 0; i < total; ++i) {
    const double t = static_cast<double>(i) / sampleRate;
    const double vib = fixture.vibratoDepth * std::sin(2.0 * kPi * fixture.vibratoRateHz * t);
    const double f = fixture.baseHz * (1.0 + vib);
    const double phase = 2.0 * kPi * f * t;
    double sample = fixture.amplitude * std::sin(phase);
    sample += 0.20 * std::sin(2.0 * phase);
    sample += 0.08 * std::sin(3.0 * phase);
    sample += 0.04 * std::sin(2.0 * kPi * 3.0 * t);
    sample += noise(rng);
    out[i] = static_cast<float>(std::clamp(sample, -1.0, 1.0));
  }

  return out;
}

bool writeWavPcm16(const std::string& path, const std::vector<float>& mono, int sampleRate) {
  std::ofstream out(path, std::ios::binary);
  if (!out) return false;

  const uint16_t channels = 1;
  const uint16_t bitsPerSample = 16;
  const uint16_t blockAlign = channels * (bitsPerSample / 8);
  const uint32_t byteRate = sampleRate * blockAlign;
  const uint32_t dataSize = static_cast<uint32_t>(mono.size() * sizeof(int16_t));
  const uint32_t riffSize = 36 + dataSize;

  out.write("RIFF", 4);
  out.write(reinterpret_cast<const char*>(&riffSize), 4);
  out.write("WAVE", 4);

  const uint32_t fmtSize = 16;
  const uint16_t audioFormat = 1;
  out.write("fmt ", 4);
  out.write(reinterpret_cast<const char*>(&fmtSize), 4);
  out.write(reinterpret_cast<const char*>(&audioFormat), 2);
  out.write(reinterpret_cast<const char*>(&channels), 2);
  out.write(reinterpret_cast<const char*>(&sampleRate), 4);
  out.write(reinterpret_cast<const char*>(&byteRate), 4);
  out.write(reinterpret_cast<const char*>(&blockAlign), 2);
  out.write(reinterpret_cast<const char*>(&bitsPerSample), 2);

  out.write("data", 4);
  out.write(reinterpret_cast<const char*>(&dataSize), 4);
  for (float s : mono) {
    const float clamped = std::clamp(s, -1.0f, 1.0f);
    const int16_t pcm = static_cast<int16_t>(std::lrint(clamped * 32767.0f));
    out.write(reinterpret_cast<const char*>(&pcm), sizeof(pcm));
  }

  return out.good();
}

bool readWavPcm16(const std::string& path, WavData* out) {
  std::ifstream in(path, std::ios::binary);
  if (!in) return false;
  char riff[4];
  uint32_t chunkSize = 0;
  char wave[4];
  in.read(riff, 4);
  in.read(reinterpret_cast<char*>(&chunkSize), 4);
  in.read(wave, 4);
  if (std::strncmp(riff, "RIFF", 4) != 0 || std::strncmp(wave, "WAVE", 4) != 0) return false;

  uint16_t channels = 0, bitsPerSample = 0, audioFormat = 0;
  uint32_t sampleRate = 0;
  std::vector<int16_t> pcm;

  while (in.good()) {
    char id[4];
    uint32_t size = 0;
    in.read(id, 4);
    in.read(reinterpret_cast<char*>(&size), 4);
    if (!in.good()) break;

    if (std::strncmp(id, "fmt ", 4) == 0) {
      uint16_t blockAlign = 0;
      uint32_t byteRate = 0;
      in.read(reinterpret_cast<char*>(&audioFormat), 2);
      in.read(reinterpret_cast<char*>(&channels), 2);
      in.read(reinterpret_cast<char*>(&sampleRate), 4);
      in.read(reinterpret_cast<char*>(&byteRate), 4);
      in.read(reinterpret_cast<char*>(&blockAlign), 2);
      in.read(reinterpret_cast<char*>(&bitsPerSample), 2);
      if (size > 16) in.seekg(size - 16, std::ios::cur);
    } else if (std::strncmp(id, "data", 4) == 0) {
      pcm.resize(size / sizeof(int16_t));
      in.read(reinterpret_cast<char*>(pcm.data()), size);
    } else {
      in.seekg(size, std::ios::cur);
    }
  }

  if (audioFormat != 1 || bitsPerSample != 16 || channels < 1 || sampleRate == 0 || pcm.empty()) return false;

  out->sampleRate = static_cast<int>(sampleRate);
  out->mono.resize(pcm.size() / channels);
  for (size_t i = 0, o = 0; i + channels <= pcm.size(); i += channels, ++o) {
    int sum = 0;
    for (int ch = 0; ch < channels; ++ch) sum += pcm[i + ch];
    out->mono[o] = static_cast<float>((sum / static_cast<double>(channels)) / 32768.0);
  }
  return true;
}
}  // namespace

int main() {
  constexpr int kSampleRate = 48000;
  constexpr char kFixturePath[] = "dsp/tests/samples/fixtures.txt";
  const ValidationGate gate{};

  std::vector<FixtureSpec> fixtures;
  if (!loadFixtures(kFixturePath, &fixtures)) {
    std::cerr << "failed_to_load_fixture=" << kFixturePath << "\n";
    return 2;
  }

  const std::filesystem::path generatedDir = "dsp/tests/samples/generated";
  std::filesystem::create_directories(generatedDir);

  bool allPass = true;
  for (const auto& f : fixtures) {
    const std::filesystem::path wavPath = generatedDir / (f.name + ".wav");
    const auto synthesized = synthesizeFixture(f, kSampleRate);
    if (!writeWavPcm16(wavPath.string(), synthesized, kSampleRate)) {
      std::cerr << "failed_to_write_wav=" << wavPath.string() << "\n";
      return 2;
    }

    WavData wav;
    if (!readWavPcm16(wavPath.string(), &wav)) {
      std::cerr << "invalid_wav=" << wavPath.string() << "\n";
      return 2;
    }

    DSPConfig cfg{};
    cfg.a4_hz = 440.0;
    cfg.sample_rate_hz = wav.sampleRate;
    cfg.frame_size = 1024;
    cfg.hop_size = std::min(256, std::max(64, wav.sampleRate / 50));

    PT_DSP* dsp = pt_dsp_create(cfg);
    if (!dsp) {
      std::cerr << "dsp_create_failed\n";
      return 2;
    }

    const int hop = cfg.hop_size;
    double centsAbsSum = 0.0;
    int centsCount = 0;
    double voicedConfSum = 0.0;
    int voicedCount = 0;
    double unvoicedConfSum = 0.0;
    int unvoicedCount = 0;

    for (size_t i = 0; i + hop <= wav.mono.size(); i += hop) {
      DSPFrameOutput frame = pt_dsp_process(dsp, wav.mono.data() + i, hop);
      if (std::isfinite(frame.freq_hz) && frame.freq_hz > 0.0) {
        const double cents = 1200.0 * std::log2(frame.freq_hz / f.expectedHz);
        centsAbsSum += std::abs(cents);
        ++centsCount;
      }
      voicedConfSum += frame.confidence;
      ++voicedCount;
    }

    std::vector<float> silence(static_cast<size_t>(cfg.sample_rate_hz), 0.0f);
    for (size_t i = 0; i + hop <= silence.size(); i += hop) {
      DSPFrameOutput frame = pt_dsp_process(dsp, silence.data() + i, hop);
      unvoicedConfSum += frame.confidence;
      ++unvoicedCount;
    }

    pt_dsp_destroy(dsp);

    const double meanAbsCents = centsCount > 0 ? (centsAbsSum / centsCount) : std::numeric_limits<double>::infinity();
    const double meanVoicedConf = voicedCount > 0 ? (voicedConfSum / voicedCount) : 0.0;
    const double meanUnvoicedConf = unvoicedCount > 0 ? (unvoicedConfSum / unvoicedCount) : 0.0;

    const bool pass = meanAbsCents <= gate.maxMeanAbsCents && meanVoicedConf >= gate.minVoicedConfidence &&
                      meanUnvoicedConf <= gate.maxUnvoicedConfidence;
    allPass = allPass && pass;

    std::cout << f.name << " mean_abs_cents=" << meanAbsCents << " voiced_conf=" << meanVoicedConf
              << " unvoiced_conf=" << meanUnvoicedConf << " status=" << (pass ? "PASS" : "FAIL") << "\n";
  }

  std::cout << "recorded_gate(max_cents=" << gate.maxMeanAbsCents << ", min_voiced_conf=" << gate.minVoicedConfidence
            << ", max_unvoiced_conf=" << gate.maxUnvoicedConfidence << ")\n";
  return allPass ? 0 : 1;
}
