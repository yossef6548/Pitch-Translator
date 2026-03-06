import '../analytics/session_repository.dart';
import '../application/progression/load_unlocked_exercises_use_case.dart';
import '../application/settings/load_settings_use_case.dart';
import '../application/settings/save_settings_use_case.dart';
import '../infrastructure/persistence/sqlite_session_progress_repository.dart';
import '../infrastructure/preferences/shared_prefs_settings_repository.dart';

class AppDependencies {
  AppDependencies._();

  static final sessionRepository = SessionRepository.instance;

  static final _progressRepository =
      SqliteSessionProgressRepository(sessionRepository);
  static const _settingsRepository = SharedPrefsSettingsRepository();

  static final loadUnlockedExercisesUseCase =
      LoadUnlockedExercisesUseCase(_progressRepository);
  static final loadSettingsUseCase = LoadSettingsUseCase(_settingsRepository);
  static final saveSettingsUseCase = SaveSettingsUseCase(_settingsRepository);
}
