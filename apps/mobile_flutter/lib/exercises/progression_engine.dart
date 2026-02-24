import 'dart:math';

import 'exercise_catalog.dart';

class SessionMetrics {
  final double avgError;
  final double stability;
  final double lockRatio;
  final int driftCount;

  const SessionMetrics({
    required this.avgError,
    required this.stability,
    required this.lockRatio,
    required this.driftCount,
  });
}

class SessionMetricsBuilder {
  final List<double> _effectiveErrors = [];
  final List<double> _absEffectiveErrors = [];
  int _driftCount = 0;
  int _lockedMs = 0;
  int _activeMs = 0;

  void addEffectiveError(double effectiveError) {
    _effectiveErrors.add(effectiveError);
    _absEffectiveErrors.add(effectiveError.abs());
  }

  void addActiveTimeMs(int deltaMs, {required bool locked}) {
    _activeMs += max(0, deltaMs);
    if (locked) _lockedMs += max(0, deltaMs);
  }

  void incrementDrift() => _driftCount++;

  SessionMetrics build() {
    if (_effectiveErrors.isEmpty) {
      return const SessionMetrics(avgError: 0, stability: 0, lockRatio: 0, driftCount: 0);
    }

    final avgAbsError = _absEffectiveErrors.reduce((a, b) => a + b) / _absEffectiveErrors.length;
    final signedMean = _effectiveErrors.reduce((a, b) => a + b) / _effectiveErrors.length;
    final variance = _effectiveErrors
            .map((e) => (e - signedMean) * (e - signedMean))
            .reduce((a, b) => a + b) /
        _effectiveErrors.length;

    return SessionMetrics(
      avgError: avgAbsError,
      stability: sqrt(variance),
      lockRatio: _activeMs == 0 ? 0 : _lockedMs / _activeMs,
      driftCount: _driftCount,
    );
  }
}

class ProgressionEngine {
  bool isMastered(LevelId level, SessionMetrics metrics) {
    final threshold = masteryThresholds[level]!;
    return metrics.avgError <= threshold.avgErrorMax &&
        metrics.stability <= threshold.stabilityMax &&
        metrics.lockRatio >= threshold.lockRatioMin &&
        metrics.driftCount <= threshold.driftCountMax;
  }

  ProgressSnapshot applyResult({
    required ProgressSnapshot snapshot,
    required String exerciseId,
    required LevelId level,
    required SessionMetrics metrics,
  }) {
    if (!isMastered(level, metrics)) return snapshot;
    return ProgressSnapshot(
      mastered: {...snapshot.mastered, '$exerciseId:${level.name}'},
    );
  }
}
