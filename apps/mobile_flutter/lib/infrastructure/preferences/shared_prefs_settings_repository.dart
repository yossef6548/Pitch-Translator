import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/settings/settings_repository.dart';

class SharedPrefsSettingsRepository implements SettingsRepository {
  static const numericOverlayKey = 'settings.numeric_overlay';

  const SharedPrefsSettingsRepository();

  @override
  Future<bool> loadShowNumericOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(numericOverlayKey) ?? true;
  }

  @override
  Future<void> saveShowNumericOverlay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(numericOverlayKey, value);
  }
}
