#include <aaudio/AAudio.h>
#include <jni.h>
#include <algorithm>
#include <cmath>
#include "pt_dsp/dsp_api.h"

struct Engine {
  AAudioStream* stream = nullptr;
  PT_DSP* dsp = nullptr;
  JavaVM* vm = nullptr;
  jobject plugin_obj = nullptr;
  jmethodID on_frame = nullptr;
};

// RAII helper that attaches the calling thread to the JVM if not already attached,
// and detaches it on destruction only if it was attached here.
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

static aaudio_data_callback_result_t dataCallback(
    AAudioStream* stream,
    void* userData,
    void* audioData,
    int32_t numFrames) {
  auto* engine = static_cast<Engine*>(userData);
  if (engine == nullptr || engine->dsp == nullptr) {
    return AAUDIO_CALLBACK_RESULT_STOP;
  }

  const float* pcm = static_cast<const float*>(audioData);
  const DSPFrameOutput frame = pt_dsp_process(engine->dsp, pcm, numFrames);

  JNIEnvGuard guard(engine->vm);
  if (guard.env == nullptr) {
    return AAUDIO_CALLBACK_RESULT_CONTINUE;
  }

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
  AAudioStream_requestStart(engine->stream);
  return reinterpret_cast<jlong>(engine);
}

extern "C" JNIEXPORT void JNICALL
Java_com_pitchtranslator_audio_NativeAaudioEngine_nativeStop(JNIEnv* env, jobject, jlong handle) {
  auto* engine = reinterpret_cast<Engine*>(handle);
  if (engine == nullptr) return;

  if (engine->stream != nullptr) {
    AAudioStream_requestStop(engine->stream);
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
