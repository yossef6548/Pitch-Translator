import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _numericOverlay = true;
  bool _haptics = true;
  bool _storeAnalytics = true;
  bool _voicePrompts = false;
  String _profile = 'Standard';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _numericOverlay = prefs.getBool('settings.numeric_overlay') ?? true;
      _haptics = prefs.getBool('settings.haptics') ?? true;
      _storeAnalytics = prefs.getBool('settings.store_analytics') ?? true;
      _voicePrompts = prefs.getBool('settings.voice_prompts') ?? false;
      _profile = prefs.getString('settings.detection_profile') ?? 'Standard';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.numeric_overlay', _numericOverlay);
    await prefs.setBool('settings.haptics', _haptics);
    await prefs.setBool('settings.store_analytics', _storeAnalytics);
    await prefs.setBool('settings.voice_prompts', _voicePrompts);
    await prefs.setString('settings.detection_profile', _profile);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Pitch detection profile'),
            subtitle: Text(_profile),
            trailing: DropdownButton<String>(
              value: _profile,
              items: const [
                DropdownMenuItem(value: 'Strict', child: Text('Strict')),
                DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                DropdownMenuItem(value: 'Relaxed', child: Text('Relaxed')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _profile = value);
                _save();
              },
            ),
          ),
          SwitchListTile(
            value: _numericOverlay,
            onChanged: (v) {
              setState(() => _numericOverlay = v);
              _save();
            },
            title: const Text('Numeric feedback overlay'),
          ),
          SwitchListTile(
            value: _voicePrompts,
            onChanged: (v) {
              setState(() => _voicePrompts = v);
              _save();
            },
            title: const Text('Voice prompts'),
          ),
          SwitchListTile(
            value: _haptics,
            onChanged: (v) {
              setState(() => _haptics = v);
              _save();
            },
            title: const Text('Haptics'),
          ),
          SwitchListTile(
            value: _storeAnalytics,
            onChanged: (v) {
              setState(() => _storeAnalytics = v);
              _save();
            },
            title: const Text('Store analytics locally'),
            subtitle: const Text('Disabling this will prevent future session persistence.'),
          ),
        ],
      ),
    );
  }
}
