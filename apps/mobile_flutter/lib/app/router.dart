import 'package:flutter/material.dart';
import 'package:pt_contracts/pt_contracts.dart';

import '../exercises/exercise_catalog.dart';
import '../features/history/history_screen.dart';
import '../features/live_pitch/live_pitch_screen.dart';
import '../features/settings/settings_screen.dart';

class AppRoutes {
  static const home = '/';
  static const livePitch = '/live-pitch';
  static const history = '/history';
  static const settings = '/settings';
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return MaterialPageRoute(builder: (_) => const _HomeScreen());
    case AppRoutes.livePitch:
      return MaterialPageRoute(
        builder: (_) => LivePitchScreen(
          exercise: ExerciseCatalog.byId('PF_1'),
          level: LevelId.l1,
          config: const ExerciseConfig(),
        ),
      );
    case AppRoutes.history:
      return MaterialPageRoute(builder: (_) => const HistoryScreen());
    case AppRoutes.settings:
      return MaterialPageRoute(builder: (_) => const SettingsScreen());
    default:
      return MaterialPageRoute(builder: (_) => const _HomeScreen());
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pitch Translator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Live Pitch'),
            subtitle: const Text('Open live audio feedback session'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.livePitch),
          ),
          ListTile(
            title: const Text('History'),
            subtitle: const Text('Session list and details'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.history),
          ),
          ListTile(
            title: const Text('Settings'),
            subtitle: const Text('Persisted local preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
          ),
        ],
      ),
    );
  }
}
