import '../../domain/settings/settings_repository.dart';

class LoadSettingsUseCase {
  const LoadSettingsUseCase(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  Future<bool> executeShowNumericOverlay() {
    return _settingsRepository.loadShowNumericOverlay();
  }
}
