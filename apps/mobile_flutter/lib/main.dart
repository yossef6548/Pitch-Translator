import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pt_contracts/pt_contracts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio/native_audio_bridge.dart';
import 'exercises/exercise_catalog.dart';
import 'training/training_engine.dart';

const _notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const _referenceTimbres = ['Pure Sine', 'Soft Piano', 'Warm Pad', 'Bright Saw'];

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
      home: const RootFlow(),
    );
  }
}

class RootFlow extends StatefulWidget {
  const RootFlow({super.key});

  @override
  State<RootFlow> createState() => _RootFlowState();
}

class _RootFlowState extends State<RootFlow> {
  static const _onboardingCompleteKey = 'onboarding_complete';

  bool _completedOnboarding = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOnboardingState();
  }

  Future<void> _loadOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_onboardingCompleteKey) ?? false;
    if (!mounted) {
      return;
    }
    setState(() {
      _completedOnboarding = completed;
      _loading = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
    if (!mounted) {
      return;
    }
    setState(() => _completedOnboarding = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_completedOnboarding) {
      return const AppShell();
    }
    return OnboardingCalibrationScreen(
      onComplete: _completeOnboarding,
    );
  }
}

class OnboardingCalibrationScreen extends StatefulWidget {
  const OnboardingCalibrationScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingCalibrationScreen> createState() => _OnboardingCalibrationScreenState();
}

class _OnboardingCalibrationScreenState extends State<OnboardingCalibrationScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _micReady = false;
  bool _headphonesReady = false;

  @override
  Widget build(BuildContext context) {
    final canContinue = _index < 2 || (_micReady && _headphonesReady);
    return Scaffold(
      appBar: AppBar(title: const Text('ONBOARDING_CALIBRATION')),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_index + 1) / 3),
          Expanded(
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _OnboardingPage(
                  title: 'Welcome to Pitch Translator',
                  bullets: const [
                    'Immediate pitch feedback through shape and color',
                    'Deterministic states: lock, drift, recovery',
                    'Daily focus drills personalized by progression engine',
                  ],
                ),
                _OnboardingPage(
                  title: 'How feedback works',
                  bullets: const [
                    'Pitch line: dot centered = on target',
                    'Shape halo: stable glow means confident hold',
                    'Cents arrow: follow direction for correction',
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Audio calibration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        value: _micReady,
                        onChanged: (v) => setState(() => _micReady = v ?? false),
                        title: const Text('Microphone permission granted'),
                        subtitle: const Text('Required for HOME_TODAY quick monitor and LIVE_PITCH.'),
                      ),
                      CheckboxListTile(
                        value: _headphonesReady,
                        onChanged: (v) => setState(() => _headphonesReady = v ?? false),
                        title: const Text('Headphones connected for reference playback'),
                        subtitle: const Text('Reduces false drift in noisy rooms.'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_index > 0)
                  TextButton(
                    onPressed: () {
                      setState(() => _index -= 1);
                      _controller.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                    },
                    child: const Text('Back'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: canContinue
                      ? () {
                          if (_index < 2) {
                            setState(() => _index += 1);
                            _controller.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                          } else {
                            widget.onComplete();
                          }
                        }
                      : null,
                  child: Text(_index < 2 ? 'Continue' : 'Start training'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (final bullet in bullets)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(bullet),
            ),
        ],
      ),
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

  void _openFocusFromHome(BuildContext context) {
    final focusExercise = ExerciseCatalog.byId('DA_2');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseConfigScreen(
          exercise: focusExercise,
          initialLevel: LevelId.l2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTodayScreen(
          onStartFocus: () => _openFocusFromHome(context),
          onOpenTrain: () => setState(() => _index = 1)),
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
  const HomeTodayScreen({super.key, required this.onStartFocus, required this.onOpenTrain});

  final VoidCallback onStartFocus;
  final VoidCallback onOpenTrain;

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
              subtitle: Text('Passive monitor ready. Open Train for full controls.'),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              title: Text('Progress Snapshot'),
              subtitle: Text('Avg Error: 13c • Stability: 9c • Drift/Session: 1.2'),
              trailing: Text('→ Analyze'),
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
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onOpenTrain, icon: const Icon(Icons.fitness_center), label: const Text('Go to TRAIN_CATALOG')),
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
                subtitle: Text('${grouped[mode]?.length ?? 0} exercises • Mastery 44%'),
                children: [
                  for (final exercise in grouped[mode] ?? const <ExerciseDefinition>[])
                    ListTile(
                      title: Text('${exercise.id}: ${exercise.name}'),
                      trailing: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ModeOverviewScreen(mode: mode)));
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

class ModeOverviewScreen extends StatelessWidget {
  const ModeOverviewScreen({super.key, required this.mode});

  final ModeId mode;

  @override
  Widget build(BuildContext context) {
    final exercises = ExerciseCatalog.all.where((e) => e.mode == mode).toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: Text('MODE_${mode.name.toUpperCase()}_OVERVIEW')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_modeTitle(mode), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_modeDescription(mode)),
          const SizedBox(height: 12),
          const Text('What you train here', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final bullet in _modeBullets(mode)) ListTile(leading: const Icon(Icons.check_circle_outline), title: Text(bullet)),
          const Divider(),
          const Text('Exercises', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final exercise in exercises)
            Card(
              child: ListTile(
                title: Text('${exercise.id}: ${exercise.name}'),
                subtitle: Text(exercise.driftAwarenessMode ? 'Drift replay enabled' : 'Standard tracking'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExerciseConfigScreen(exercise: exercise, initialLevel: LevelId.l2)));
                },
              ),
            ),
        ],
      ),
    );
  }
}

