import '../../analytics/session_repository.dart';
import '../../domain/session/session_repository.dart';

class SqliteSessionProgressRepository extends SessionProgressRepository {
  SqliteSessionProgressRepository(this._sessionRepository);

  final SessionRepository _sessionRepository;

  @override
  Future<Set<String>> masteredExerciseLevelKeys() {
    return _sessionRepository.masteredExerciseLevelKeys();
  }
}
