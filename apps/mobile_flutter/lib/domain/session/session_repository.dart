import '../exercises/level_id.dart';

abstract class SessionProgressRepository {
  Future<Set<String>> masteredExerciseLevelKeys();

  String masteryKey(String exerciseId, LevelId level) => '$exerciseId:${level.name}';
}
