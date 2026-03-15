import '../exercises/exercise_catalog.dart';

class SessionEvaluator {
  const SessionEvaluator();

  bool passed(SessionMetrics metrics, LevelId level) {
    return const MasteryEvaluator().evaluate(
      level: level,
      metrics: metrics,
      assisted: false,
    );
  }
}
