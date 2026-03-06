abstract class SettingsRepository {
  Future<bool> loadShowNumericOverlay();
  Future<void> saveShowNumericOverlay(bool value);
}
