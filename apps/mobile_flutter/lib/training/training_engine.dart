import 'dart:collection';
import 'dart:math';

import 'package:pt_contracts/pt_contracts.dart';

class TrainingEngine {
  TrainingEngine({ExerciseConfig? config})
      : _config = config ?? const ExerciseConfig();

  final ExerciseConfig _config;
  LivePitchUiState state = const LivePitchUiState.idle();

  int? _lastTimestampMs;
  int _countdownRemainingMs = 0;
  int _withinToleranceMs = 0;
  int _outsideDriftMs = 0;
  int _lockedTimeMs = 0;
  LivePitchStateId _returnStateAfterOverride = LivePitchStateId.idle;
  final Queue<DspFrame> _recentFrames = Queue<DspFrame>();
  DriftEvent? lastDriftEvent;
  DspFrame? _lastLockedFrame;
  int _confirmedDriftCount = 0;
  int? _driftConfirmedAtMs;
  final List<int> _recoveryTimesMs = <int>[];

  int get confirmedDriftCount => _confirmedDriftCount;
  double? get averageRecoveryTimeMs =>
      _recoveryTimesMs.isEmpty
          ? null
          : _recoveryTimesMs.reduce((a, b) => a + b) / _recoveryTimesMs.length;

  void _resetSessionAccumulators() {
    _lastTimestampMs = null;
    _withinToleranceMs = 0;
    _outsideDriftMs = 0;
    _lockedTimeMs = 0;
    _returnStateAfterOverride = LivePitchStateId.idle;
    _recentFrames.clear();
    lastDriftEvent = null;
    _confirmedDriftCount = 0;
    _driftConfirmedAtMs = null;
    _recoveryTimesMs.clear();
  }

  void onDspFrame(DspFrame frame) {
    final dt = _lastTimestampMs == null
        ? 0
        : max(0, frame.timestampMs - _lastTimestampMs!);
    _lastTimestampMs = frame.timestampMs;

    if (state.id == LivePitchStateId.paused ||
        state.id == LivePitchStateId.completed ||
        state.id == LivePitchStateId.idle) {
      return;
    }

    if (state.id == LivePitchStateId.lowConfidence) {
      if (!_canRecoverFromLowConfidence(frame)) {
        state = _computeVisuals(frame, LivePitchStateId.lowConfidence,
            effectiveError: null);
        return;
      }
      state = state.copyWith(id: _returnStateAfterOverride);
    } else if (_isLowConfidence(frame)) {
      _returnStateAfterOverride = state.id;
      state = _computeVisuals(frame, LivePitchStateId.lowConfidence,
          effectiveError: null);
      return;
    }

    final effectiveError = _effectiveError(frame);
    final absEffectiveError = effectiveError.abs();

    if (state.id == LivePitchStateId.countdown) {
      _countdownRemainingMs = max(0, _countdownRemainingMs - dt);
      if (_countdownRemainingMs == 0) {
        state = _computeVisuals(frame, LivePitchStateId.seekingLock,
            effectiveError: effectiveError);
      }
      return;
    }

    final prior = state.id;
    var next = prior;

    if (prior == LivePitchStateId.seekingLock) {
      if (absEffectiveError <= _config.toleranceCents) {
        _withinToleranceMs += dt;
      } else {
        _withinToleranceMs = 0;
      }
      if (_withinToleranceMs >= PtConstants.lockAcquireTimeMs) {
        next = LivePitchStateId.locked;
        _lockedTimeMs = 0;
        _outsideDriftMs = 0;
        _lastLockedFrame = frame;
        if (_driftConfirmedAtMs != null) {
          _recoveryTimesMs.add(max(0, frame.timestampMs - _driftConfirmedAtMs!));
          _driftConfirmedAtMs = null;
        }
      }
    } else if (prior == LivePitchStateId.locked) {
      _lastLockedFrame = frame;
      _lockedTimeMs += dt;
      if (_lockedTimeMs >= PtConstants.lockRequiredBeforeDriftMs) {
        if (absEffectiveError > _config.driftThresholdCents) {
          _outsideDriftMs += dt;
        } else {
          _outsideDriftMs = 0;
        }
        if (_outsideDriftMs >= PtConstants.driftCandidateTimeMs) {
          next = LivePitchStateId.driftCandidate;
          _outsideDriftMs = 0;
        }
      }
    } else if (prior == LivePitchStateId.driftCandidate) {
      if (absEffectiveError <= _config.toleranceCents) {
        _outsideDriftMs = 0;
        next = LivePitchStateId.locked;
      } else if (absEffectiveError > _config.driftThresholdCents) {
        _outsideDriftMs += dt;
        if (_outsideDriftMs >= PtConstants.driftConfirmTimeMs) {
          next = LivePitchStateId.driftConfirmed;
          _confirmedDriftCount += 1;
          _driftConfirmedAtMs = frame.timestampMs;
          if (_lastLockedFrame != null) {
            lastDriftEvent =
                DriftEvent(before: _lastLockedFrame!, after: frame);
          }
        }
      }

    } else if (prior == LivePitchStateId.driftConfirmed &&
        _config.driftAwarenessMode &&
        absEffectiveError <= _config.toleranceCents) {
      next = LivePitchStateId.seekingLock;
      _outsideDriftMs = 0;
      _withinToleranceMs = 0;
    }

    state = _computeVisuals(frame, next, effectiveError: effectiveError);
  }

