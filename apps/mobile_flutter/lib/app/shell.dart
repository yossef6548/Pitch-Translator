import 'package:flutter/material.dart';

import '../presentation/analyze/analyze_overview_screen.dart';
import '../presentation/home/home_screen.dart';
import '../presentation/library/library_screen.dart';
import '../presentation/settings/settings_screen.dart';
import '../presentation/train/train_catalog_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static final _tabs = <Widget>[
    const HomeScreen(),
    const TrainCatalogScreen(),
    const AnalyzeOverviewScreen(),
    const LibraryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Train'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Analyze'),
          NavigationDestination(icon: Icon(Icons.library_music), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
