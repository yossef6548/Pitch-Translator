import 'level_id.dart';

class ProgressSnapshot {
  final Set<String> mastered;

  const ProgressSnapshot({this.mastered = const {}});

  bool isMastered(String exerciseId, LevelId level) =>
      mastered.contains(_key(exerciseId, level));

  static String key(String id, LevelId level) => _key(id, level);

  static String _key(String id, LevelId level) => '$id:${level.name}';
}