class ExerciseConfigScreen extends StatefulWidget {
  const ExerciseConfigScreen({super.key, required this.exercise, required this.initialLevel});

  final ExerciseDefinition exercise;
  final LevelId initialLevel;

  @override
  State<ExerciseConfigScreen> createState() => _ExerciseConfigScreenState();
}

class _ExerciseConfigScreenState extends State<ExerciseConfigScreen> {
  late LevelId _level;
  bool _randomizeTarget = false;
  bool _referenceOn = true;
  bool _showNumeric = true;
  bool _shapeWarping = true;
  bool _colorFlood = true;
  bool _haptics = false;
  bool _showCustomTolerance = false;
  double _tolerance = 20;
  double _driftThreshold = 30;
  String _targetNote = 'A';
  int _targetOctave = 4;
  String _rangeMinNote = 'G';
  int _rangeMinOctave = 3;
  String _rangeMaxNote = 'B';
  int _rangeMaxOctave = 4;
  String _referenceTimbre = _referenceTimbres.first;
  double _referenceVolume = 0.6;

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel;
    _applyLevelDefaults();
  }

  void _applyLevelDefaults() {
    final config = widget.exercise.configForLevel(_level);
    _tolerance = config.toleranceCents;
    _driftThreshold = config.driftThresholdCents;
  }

  Future<void> _openTargetPicker() async {
    var tempNote = _targetNote;
    var tempOctave = _targetOctave;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select target', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: tempNote,
                  items: [for (final note in _notes) DropdownMenuItem(value: note, child: Text(note))],
                  onChanged: (value) => setModalState(() => tempNote = value!),
                ),
                Slider(
                  min: 2,
                  max: 6,
                  divisions: 4,
                  label: 'Octave $tempOctave',
                  value: tempOctave.toDouble(),
                  onChanged: (v) => setModalState(() => tempOctave = v.round()),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _targetNote = tempNote;
                      _targetOctave = tempOctave;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Confirm target'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('EXERCISE_CONFIG • ${widget.exercise.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Target', style: TextStyle(fontWeight: FontWeight.bold)),
          ListTile(
            title: Text('Target: $_targetNote$_targetOctave'),
            subtitle: const Text('Tap to open note & octave picker'),
            trailing: const Icon(Icons.edit),
            onTap: _randomizeTarget ? null : _openTargetPicker,
          ),
          SwitchListTile(
            title: const Text('Randomize within range'),
            value: _randomizeTarget,
            onChanged: (value) => setState(() => _randomizeTarget = value),
          ),
          if (_randomizeTarget)
            Text('Range: $_rangeMinNote$_rangeMinOctave → $_rangeMaxNote$_rangeMaxOctave', style: Theme.of(context).textTheme.bodySmall),
          if (_randomizeTarget)
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _rangeMinNote,
                    isExpanded: true,
                    items: [for (final note in _notes) DropdownMenuItem(value: note, child: Text('Min $note'))],
                    onChanged: (value) => setState(() => _rangeMinNote = value!),
                  ),
                ),
                Expanded(
                  child: DropdownButton<String>(
                    value: _rangeMaxNote,
                    isExpanded: true,
                    items: [for (final note in _notes) DropdownMenuItem(value: note, child: Text('Max $note'))],
                    onChanged: (value) => setState(() => _rangeMaxNote = value!),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          const Text('Difficulty Level', style: TextStyle(fontWeight: FontWeight.bold)),
          SegmentedButton<LevelId>(
            segments: const [
              ButtonSegment(value: LevelId.l1, label: Text('L1')),
              ButtonSegment(value: LevelId.l2, label: Text('L2')),
              ButtonSegment(value: LevelId.l3, label: Text('L3')),
            ],
            selected: {_level},
            onSelectionChanged: (selected) {
              setState(() {
                _level = selected.first;
                _applyLevelDefaults();
              });
            },
          ),
          const SizedBox(height: 12),
          const Text('Tolerance', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('Lenient ±35c'), selected: _tolerance == 35, onSelected: (_) => setState(() => _tolerance = 35)),
              ChoiceChip(label: const Text('Standard ±20c'), selected: _tolerance == 20, onSelected: (_) => setState(() => _tolerance = 20)),
              ChoiceChip(label: const Text('Strict ±10c'), selected: _tolerance == 10, onSelected: (_) => setState(() => _tolerance = 10)),
            ],
          ),
          SwitchListTile(
            title: const Text('Custom tolerance slider'),
            value: _showCustomTolerance,
            onChanged: (value) => setState(() => _showCustomTolerance = value),
          ),
          if (_showCustomTolerance)
            Slider(
              min: 5,
              max: 40,
              divisions: 35,
              label: '±${_tolerance.round()}c',
              value: _tolerance,
              onChanged: (value) => setState(() => _tolerance = value),
            ),
          const SizedBox(height: 12),
          const Text('Reference', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('Reference tone'),
            value: _referenceOn,
            onChanged: (value) => setState(() => _referenceOn = value),
          ),
          DropdownButtonFormField<String>(
            value: _referenceTimbre,
            decoration: const InputDecoration(labelText: 'Timbre selector'),
            items: [for (final timbre in _referenceTimbres) DropdownMenuItem(value: timbre, child: Text(timbre))],
            onChanged: _referenceOn ? (value) => setState(() => _referenceTimbre = value!) : null,
          ),
          Slider(
            min: 0,
            max: 1,
            divisions: 10,
            label: '${(_referenceVolume * 100).round()}%',
            value: _referenceVolume,
            onChanged: _referenceOn ? (v) => setState(() => _referenceVolume = v) : null,
          ),
          const SizedBox(height: 12),
          const Text('Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(title: const Text('Numeric overlay'), value: _showNumeric, onChanged: (value) => setState(() => _showNumeric = value)),
          SwitchListTile(title: const Text('Shape warping'), value: _shapeWarping, onChanged: (value) => setState(() => _shapeWarping = value)),
          SwitchListTile(title: const Text('Color flood'), value: _colorFlood, onChanged: (value) => setState(() => _colorFlood = value)),
          SwitchListTile(title: const Text('Haptics'), value: _haptics, onChanged: (value) => setState(() => _haptics = value)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final config = ExerciseConfig(
                toleranceCents: _tolerance,
                driftThresholdCents: _driftThreshold,
                driftAwarenessMode: widget.exercise.driftAwarenessMode,
                countdownMs: PtConstants.defaultCountdownMs,
                randomizeTargetWithinRange: _randomizeTarget,
                referenceToneEnabled: _referenceOn,
                showNumericOverlay: _showNumeric,
                shapeWarpingEnabled: _shapeWarping,
                colorFloodEnabled: _colorFlood,
                hapticsEnabled: _haptics,
                targetNote: _targetNote,
                targetOctave: _targetOctave,
                randomizeMinNote: _rangeMinNote,
                randomizeMinOctave: _rangeMinOctave,
                randomizeMaxNote: _rangeMaxNote,
                randomizeMaxOctave: _rangeMaxOctave,
                referenceTimbre: _referenceTimbre,
                referenceVolume: _referenceVolume,
              );
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => LivePitchScreen(exercise: widget.exercise, config: config)));
            },
            child: const Text('Start Exercise'),
          ),
        ],
      ),
    );
  }
}

