import '../../domain/exercises/exercise_catalog.dart';
import '../../domain/session/session_repository.dart';

class LoadUnlockedExercisesUseCase {
  const LoadUnlockedExercisesUseCase(this._repository);

  final SessionProgressRepository _repository;

  Future<ProgressSnapshot> loadSnapshot() async {
    final mastered = await _repository.masteredExerciseLevelKeys();
    return ProgressSnapshot(mastered: mastered);
  }

  Future<List<ExerciseDefinition>> loadUnlocked(LevelId level) async {
    final snapshot = await loadSnapshot();
    return ExerciseCatalog.unlocked(snapshot, level);
  }
}
