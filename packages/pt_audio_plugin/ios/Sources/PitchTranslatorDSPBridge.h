#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PTDSPFrame {
  double timestamp_ms;
  double freq_hz;
  double midi_float;
  int nearest_midi;
  double cents_error;
  double confidence;
  bool vibrato_detected;
  double vibrato_rate_hz;
  double vibrato_depth_cents;
} PTDSPFrame;

void* pt_dsp_make(int sample_rate_hz, int hop_size);
PTDSPFrame pt_dsp_run(void* handle, const float* mono, int sample_count);
void pt_dsp_free(void* handle);

#ifdef __cplusplus
}
#endif
