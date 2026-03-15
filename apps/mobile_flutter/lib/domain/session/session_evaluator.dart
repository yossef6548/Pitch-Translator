import 'package:pt_contracts/pt_contracts.dart';

import '../exercises/progression_engine.dart';

class SessionEvaluator {
  const SessionEvaluator();

  bool passed(SessionMetrics metrics, ExerciseConfig config) {
    return metrics.lockRatio >= 0.6 &&
        metrics.avgError <= config.toleranceCents * 1.5 &&
        metrics.driftCount <= 3;
  }
}
