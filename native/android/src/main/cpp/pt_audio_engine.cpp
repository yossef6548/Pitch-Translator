#include <aaudio/AAudio.h>
#include <jni.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <thread>

#include "pt_dsp/dsp_api.h"

namespace {
constexpr int kFrameQueueSize = 1024;

struct QueuedFrame {
  DSPFrameOutput frame{};
  bool valid = false;
};

struct FrameRing {
  QueuedFrame items[kFrameQueueSize]{};
  std::atomic<uint32_t> write_index{0};
  std::atomic<uint32_t> read_index{0};

  bool push(const DSPFrameOutput& frame) {
    const uint32_t write = write_index.load(std::memory_order_relaxed);
    const uint32_t next = (write + 1u) % kFrameQueueSize;
    if (next == read_index.load(std::memory_order_acquire)) {
      return false;
    }
    items[write].frame = frame;
    items[write].valid = true;
    write_index.store(next, std::memory_order_release);
    return true;
  }

  bool pop(DSPFrameOutput* out) {
    const uint32_t read = read_index.load(std::memory_order_relaxed);
    if (read == write_index.load(std::memory_order_acquire)) {
      return false;
    }
    const QueuedFrame& slot = items[read];
    if (!slot.valid) {
      return false;
    }
    *out = slot.frame;
    items[read].valid = false;
    read_index.store((read + 1u) % kFrameQueueSize, std::memory_order_release);
    return true;
  }
};
}  // namespace

struct Engine {
  AAudioStream* stream = nullptr;
  PT_DSP* dsp = nullptr;
  JavaVM* vm = nullptr;
  jobject plugin_obj = nullptr;
  jmethodID on_frame = nullptr;

  FrameRing ring{};
  std::atomic<bool> running{false};
  std::thread emitter_thread;
};

struct JNIEnvGuard {
  JavaVM* vm;
  JNIEnv* env = nullptr;
  bool attached = false;

  explicit JNIEnvGuard(JavaVM* vm) : vm(vm) {
    jint state = vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (state == JNI_EDETACHED) {
      if (vm->AttachCurrentThread(&env, nullptr) == JNI_OK) {
        attached = true;
      } else {
        env = nullptr;
      }
    } else if (state != JNI_OK) {
      env = nullptr;
    }
  }

  ~JNIEnvGuard() {
    if (attached) {
      vm->DetachCurrentThread();
    }
  }
};

static void emitFramesOnBackgroundThread(Engine* engine) {
  JNIEnvGuard guard(engine->vm);
  if (guard.env == nullptr) {
    return;
  }

  while (engine->running.load(std::memory_order_acquire)) {
    DSPFrameOutput frame{};
    bool drained_any = false;
    while (engine->ring.pop(&frame)) {
      drained_any = true;
      guard.env->CallVoidMethod(
          engine->plugin_obj,
          engine->on_frame,
          frame.timestamp_ms,
          frame.freq_hz,
          frame.midi_float,
          frame.nearest_midi,
          frame.cents_error,
          std::clamp(frame.confidence, 0.0, 1.0),
          frame.vibrato_detected,
          frame.vibrato_rate_hz,
          frame.vibrato_depth_cents);
    }

    if (!drained_any) {
      std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }
  }

  DSPFrameOutput frame{};
  while (engine->ring.pop(&frame)) {
    guard.env->CallVoidMethod(
        engine->plugin_obj,
        engine->on_frame,
        frame.timestamp_ms,
        frame.freq_hz,
        frame.midi_float,
        frame.nearest_midi,
        frame.cents_error,
        std::clamp(frame.confidence, 0.0, 1.0),
        frame.vibrato_detected,
        frame.vibrato_rate_hz,
        frame.vibrato_depth_cents);
  }
}

static aaudio_data_callback_result_t dataCallback(
    AAudioStream* stream,
    void* userData,
    void* audioData,
    int32_t numFrames) {
  (void)stream;
  auto* engine = static_cast<Engine*>(userData);
  if (engine == nullptr || engine->dsp == nullptr) {
    return AAUDIO_CALLBACK_RESULT_STOP;
  }

  const float* pcm = static_cast<const float*>(audioData);
  const DSPFrameOutput frame = pt_dsp_process(engine->dsp, pcm, numFrames);
  engine->ring.push(frame);

  return AAUDIO_CALLBACK_RESULT_CONTINUE;
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_pitchtranslator_audio_NativeAaudioEngine_nativeStart(JNIEnv* env, jobject thiz) {
  auto* engine = new Engine();
  env->GetJavaVM(&engine->vm);
  engine->plugin_obj = env->NewGlobalRef(thiz);
  jclass cls = env->GetObjectClass(thiz);
  engine->on_frame = env->GetMethodID(cls, "onNativeFrame", "(DDDIDDZDD)V");

  AAudioStreamBuilder* builder = nullptr;
  AAudio_createStreamBuilder(&builder);
  AAudioStreamBuilder_setDirection(builder, AAUDIO_DIRECTION_INPUT);
  AAudioStreamBuilder_setChannelCount(builder, 1);
  AAudioStreamBuilder_setFormat(builder, AAUDIO_FORMAT_PCM_FLOAT);
  AAudioStreamBuilder_setPerformanceMode(builder, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
  AAudioStreamBuilder_setDataCallback(builder, dataCallback, engine);

  if (AAudioStreamBuilder_openStream(builder, &engine->stream) != AAUDIO_OK) {
    AAudioStreamBuilder_delete(builder);
    env->DeleteGlobalRef(engine->plugin_obj);
    delete engine;
    return 0;
  }

  const int sample_rate = AAudioStream_getSampleRate(engine->stream);
  DSPConfig cfg{};
  cfg.a4_hz = 440.0;
  cfg.sample_rate_hz = sample_rate;
  cfg.frame_size = 1024;
  cfg.hop_size = 256;
  engine->dsp = pt_dsp_create(cfg);

  AAudioStreamBuilder_delete(builder);
  engine->running.store(true, std::memory_order_release);
  engine->emitter_thread = std::thread(emitFramesOnBackgroundThread, engine);
  AAudioStream_requestStart(engine->stream);
  return reinterpret_cast<jlong>(engine);
}

extern "C" JNIEXPORT void JNICALL
Java_com_pitchtranslator_audio_NativeAaudioEngine_nativeStop(JNIEnv* env, jobject, jlong handle) {
  auto* engine = reinterpret_cast<Engine*>(handle);
  if (engine == nullptr) return;

  if (engine->stream != nullptr) {
    AAudioStream_requestStop(engine->stream);
    aaudio_stream_state_t ignored = AAUDIO_STREAM_STATE_STOPPING;
    aaudio_stream_state_t nextState = AAUDIO_STREAM_STATE_UNINITIALIZED;
    AAudioStream_waitForStateChange(engine->stream, ignored, &nextState, 2000000000LL);
  }
  engine->running.store(false, std::memory_order_release);
  if (engine->emitter_thread.joinable()) {
    engine->emitter_thread.join();
  }
  if (engine->stream != nullptr) {
    AAudioStream_close(engine->stream);
  }
  if (engine->dsp != nullptr) {
    pt_dsp_destroy(engine->dsp);
  }
  if (engine->plugin_obj != nullptr) {
    env->DeleteGlobalRef(engine->plugin_obj);
  }
  delete engine;
}