class AnalyzeOverviewScreen extends StatelessWidget {
  const AnalyzeOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = const [
      ('Drift Awareness', '08:31', '12c', 2),
      ('Pitch Freezing', '05:12', '9c', 0),
      ('Relative Pitch', '11:05', '18c', 1),
    ];
    return DefaultTabController(
      length: 3,
      child: SafeArea(
        child: Column(
          children: [
            const TabBar(tabs: [Tab(text: 'Sessions'), Tab(text: 'Trends'), Tab(text: 'Weakness Map')]),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    children: [
                      for (final s in sessions)
                        ListTile(
                          title: Text('${s.$1} • ${s.$2}'),
                          subtitle: Text('Avg Error ${s.$3} • Drift ${s.$4}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetailScreen(mode: s.$1))),
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      ListTile(title: Text('Avg error trend'), subtitle: Text('13c → 11c over 7 days')),
                      ListTile(title: Text('Stability score trend'), subtitle: Text('62 → 73')),
                      ListTile(title: Text('Drift trend'), subtitle: Text('1.8/session → 1.1/session')),
                    ],
                  ),
                  const Center(child: Text('ANALYZE_WEAKNESS_MAP\nPitch Class × Octave heatmap', textAlign: TextAlign.center)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SESSION_DETAIL')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(mode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const ListTile(title: Text('Cents error timeline'), subtitle: Text('Graph placeholder with drift markers.')),
          const ListTile(title: Text('Drift markers'), subtitle: Text('Tap marker to open replay frame pair.')),
          const ListTile(title: Text('Summary metrics'), subtitle: Text('Avg 12c • Stability 74 • Drifts 2')),
        ],
      ),
    );
  }
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('LIBRARY', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          ListTile(title: Text('Reference Tones'), subtitle: Text('Pitch, timbre, duration, loop and preview controls.')),
          ListTile(title: Text('Virtual Choir Presets'), subtitle: Text('Soprano/Alto/Tenor/Bass stacked textures.')),
          ListTile(title: Text('Imported Audio'), subtitle: Text('Bring rehearsal stems and annotate difficult passages.')),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('SETTINGS_ROOT', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          ListTile(title: Text('Pitch Detection'), subtitle: Text('Sensitivity and low-confidence thresholds.')),
          ListTile(title: Text('Feedback & Representation'), subtitle: Text('Shape/color mapping editor and preview.')),
          ListTile(title: Text('Audio'), subtitle: Text('Input route, reference output, latency diagnostics.')),
          ListTile(title: Text('Training'), subtitle: Text('Default tolerances, session duration and assisted mode behavior.')),
          ListTile(title: Text('Data & Privacy'), subtitle: Text('Session export, deletion and offline retention controls.')),
          ListTile(title: Text('About'), subtitle: Text('Version, licenses and support links.')),
        ],
      ),
    );
  }
}

