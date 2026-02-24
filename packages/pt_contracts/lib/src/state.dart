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

@immutable
class ExerciseConfig {
  final double toleranceCents;
  final double driftThresholdCents;
  final bool driftAwarenessMode;
  final int countdownMs;
  final bool randomizeTargetWithinRange;
  final bool referenceToneEnabled;
  final bool showNumericOverlay;
  final bool shapeWarpingEnabled;
  final bool colorFloodEnabled;
  final bool hapticsEnabled;

  const ExerciseConfig({
    this.toleranceCents = 20.0,
    this.driftThresholdCents = 30.0,
    this.driftAwarenessMode = false,
    this.countdownMs = 3000,
    this.randomizeTargetWithinRange = false,
    this.referenceToneEnabled = true,
    this.showNumericOverlay = true,
    this.shapeWarpingEnabled = true,
    this.colorFloodEnabled = true,
    this.hapticsEnabled = false,
  });
}

class _Value<T> {
  final bool isSet;
  final T? value;

  const _Value._(this.isSet, this.value);
  const _Value.unset() : this._(false, null);
  const _Value.set(T? value) : this._(true, value);
}

@immutable
class LivePitchUiState {
  final LivePitchStateId id;
  final LivePitchStateId? previousStateId;
  final int? currentMidi;
  final double? centsError;
  final double? effectiveError;
  final double absError;
  final double errorFactorE;
  final int directionD;
  final double xOffsetPx;
  final double deformPx;
  final double saturation;
  final double haloIntensity;
  final bool errorReadoutVisible;
  final String displayCents;
  final String arrow;

  const LivePitchUiState({
    required this.id,
    this.previousStateId,
    this.currentMidi,
    this.centsError,
    this.effectiveError,
    this.absError = 0,
    this.errorFactorE = 0,
    this.directionD = 0,
    this.xOffsetPx = 0,
    this.deformPx = 0,
    this.saturation = 1,
    this.haloIntensity = 0,
    this.errorReadoutVisible = true,
    this.displayCents = '—',
    this.arrow = '',
  });

  const LivePitchUiState.idle()
      : this(
          id: LivePitchStateId.idle,
          saturation: 1.0,
          haloIntensity: 0.0,
          errorReadoutVisible: false,
        );

  LivePitchUiState copyWith({
    LivePitchStateId? id,
    LivePitchStateId? previousStateId,
    _Value<int> currentMidi = const _Value.unset(),
    _Value<double> centsError = const _Value.unset(),
    _Value<double> effectiveError = const _Value.unset(),
    double? absError,
    double? errorFactorE,
    int? directionD,
    double? xOffsetPx,
    double? deformPx,
    double? saturation,
    double? haloIntensity,
    bool? errorReadoutVisible,
    String? displayCents,
    String? arrow,
  }) {
    return LivePitchUiState(
      id: id ?? this.id,
      previousStateId: previousStateId ?? this.previousStateId,
      currentMidi: currentMidi.isSet ? currentMidi.value : this.currentMidi,
      centsError: centsError.isSet ? centsError.value : this.centsError,
      effectiveError:
          effectiveError.isSet ? effectiveError.value : this.effectiveError,
      absError: absError ?? this.absError,
      errorFactorE: errorFactorE ?? this.errorFactorE,
      directionD: directionD ?? this.directionD,
      xOffsetPx: xOffsetPx ?? this.xOffsetPx,
      deformPx: deformPx ?? this.deformPx,
      saturation: saturation ?? this.saturation,
      haloIntensity: haloIntensity ?? this.haloIntensity,
      errorReadoutVisible: errorReadoutVisible ?? this.errorReadoutVisible,
      displayCents: displayCents ?? this.displayCents,
      arrow: arrow ?? this.arrow,
    );
  }

  static _Value<T> setValue<T>(T? value) => _Value<T>.set(value);
}
