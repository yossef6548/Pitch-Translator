import '../../analytics/session_repository.dart';
import '../../domain/session/session_repository.dart';

class SqliteSessionProgressRepository implements SessionProgressRepository {
  const SqliteSessionProgressRepository(this._sessionRepository);

  final SessionRepository _sessionRepository;

  @override
  Future<Set<String>> masteredExerciseLevelKeys() {
    return _sessionRepository.masteredExerciseLevelKeys();
  }
}
