import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pt_contracts/pt_contracts.dart';

import 'audio/native_audio_bridge.dart';
import 'exercises/exercise_catalog.dart';
import 'training/training_engine.dart';

void main() {
  runApp(const PitchTranslatorApp());
}

class PitchTranslatorApp extends StatelessWidget {
  const PitchTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pitch Translator',
      theme: ThemeData.dark(useMaterial3: true),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTodayScreen(onStartFocus: () => setState(() => _index = 1)),
      const TrainCatalogScreen(),
      const AnalyzeOverviewScreen(),
      const LibraryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (next) => setState(() => _index = next),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Train'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analyze'),
          NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomeTodayScreen extends StatelessWidget {
  const HomeTodayScreen({super.key, required this.onStartFocus});

  final VoidCallback onStartFocus;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Today Focus: Drift Recovery'),
              subtitle: const Text('Goal: Hold A4 with ≤ ±20c for 8 seconds.'),
              trailing: FilledButton(onPressed: onStartFocus, child: const Text('Start')),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              title: Text('Quick Monitor'),
              subtitle: Text('Tap Train → LIVE_PITCH for full session controls.'),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              title: Text('Progress Snapshot'),
              subtitle: Text('Avg Error: 13c • Stability: 9c • Drift/Session: 1.2'),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              title: Text('Continue Last Session'),
              subtitle: Text('Mode: Drift Awareness • Progress: 62%'),
              trailing: Text('Resume'),
            ),
          ),
        ],
      ),
    );
  }
}

class TrainCatalogScreen extends StatelessWidget {
  const TrainCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final grouped = <ModeId, List<ExerciseDefinition>>{};
    for (final exercise in ExerciseCatalog.all) {
      grouped.putIfAbsent(exercise.mode, () => []).add(exercise);
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('TRAIN_CATALOG', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (final mode in ExerciseCatalog.modeOrder)
            Card(
              child: ExpansionTile(
                title: Text(_modeLabel(mode)),
                subtitle: Text('${grouped[mode]?.length ?? 0} exercises'),
                children: [
                  for (final exercise in grouped[mode] ?? const <ExerciseDefinition>[])
                    ListTile(
                      title: Text('${exercise.id}: ${exercise.name}'),
                      trailing: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => LivePitchScreen(exercise: exercise)));
                        },
                        child: const Text('Open'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _modeLabel(ModeId mode) {
    switch (mode) {
      case ModeId.modePf:
        return 'Foundation • Pitch Freezing';
      case ModeId.modeDa:
        return 'Awareness • Drift Awareness';
      case ModeId.modeRp:
        return 'Relative Pitch';
      case ModeId.modeGs:
        return 'Group Simulation';
      case ModeId.modeLt:
        return 'Listening & Translation';
    }
  }
}

class AnalyzeOverviewScreen extends StatelessWidget {
  const AnalyzeOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Text('ANALYZE_OVERVIEW\nSessions • Drift Events • Trends', textAlign: TextAlign.center),
      ),
    );
  }
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(child: Text('LIBRARY\nReference tones, choir packs, and imports')),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(child: Text('SETTINGS\nAudio • Accessibility • Feedback')),
    );
  }
}

class LivePitchScreen extends StatefulWidget {
  const LivePitchScreen({super.key, required this.exercise});

  final ExerciseDefinition exercise;

  @override
  State<LivePitchScreen> createState() => _LivePitchScreenState();
}

class _LivePitchScreenState extends State<LivePitchScreen> {
  late final TrainingEngine _engine;
  final _bridge = NativeAudioBridge();
  StreamSubscription<DspFrame>? _sub;
  bool _replayOpen = false;

  @override
  void initState() {
    super.initState();
    _engine = TrainingEngine(config: widget.exercise.configForLevel(LevelId.l2));
    _sub = _bridge.frames().listen((frame) {
      setState(() => _engine.onDspFrame(frame));
      if (_engine.state.id == LivePitchStateId.driftConfirmed && !_replayOpen && widget.exercise.driftAwarenessMode) {
        _openReplay();
      }
    });
  }

  Future<void> _openReplay() async {
    setState(() {
      _replayOpen = true;
      _engine.onIntent(TrainingIntent.pause);
    });
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      builder: (context) {
        final event = _engine.lastDriftEvent;
        final before = event?.beforeCents.round() ?? 0;
        final after = event?.afterCents.round() ?? 0;
        final delta = after - before;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DRIFT_REPLAY', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Before: ${event?.beforeMidi ?? '-'} (${before >= 0 ? '+' : ''}$before c)'),
                Text('After: ${event?.afterMidi ?? '-'} (${after >= 0 ? '+' : ''}$after c)'),
                Text('Delta: ${delta >= 0 ? '+' : ''}$delta cents'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Resume Exercise'),
                ),
              ],
            ),
          ),
        );
      },
    );
    setState(() {
      _replayOpen = false;
      _engine.onIntent(TrainingIntent.resume);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _engine.state;
    return Scaffold(
      appBar: AppBar(title: Text('LIVE_PITCH • ${widget.exercise.id}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _TargetHeader(),
            const SizedBox(height: 24),
            _PitchLine(state: state),
            const SizedBox(height: 24),
            _PitchShape(state: state),
            const SizedBox(height: 24),
            Text(state.errorReadoutVisible ? 'Cents: ${state.displayCents} ${state.arrow}' : 'Cents: —', style: const TextStyle(fontSize: 32)),
            Text('State: ${state.id.name}'),
            const Spacer(),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(onPressed: () => setState(() => _engine.onIntent(TrainingIntent.start)), child: const Text('Start')),
                ElevatedButton(onPressed: () => setState(() => _engine.onIntent(TrainingIntent.pause)), child: const Text('Pause')),
                ElevatedButton(onPressed: () => setState(() => _engine.onIntent(TrainingIntent.resume)), child: const Text('Resume')),
                ElevatedButton(onPressed: () => setState(() => _engine.onIntent(TrainingIntent.stop)), child: const Text('Stop')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetHeader extends StatelessWidget {
  const _TargetHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Target: A4', style: TextStyle(fontSize: 22)),
        Text('MIDI 69', style: TextStyle(fontSize: 22)),
      ],
    );
  }
}

class _PitchLine extends StatelessWidget {
  const _PitchLine({required this.state});

  final LivePitchUiState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Stack(
        children: [
          Center(child: Container(height: 2, color: Colors.white24)),
          Center(child: Container(width: 2, color: Colors.white, height: 24)),
          Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(state.xOffsetPx, 0),
              child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PitchShape extends StatelessWidget {
  const _PitchShape({required this.state});

  final LivePitchUiState state;

  @override
  Widget build(BuildContext context) {
    final saturation = state.saturation.clamp(0.0, 1.0);
    final color = HSVColor.fromAHSV(1, 0, saturation, 1).toColor();
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: state.haloIntensity.clamp(0.0, 1.0)), blurRadius: 24, spreadRadius: 6),
        ],
      ),
      child: Center(child: Text('E=${state.errorFactorE.toStringAsFixed(2)}')),
    );
  }
}
