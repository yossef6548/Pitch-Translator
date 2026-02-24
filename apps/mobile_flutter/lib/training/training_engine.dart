import 'package:pt_contracts/pt_contracts.dart';

/// Training Engine placeholder.
/// Owns the state machine described in `interaction.md` and uses constants/math from `dsp-ui-binding.md`.
class TrainingEngine {
  TrainingEngine();

  LivePitchUiState state = const LivePitchUiState.idle();

  /// Called on every DSP frame (from native audio + C++ DSP).
  void onDspFrame(DspFrame frame) {
    // TODO: implement state machine:
    // - LOW_CONFIDENCE overrides everything
    // - IDLE/COUNTDOWN/SEEKING_LOCK/LOCKED/DRIFT_CANDIDATE/DRIFT_CONFIRMED/PAUSED/COMPLETED
    // - use effective_error (vibrato-aware)
    // - timing constants and thresholds from configs
  }

  /// User intents (buttons, navigation)
  void onIntent(TrainingIntent intent) {
    // TODO: implement transitions
  }
}
