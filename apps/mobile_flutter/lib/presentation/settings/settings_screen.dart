import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          ListTile(title: Text('Pitch detection')),
          ListTile(title: Text('Feedback representation')),
          ListTile(title: Text('Audio')),
          ListTile(title: Text('Training')),
          ListTile(title: Text('Privacy')),
          ListTile(title: Text('About')),
        ],
      ),
    );
  }
}