class LivePitchScreen extends StatefulWidget {
  const LivePitchScreen({super.key, required this.exercise, required this.config});

  final ExerciseDefinition exercise;
  final ExerciseConfig config;

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
    _engine = TrainingEngine(config: widget.config);
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
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DRIFT_REPLAY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Before: ${event?.before.centsError?.toStringAsFixed(1) ?? '—'}c'),
              Text('After: ${event?.after.centsError?.toStringAsFixed(1) ?? '—'}c'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Resume exercise'),
              ),
            ],
          ),
        );
      },
    );
    if (mounted) {
      setState(() {
        _replayOpen = false;
        _engine.onIntent(TrainingIntent.resume);
      });
    }
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
            _TargetHeader(config: widget.config),
            const SizedBox(height: 24),
            _PitchLine(state: state),
            const SizedBox(height: 24),
            _PitchShape(state: state),
            const SizedBox(height: 24),
            Text(
              widget.config.showNumericOverlay && state.errorReadoutVisible ? 'Cents: ${state.displayCents} ${state.arrow}' : 'Cents: —',
              style: const TextStyle(fontSize: 32),
            ),
            Text('State: ${state.id.name}'),
            Text(
              'Session options • Randomize: ${widget.config.randomizeTargetWithinRange ? 'ON' : 'OFF'} • '
              'Reference: ${widget.config.referenceToneEnabled ? 'ON' : 'OFF'} • '
              'Timbre: ${widget.config.referenceTimbre} • '
              'Vol: ${(widget.config.referenceVolume * 100).round()}% • '
              'Shape: ${widget.config.shapeWarpingEnabled ? 'ON' : 'OFF'} • '
              'Color: ${widget.config.colorFloodEnabled ? 'ON' : 'OFF'} • '
              'Haptics: ${widget.config.hapticsEnabled ? 'ON' : 'OFF'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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

String _modeTitle(ModeId mode) {
  switch (mode) {
    case ModeId.modePf:
      return 'Pitch Freezing (Foundation)';
    case ModeId.modeDa:
      return 'Drift Awareness';
    case ModeId.modeRp:
      return 'Relative Pitch';
    case ModeId.modeGs:
      return 'Group Simulation';
    case ModeId.modeLt:
      return 'Listening & Translation';
  }
}

String _modeDescription(ModeId mode) {
  switch (mode) {
    case ModeId.modePf:
      return 'Build lock-in stability and reliable hold control around a single target.';
    case ModeId.modeDa:
      return 'Detect and recover from drift as soon as pitch instability appears.';
    case ModeId.modeRp:
      return 'Train interval navigation and silent correction decisions.';
    case ModeId.modeGs:
      return 'Hold anchors while competing tones and motion are introduced.';
    case ModeId.modeLt:
      return 'Map heard pitch to visual and numeric representations quickly.';
  }
}

List<String> _modeBullets(ModeId mode) {
  switch (mode) {
    case ModeId.modePf:
      return const ['Target hold consistency', 'Confidence in quiet starts', 'Basic stability metrics'];
    case ModeId.modeDa:
      return const ['Drift candidate awareness', 'Recovery under pressure', 'Before/after drift replay'];
    case ModeId.modeRp:
      return const ['Semitone jumps', 'Two-step arithmetic', 'Reference-free internal correction'];
    case ModeId.modeGs:
      return const ['Unison lock in context', 'Chord anchoring', 'Distraction resistance'];
    case ModeId.modeLt:
      return const ['Note identification', 'Color and shape matching', 'Octave discrimination'];
  }
}

class _TargetHeader extends StatelessWidget {
  const _TargetHeader({required this.config});

  final ExerciseConfig config;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Target: ${config.targetNote}${config.targetOctave}', style: const TextStyle(fontSize: 22)),
        Text('MIDI ${_noteToMidi(config.targetNote, config.targetOctave)}', style: const TextStyle(fontSize: 22)),
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
          BoxShadow(color: color.withOpacity(state.haloIntensity.clamp(0.0, 1.0)), blurRadius: 24, spreadRadius: 6),
        ],
      ),
      child: Center(child: Text('E=${state.errorFactorE.toStringAsFixed(2)}')),
    );
  }
}

int _noteToMidi(String note, int octave) {
  final index = _notes.indexOf(note);
  return (octave + 1) * 12 + (index < 0 ? 9 : index);
}
