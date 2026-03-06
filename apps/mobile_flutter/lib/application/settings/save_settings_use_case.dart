import '../../domain/settings/settings_repository.dart';

class SaveSettingsUseCase {
  const SaveSettingsUseCase(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  Future<void> executeShowNumericOverlay(bool value) {
    return _settingsRepository.saveShowNumericOverlay(value);
  }
}
