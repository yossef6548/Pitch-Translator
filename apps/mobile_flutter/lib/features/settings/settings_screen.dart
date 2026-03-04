import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'log_export_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _numericOverlayKey = 'settings.numeric_overlay';

  bool _showNumericOverlay = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showNumericOverlay = prefs.getBool(_numericOverlayKey) ?? true;
    });
  }

  Future<void> _setNumericOverlay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_numericOverlayKey, value);
    if (!mounted) return;
    setState(() => _showNumericOverlay = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            value: _showNumericOverlay,
            onChanged: _setNumericOverlay,
            title: const Text('Show numeric pitch overlay'),
            subtitle: const Text('Persists locally via SharedPreferences.'),
          ),
          const ListTile(
            title: Text('Privacy note'),
            subtitle: Text(
              'Session history is stored with local-only SQLite storage on this device. '
              'No cloud sync is active in this repository.',
            ),
          ),
          const ListTile(
            title: Text('Microphone disclosure'),
            subtitle: Text(
              'Pitch Translator requires microphone access for real-time pitch detection. '
              'Without microphone permission, live tracking cannot start.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Diagnostic logs'),
            subtitle: const Text('View, copy, or export local logs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogExportScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
