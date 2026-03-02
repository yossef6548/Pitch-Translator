import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        ],
      ),
    );
  }
}
