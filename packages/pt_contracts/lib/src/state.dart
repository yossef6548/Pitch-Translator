import 'package:meta/meta.dart';

/// Live Pitch UI states per `interaction.md`.
enum LivePitchStateId {
  idle,
  countdown,
  seekingLock,
  locked,
  driftCandidate,
  driftConfirmed,
  lowConfidence,
  paused,
  completed,
}

/// Minimal UI state placeholder.
/// Real state must include fields needed to render deterministically:
/// - cents_error, effective_error, E scalar, D sign
/// - pixel offsets, halo intensity, saturation
@immutable
class LivePitchUiState {
  final LivePitchStateId id;

  const LivePitchUiState._(this.id);

  const LivePitchUiState.idle() : this._(LivePitchStateId.idle);
}