  void onIntent(TrainingIntent intent) {
    switch (intent) {
      case TrainingIntent.start:
        if (state.id == LivePitchStateId.idle ||
            state.id == LivePitchStateId.completed) {
          _resetSessionAccumulators();
          _countdownRemainingMs = _config.countdownMs;
          state = state.copyWith(
              id: LivePitchStateId.countdown, errorReadoutVisible: false);
        }
        break;
      case TrainingIntent.pause:
        if (state.id != LivePitchStateId.idle &&
            state.id != LivePitchStateId.paused) {
          _returnStateAfterOverride = state.id;
          state = state.copyWith(id: LivePitchStateId.paused);
        }
        break;
      case TrainingIntent.resume:
        if (state.id == LivePitchStateId.paused) {
          state = state.copyWith(id: _returnStateAfterOverride);
        }
        break;
      case TrainingIntent.stop:
        state = state.copyWith(id: LivePitchStateId.completed);
        break;
      case TrainingIntent.restart:
        _countdownRemainingMs = _config.countdownMs;
        _resetSessionAccumulators();
        state = const LivePitchUiState.idle();
        break;
    }
  }

  bool _isLowConfidence(DspFrame frame) {
    if (!frame.hasUsablePitch) return true;
    return frame.confidence < PtConstants.minConfidence;
  }

  bool _canRecoverFromLowConfidence(DspFrame frame) {
    if (!frame.hasUsablePitch) return false;
    return frame.confidence >= PtConstants.recoveryConfidence;
  }

  double _effectiveError(DspFrame frame) {
    _recentFrames.addLast(frame);
    while (_recentFrames.isNotEmpty &&
        frame.timestampMs - _recentFrames.first.timestampMs >
            PtConstants.effectiveErrorWindowMs) {
      _recentFrames.removeFirst();
    }

    final isValidVibrato = frame.vibrato.isQualified &&
        frame.vibrato.rateHz! >= PtConstants.vibratoRateMinHz &&
        frame.vibrato.rateHz! <= PtConstants.vibratoRateMaxHz &&
        frame.vibrato.depthCents! <= PtConstants.vibratoDepthLimitCents;

    if (!isValidVibrato) {
      return frame.centsError!
          .clamp(-PtConstants.centsErrorClamp, PtConstants.centsErrorClamp);
    }

    final usable = _recentFrames
        .where((f) => f.centsError != null)
        .toList(growable: false);
    if (usable.isEmpty) return 0;
    final mean = usable.map((f) => f.centsError!).reduce((a, b) => a + b) /
        usable.length;
    return mean.clamp(
        -PtConstants.centsErrorClamp, PtConstants.centsErrorClamp);
  }

  LivePitchUiState _computeVisuals(
    DspFrame frame,
    LivePitchStateId next, {
    required double? effectiveError,
  }) {
    if (next == LivePitchStateId.lowConfidence) {
      return state.copyWith(
        id: next,
        currentMidi: LivePitchUiState.setValue(frame.nearestMidi),
        centsError: LivePitchUiState.setValue<double>(null),
        effectiveError: LivePitchUiState.setValue<double>(null),
        absError: 0,
        errorFactorE: 0,
        directionD: 0,
        xOffsetPx: 0,
        deformPx: 0,
        saturation: PtConstants.lowConfidenceSaturation,
        haloIntensity: 0,
        errorReadoutVisible: false,
        displayCents: '—',
        arrow: '',
      );
    }

    final centsError = frame.centsError!
        .clamp(-PtConstants.centsErrorClamp, PtConstants.centsErrorClamp);
    final absError = effectiveError!.abs();
    final e = (absError / _config.driftThresholdCents).clamp(0.0, 1.0);
    final d = centsError == 0 ? 0 : (centsError > 0 ? 1 : -1);
    final shouldRenderRigid =
        next == LivePitchStateId.locked && absError <= _config.toleranceCents;
    final xOffset = shouldRenderRigid
        ? 0.0
        : (centsError / 100.0) * PtConstants.semitoneWidthPx;
    final deform = shouldRenderRigid ? 0.0 : e * PtConstants.maxDeformPx;

    var saturation = 1.0 - (e * 0.6);
    if (next == LivePitchStateId.locked)
      saturation = PtConstants.lockedSaturation;
    if (next == LivePitchStateId.seekingLock)
      saturation = PtConstants.seekingLockSaturation;
    if (next == LivePitchStateId.driftConfirmed)
      saturation = PtConstants.driftConfirmedSaturation;

    double haloIntensity;
    if (next == LivePitchStateId.locked) {
      haloIntensity = 1.0;
    } else if (next == LivePitchStateId.seekingLock) {
      final t = frame.timestampMs / 1000.0;
      haloIntensity = 0.65 + 0.15 * sin(2 * pi * t / 1.2);
    } else if (next == LivePitchStateId.driftConfirmed) {
      haloIntensity = 0.2;
    } else {
      haloIntensity = 0.4 + 0.3 * e;
    }

    final arrow =
        absError <= _config.toleranceCents ? '' : (centsError > 0 ? '↑' : '↓');
    return state.copyWith(
      id: next,
      currentMidi: LivePitchUiState.setValue(frame.nearestMidi),
      centsError: LivePitchUiState.setValue(centsError),
      effectiveError: LivePitchUiState.setValue(effectiveError),
      absError: absError,
      errorFactorE: e,
      directionD: d,
      xOffsetPx: xOffset,
      deformPx: deform,
      saturation: saturation,
      haloIntensity: haloIntensity,
      errorReadoutVisible: true,
      displayCents: '${centsError.round()}',
      arrow: arrow,
    );
  }
}

class DriftEvent {
  DriftEvent({required this.before, required this.after});

  final DspFrame before;
  final DspFrame after;

  int? get beforeMidi => before.nearestMidi;
  int? get afterMidi => after.nearestMidi;
  double get beforeCents => before.centsError ?? 0;
  double get afterCents => after.centsError ?? 0;
}
