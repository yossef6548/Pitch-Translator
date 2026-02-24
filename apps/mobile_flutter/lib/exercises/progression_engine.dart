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

class AssistAdjustment {
  final double toleranceDeltaCents;
  final double durationScale;

  const AssistAdjustment({required this.toleranceDeltaCents, required this.durationScale});

  static const none = AssistAdjustment(toleranceDeltaCents: 0, durationScale: 1);
}

class ExerciseProgress {
  final int attempts;
  final int assistedAttempts;
  final DateTime? masteryDate;
  final DateTime? lastAttemptDate;
  final SessionMetrics? bestMetrics;
  final int consecutiveFailures;

  const ExerciseProgress({
    this.attempts = 0,
    this.assistedAttempts = 0,
    this.masteryDate,
    this.lastAttemptDate,
    this.bestMetrics,
    this.consecutiveFailures = 0,
  });

  ExerciseProgress copyWith({
    int? attempts,
    int? assistedAttempts,
    DateTime? masteryDate,
    bool clearMasteryDate = false,
    DateTime? lastAttemptDate,
    SessionMetrics? bestMetrics,
    int? consecutiveFailures,
  }) {
    return ExerciseProgress(
      attempts: attempts ?? this.attempts,
      assistedAttempts: assistedAttempts ?? this.assistedAttempts,
      masteryDate: clearMasteryDate ? null : (masteryDate ?? this.masteryDate),
      lastAttemptDate: lastAttemptDate ?? this.lastAttemptDate,
      bestMetrics: bestMetrics ?? this.bestMetrics,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    );
  }
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
  static const int failureAssistThreshold = 3;
  static const Duration skillDecayWindow = Duration(days: 30);

  final Map<String, ExerciseProgress> _exerciseState = {};

  ExerciseProgress progressFor(String exerciseId, LevelId level) {
    return _exerciseState[_key(exerciseId, level)] ?? const ExerciseProgress();
  }

  AssistAdjustment assistFor(String exerciseId, LevelId level) {
    final progress = progressFor(exerciseId, level);
    if (progress.consecutiveFailures < failureAssistThreshold) {
      return AssistAdjustment.none;
    }
    return const AssistAdjustment(toleranceDeltaCents: 5, durationScale: 0.8);
  }

  bool needsRefresh(String exerciseId, LevelId level, DateTime now) {
    final progress = progressFor(exerciseId, level);
    final masteryDate = progress.masteryDate;
    if (masteryDate == null) return false;
    return now.difference(masteryDate) > skillDecayWindow;
  }

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
    bool assisted = false,
    DateTime? attemptedAt,
  }) {
    final now = attemptedAt ?? DateTime.now();
    final progressKey = _key(exerciseId, level);
    final current = _exerciseState[progressKey] ?? const ExerciseProgress();
    final mastered = isMastered(level, metrics) && !assisted;

    final bestMetrics = _betterMetrics(current.bestMetrics, metrics);
    _exerciseState[progressKey] = current.copyWith(
      attempts: current.attempts + 1,
      assistedAttempts: current.assistedAttempts + (assisted ? 1 : 0),
      masteryDate: mastered ? now : current.masteryDate,
      lastAttemptDate: now,
      bestMetrics: bestMetrics,
      consecutiveFailures: mastered ? 0 : current.consecutiveFailures + 1,
    );

    if (!mastered) return snapshot;
    return ProgressSnapshot(mastered: {...snapshot.mastered, '$exerciseId:${level.name}'});
  }

  SessionMetrics _betterMetrics(SessionMetrics? previous, SessionMetrics candidate) {
    if (previous == null) return candidate;
    final previousScore = _qualityScore(previous);
    final candidateScore = _qualityScore(candidate);
    return candidateScore <= previousScore ? candidate : previous;
  }

  double _qualityScore(SessionMetrics metrics) {
    return metrics.avgError + metrics.stability + (1 - metrics.lockRatio) * 100 + metrics.driftCount * 10;
  }

  String _key(String exerciseId, LevelId level) => '$exerciseId:${level.name}';
}
