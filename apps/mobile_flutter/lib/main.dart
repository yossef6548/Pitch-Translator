import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pt_contracts/pt_contracts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics/session_repository.dart';
import 'audio/native_audio_bridge.dart';
import 'exercises/exercise_catalog.dart';
import 'qa/drift_snippet_recorder.dart';
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
    var completed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      completed = prefs.getBool(_onboardingCompleteKey) ?? false;
    } catch (error) {
      debugPrint('Failed to load onboarding state: $error');
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _completedOnboarding = completed;
      _loading = false;
    });
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompleteKey, true);
    } catch (error) {
      debugPrint('Failed to persist onboarding state: $error');
    }
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
          onOpenTrain: () => setState(() => _index = 1),
          onOpenQuickMonitor: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LivePitchScreen(
                  exercise: ExerciseCatalog.byId('PF_1'),
                  level: LevelId.l1,
                  config: const ExerciseConfig(
                    referenceToneEnabled: false,
                    toleranceCents: 20.0,
                    driftThresholdCents: 30.0,
                  ),
                ),
              ),
            );
          }),
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
  const HomeTodayScreen({
    super.key,
    required this.onStartFocus,
    required this.onOpenTrain,
    required this.onOpenQuickMonitor,
  });

  final VoidCallback onStartFocus;
  final VoidCallback onOpenTrain;
  final VoidCallback onOpenQuickMonitor;

  @override
  Widget build(BuildContext context) {
    final trendsFuture = SessionRepository.instance.recentTrends();
    final latestSessionFuture = SessionRepository.instance.latestSession();
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
          Card(
            child: InkWell(
              onTap: onOpenQuickMonitor,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: StreamBuilder<DspFrame>(
                  stream: NativeAudioBridge().frames(),
                  builder: (context, snapshot) {
                    final frame = snapshot.data;
                    final noteLabel = _midiToNoteLabel(frame?.nearestMidi);
                    final haloColor = _pitchClassColor(frame?.nearestMidi);
                    final markerAlignment = ((frame?.centsError ?? 0) / PtConstants.centsErrorClamp).clamp(-1.0, 1.0).toDouble();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quick Monitor', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          frame == null ? 'Warming up mic preview…' : 'Current note: $noteLabel',
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: haloColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: haloColor.withOpacity(0.65),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 20,
                                child: Stack(
                                  children: [
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(height: 2, color: Colors.white24),
                                    ),
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(width: 2, height: 14, color: Colors.white70),
                                    ),
                                    Align(
                                      alignment: Alignment(markerAlignment, 0),
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: haloColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text('Tap to open LIVE_PITCH', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: FutureBuilder<TrendSnapshot>(
              future: trendsFuture,
              builder: (context, snapshot) {
                final trend = snapshot.data;
                final subtitle = trend == null || trend.sampleSize == 0
                    ? 'No completed sessions yet. Start a drill to populate analytics.'
                    : 'Avg Error: ${trend.avgErrorCents.toStringAsFixed(1)}c • '
                        'Stability: ${trend.stabilityScore.toStringAsFixed(1)} • '
                        'Drift/Session: ${trend.driftPerSession.toStringAsFixed(2)}';
                return ListTile(
                  title: const Text('Progress Snapshot'),
                  subtitle: Text(subtitle),
                  trailing: const Text('→ Analyze'),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: FutureBuilder<SessionRecord?>(
              future: latestSessionFuture,
              builder: (context, snapshot) {
                final last = snapshot.data;
                return ListTile(
                  title: const Text('Continue Last Session'),
                  subtitle: Text(
                    last == null
                        ? 'No resumable session yet.'
                        : 'Mode: ${last.modeLabel} • Last avg error: ${last.avgErrorCents.toStringAsFixed(1)}c',
                  ),
                  trailing: const Text('Resume'),
                );
              },
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LivePitchScreen(
                    exercise: widget.exercise,
                    config: config,
                    level: _level,
                  ),
                ),
              );
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
    final sessionsFuture = SessionRepository.instance.recentSessions(limit: 30);
    final trendsFuture = SessionRepository.instance.recentTrends();
    final seriesFuture = SessionRepository.instance.trendSeries(limit: 20);
    final weaknessFuture = SessionRepository.instance.weaknessMap();
    final percentilesFuture = SessionRepository.instance.modeLevelPercentiles();
    final retentionFuture = SessionRepository.instance.retentionSnapshot();
    return DefaultTabController(
      length: 3,
      child: SafeArea(
        child: Column(
          children: [
            const TabBar(tabs: [Tab(text: 'Sessions'), Tab(text: 'Trends'), Tab(text: 'Weakness Map')]),
            Expanded(
              child: TabBarView(
                children: [
                  FutureBuilder<List<SessionRecord>>(
                    future: sessionsFuture,
                    builder: (context, snapshot) {
                      final sessions = snapshot.data ?? const <SessionRecord>[];
                      if (sessions.isEmpty) {
                        return const Center(child: Text('No sessions yet. Complete a LIVE_PITCH run to populate analytics.'));
                      }
                      return ListView(
                        children: [
                          for (final s in sessions)
                            ListTile(
                              title: Text('${s.modeLabel} • ${_formatDuration(s.durationMs)}'),
                              subtitle: Text('Avg Error ${s.avgErrorCents.toStringAsFixed(1)}c • Drift ${s.driftCount}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: s.id)),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  FutureBuilder<List<TrendPoint>>(
                    future: seriesFuture,
                    builder: (context, snapshot) {
                      final series = snapshot.data ?? const <TrendPoint>[];
                      return FutureBuilder<TrendSnapshot>(
                        future: trendsFuture,
                        builder: (context, trendSnapshot) {
                          final trend = trendSnapshot.data;
                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              ListTile(
                                title: const Text('Avg error trend (recent sessions)'),
                                subtitle: Text('${trend?.avgErrorCents.toStringAsFixed(1) ?? '—'}c'),
                              ),
                              SizedBox(height: 96, child: _TrendSparkline(series: series, selector: (p) => p.avgErrorCents, color: Colors.orangeAccent)),
                              const SizedBox(height: 12),
                              ListTile(
                                title: const Text('Stability score trend (recent sessions)'),
                                subtitle: Text(trend?.stabilityScore.toStringAsFixed(1) ?? '—'),
                              ),
                              SizedBox(height: 96, child: _TrendSparkline(series: series, selector: (p) => p.stabilityScore, color: Colors.lightGreenAccent)),
                              const SizedBox(height: 12),
                              ListTile(
                                title: const Text('Drift trend (recent sessions)'),
                                subtitle: Text(trend == null ? '—' : '${trend.driftPerSession.toStringAsFixed(2)} per session'),
                              ),
                              SizedBox(height: 96, child: _TrendSparkline(series: series, selector: (p) => p.driftCount.toDouble(), color: Colors.cyanAccent)),
                              const SizedBox(height: 12),
                              FutureBuilder<RetentionSnapshot>(
                                future: retentionFuture,
                                builder: (context, retentionSnapshot) {
                                  final retention = retentionSnapshot.data;
                                  final mastered = retention?.masteredCount ?? 0;
                                  final ratio7d = retention == null ? '—' : '${(retention.retained7DayRatio * 100).round()}%';
                                  final ratio30d = retention == null ? '—' : '${(retention.retained30DayRatio * 100).round()}%';
                                  return ListTile(
                                    title: const Text('Longitudinal retention'),
                                    subtitle: Text('Masteries: $mastered • 7d: $ratio7d • 30d: $ratio30d'),
                                  );
                                },
                              ),
                              FutureBuilder<List<ModeLevelPercentile>>(
                                future: percentilesFuture,
                                builder: (context, percentileSnapshot) {
                                  final percentiles = percentileSnapshot.data ?? const <ModeLevelPercentile>[];
                                  if (percentiles.isEmpty) {
                                    return const ListTile(
                                      title: Text('Mode/level error percentiles'),
                                      subtitle: Text('No attempt distribution yet.'),
                                    );
                                  }
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text('Mode/level error percentiles'),
                                        subtitle: Text('Absolute cents error distribution by exercise mode and level.'),
                                      ),
                                      for (final row in percentiles)
                                        ListTile(
                                          dense: true,
                                          title: Text('${row.mode} • ${row.level}'),
                                          subtitle: Text('P50 ${row.p50ErrorCents.toStringAsFixed(1)}c • P90 ${row.p90ErrorCents.toStringAsFixed(1)}c'),
                                          trailing: Text('n=${row.sampleSize}'),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  FutureBuilder<List<WeaknessMapCell>>(
                    future: weaknessFuture,
                    builder: (context, snapshot) {
                      final cells = snapshot.data ?? const <WeaknessMapCell>[];
                      if (cells.isEmpty) {
                        return const Center(
                          child: Text(
                            'ANALYZE_WEAKNESS_MAP\nComplete targeted sessions to build the pitch-class × octave heatmap.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return _WeaknessMapGrid(cells: cells);
                    },
                  ),
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
  const SessionDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SESSION_DETAIL')),
      body: FutureBuilder<SessionRecord?>(
        future: SessionRepository.instance.sessionById(sessionId),
        builder: (context, snapshot) {
          final session = snapshot.data;
          if (session == null) {
            return const Center(child: Text('Session not found.'));
          }
          return FutureBuilder<List<DriftEventRecord>>(
            future: SessionRepository.instance.driftEventsForSession(sessionId),
            builder: (context, driftSnapshot) {
              final driftEvents = driftSnapshot.data ?? const <DriftEventRecord>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(session.modeLabel, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 84,
                    child: _SessionTimeline(session: session, driftEvents: driftEvents),
                  ),
                  const SizedBox(height: 12),
                  ListTile(title: const Text('Duration'), subtitle: Text(_formatDuration(session.durationMs))),
                  ListTile(title: const Text('Average cents error'), subtitle: Text('${session.avgErrorCents.toStringAsFixed(1)}c')),
                  ListTile(title: const Text('Stability score'), subtitle: Text(session.stabilityScore.toStringAsFixed(1))),
                  ListTile(title: const Text('Drift events'), subtitle: Text('${session.driftCount} confirmed drifts')),
                  const Divider(),
                  const Text('Drift markers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  if (driftEvents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No drift markers recorded for this session.'),
                    )
                  else
                    ...driftEvents.map(
                      (event) => ListTile(
                        leading: const Icon(Icons.warning_amber_rounded),
                        title: Text('Drift #${event.eventIndex + 1}'),
                        subtitle: Text('Recorded at ${_formatEpochTime(event.confirmedAtMs)}'),
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (context) => DriftReplaySheet(event: event),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class DriftReplaySheet extends StatefulWidget {
  const DriftReplaySheet({super.key, required this.event});

  final DriftEventRecord event;

  @override
  State<DriftReplaySheet> createState() => _DriftReplaySheetState();
}

class _DriftReplaySheetState extends State<DriftReplaySheet> {
  double _progress = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _play() {
    _timer?.cancel();
    setState(() => _progress = 0);
    _timer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress = (_progress + 0.016).clamp(0, 1);
      });
      if (_progress >= 1) {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final beforeCents = widget.event.beforeCents;
    final afterCents = widget.event.afterCents;
    final hasData = beforeCents != null && afterCents != null;
    final liveCents = hasData ? beforeCents + ((afterCents - beforeCents) * _progress) : null;
    final delta = hasData ? afterCents - beforeCents : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Drift Replay #${widget.event.eventIndex + 1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Timestamp: ${_formatEpochTime(widget.event.confirmedAtMs)}'),
          Text('Snippet: ${widget.event.audioSnippetUri ?? 'Not attached'}'),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 12),
          if (!hasData)
            const Text('Incomplete replay data', style: TextStyle(color: Colors.red))
          else ...[
            Text('Before: ${beforeCents.toStringAsFixed(1)}c (MIDI ${widget.event.beforeMidi ?? '—'})'),
            Text('After: ${afterCents.toStringAsFixed(1)}c (MIDI ${widget.event.afterMidi ?? '—'})'),
            Text('Live replay: ${liveCents!.toStringAsFixed(1)}c • Δ ${delta! >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}c'),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: hasData ? _play : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play replay'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendSparkline extends StatelessWidget {
  const _TrendSparkline({required this.series, required this.selector, required this.color});

  final List<TrendPoint> series;
  final double Function(TrendPoint point) selector;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) {
      return const Center(child: Text('Need at least 2 sessions for trend chart.'));
    }
    return CustomPaint(
      painter: _SparklinePainter(
        values: series.map(selector).toList(growable: false),
        color: color,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), axisPaint);

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);
    final stepX = size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final normalized = (values[i] - minV) / span;
      final x = i * stepX;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    if (oldDelegate.color != color) return true;
    if (identical(oldDelegate.values, values)) return false;
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

class _WeaknessMapGrid extends StatelessWidget {
  const _WeaknessMapGrid({required this.cells});

  final List<WeaknessMapCell> cells;

  @override
  Widget build(BuildContext context) {
    final maxError = cells.map((c) => c.avgErrorCents).fold<double>(0, math.max);
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: cells.length,
      itemBuilder: (context, index) {
        final cell = cells[index];
        final intensity = maxError <= 0 ? 0.0 : (cell.avgErrorCents / maxError).clamp(0, 1);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Color.lerp(Colors.green.shade700, Colors.red.shade700, intensity),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${cell.note}${cell.octave}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${cell.avgErrorCents.toStringAsFixed(1)}c'),
              Text('${cell.attemptCount} attempts', style: const TextStyle(fontSize: 11)),
            ],
          ),
        );
      },
    );
  }
}

class _SessionTimeline extends StatelessWidget {
  const _SessionTimeline({required this.session, required this.driftEvents});

  final SessionRecord session;
  final List<DriftEventRecord> driftEvents;

  @override
  Widget build(BuildContext context) {
    if (session.durationMs <= 0) {
      return const Center(child: Text('Timeline unavailable.'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Container(height: 6, color: Colors.white12),
              ),
            ),
            for (final event in driftEvents)
              Positioned(
                left: ((event.confirmedAtMs - session.startedAtMs) / session.durationMs * constraints.maxWidth)
                    .clamp(0, constraints.maxWidth - 10),
                top: 20,
                child: const Icon(Icons.location_on, size: 18, color: Colors.orangeAccent),
              ),
            Positioned(
              left: 0,
              bottom: 0,
              child: Text(_formatEpochTime(session.startedAtMs)),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Text(_formatEpochTime(session.endedAtMs)),
            ),
          ],
        );
      },
    );
  }
}

String _formatDuration(int durationMs) {
  final seconds = durationMs ~/ 1000;
  final mm = (seconds ~/ 60).toString().padLeft(2, '0');
  final ss = (seconds % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

String _formatEpochTime(int epochMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final ss = dt.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}
}

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<Map<String, int>>(
        future: SessionRepository.instance.libraryCounts(),
        builder: (context, snapshot) {
          final counts = snapshot.data ?? const <String, int>{};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('LIBRARY', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Reference Tones'),
                subtitle: Text('Active exercise tone sets: ${counts['reference_tones'] ?? 0}'),
              ),
              ListTile(
                title: const Text('Mastery Archive'),
                subtitle: Text('Mastery history entries: ${counts['mastered_entries'] ?? 0}'),
              ),
              ListTile(
                title: const Text('Drift Replay Clips'),
                subtitle: Text('Recorded drift events available: ${counts['drift_replays'] ?? 0}'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<Map<String, String>>(
        future: SessionRepository.instance.settingsSummary(),
        builder: (context, snapshot) {
          final summary = snapshot.data ?? const <String, String>{};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('SETTINGS_ROOT', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(title: const Text('Pitch Detection'), subtitle: Text('Suggested profile: ${summary['detection_profile'] ?? 'Standard'}')),
              const ListTile(title: Text('Feedback & Representation'), subtitle: Text('Shape/color mapping editor and preview.')),
              const ListTile(title: Text('Audio'), subtitle: Text('Input route, reference output, latency diagnostics.')),
              ListTile(
                title: const Text('Training'),
                subtitle: Text(
                  'Assisted-attempt ratio: ${summary['assist_ratio'] ?? '0%'} • 30-day retention: ${summary['retention_30d'] ?? '0%'}',
                ),
              ),
              ListTile(
                title: const Text('Data & Privacy'),
                subtitle: Text('${summary['privacy'] ?? 'Local-only SQLite storage'} • Analytics coverage: ${summary['percentile_coverage'] ?? '0 mode/level groups'}'),
              ),
              const ListTile(title: Text('About'), subtitle: Text('Version, licenses and support links.')),
            ],
          );
        },
      ),
    );
  }
}

class LivePitchScreen extends StatefulWidget {
  const LivePitchScreen({super.key, required this.exercise, required this.config, required this.level});

  final ExerciseDefinition exercise;
  final ExerciseConfig config;
  final LevelId level;

  @override
  State<LivePitchScreen> createState() => _LivePitchScreenState();
}

class _LivePitchScreenState extends State<LivePitchScreen> {
  late final TrainingEngine _engine;
  final _bridge = NativeAudioBridge();
  StreamSubscription<DspFrame>? _sub;
  bool _replayOpen = false;
  int? _sessionStartMs;
  final List<double> _absErrors = <double>[];
  final List<double> _effectiveErrors = <double>[];
  int _driftCount = 0;
  int _activeTimeMs = 0;
  int _lockedTimeMs = 0;
  int? _lastFrameTimestampMs;
  int _lastDriftAfterTimestamp = -1;
  final List<DriftEventWrite> _driftEvents = <DriftEventWrite>[];
  final DriftSnippetRecorder _snippetRecorder = DriftSnippetRecorder();
  final List<Future<void>> _pendingSnippetWrites = <Future<void>>[];

  @override
  void initState() {
    super.initState();
    _engine = TrainingEngine(config: widget.config);
    _sub = _bridge.frames().listen((frame) {
      setState(() => _engine.onDspFrame(frame));
      _snippetRecorder.addFrame(frame);
      final stateId = _engine.state.id;
      final isTrainingActive = stateId != LivePitchStateId.idle &&
          stateId != LivePitchStateId.paused &&
          stateId != LivePitchStateId.completed;
      if (_sessionStartMs != null && isTrainingActive) {
        if (_lastFrameTimestampMs != null) {
          final deltaMs = math.max(0, frame.timestampMs - _lastFrameTimestampMs!);
          _activeTimeMs += deltaMs;
          if (stateId == LivePitchStateId.locked) {
            _lockedTimeMs += deltaMs;
          }
        }
        _lastFrameTimestampMs = frame.timestampMs;
      } else {
        _lastFrameTimestampMs = null;
      }

      if (isTrainingActive && _engine.state.effectiveError != null) {
        final effectiveError = _engine.state.effectiveError!;
        _effectiveErrors.add(effectiveError);
        _absErrors.add(effectiveError.abs());
      }
      final driftEvent = _engine.lastDriftEvent;
      if (isTrainingActive &&
          driftEvent != null &&
          driftEvent.after.timestampMs > _lastDriftAfterTimestamp) {
        _lastDriftAfterTimestamp = driftEvent.after.timestampMs;
        _driftCount += 1;
        final confirmedAtMs = DateTime.now().millisecondsSinceEpoch;
        _driftEvents.add(
          DriftEventWrite(
            eventIndex: _driftCount - 1,
            confirmedAtMs: confirmedAtMs,
            beforeMidi: driftEvent.before.nearestMidi,
            beforeCents: driftEvent.before.centsError,
            beforeFreqHz: driftEvent.before.freqHz,
            afterMidi: driftEvent.after.nearestMidi,
            afterCents: driftEvent.after.centsError,
            afterFreqHz: driftEvent.after.freqHz,
            audioSnippetUri: null,
          ),
        );
        _pendingSnippetWrites.add(_persistDriftSnippet(eventIndex: _driftCount - 1));
      }
      if (_engine.state.id == LivePitchStateId.driftConfirmed && !_replayOpen && widget.exercise.driftAwarenessMode) {
        _openReplay();
      }
    });
  }

  Future<void> _persistDriftSnippet({required int eventIndex}) async {
    final sessionStartMs = _sessionStartMs;
    if (sessionStartMs == null) {
      return;
    }
    try {
      final snippetPath = await _snippetRecorder.persistSnippet(
        sessionStartMs: sessionStartMs,
        eventIndex: eventIndex,
      );
      final absolutePath = snippetPath;
      if (!mounted) {
        return;
      }
      setState(() {
        final existing = _driftEvents[eventIndex];
        _driftEvents[eventIndex] = DriftEventWrite(
          eventIndex: existing.eventIndex,
          confirmedAtMs: existing.confirmedAtMs,
          beforeMidi: existing.beforeMidi,
          beforeCents: existing.beforeCents,
          beforeFreqHz: existing.beforeFreqHz,
          afterMidi: existing.afterMidi,
          afterCents: existing.afterCents,
          afterFreqHz: existing.afterFreqHz,
          audioSnippetUri: absolutePath,
        );
      });
    } catch (error) {
      debugPrint('Failed to persist drift snippet for event $eventIndex: $error');
    }
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

  Future<void> _persistSessionIfNeeded() async {
    if (_sessionStartMs == null || _absErrors.isEmpty) {
      return;
    }
    final endedAtMs = DateTime.now().millisecondsSinceEpoch;
    await Future.wait(_pendingSnippetWrites);
    final avgError = _absErrors.reduce((a, b) => a + b) / _absErrors.length;
    final signedMean = _effectiveErrors.reduce((a, b) => a + b) / _effectiveErrors.length;
    final variance = _effectiveErrors
            .map((e) => (e - signedMean) * (e - signedMean))
            .reduce((a, b) => a + b) /
        _effectiveErrors.length;
    final stdDev = math.sqrt(variance);
    final stability = (100 - (stdDev * 3)).clamp(0, 100).toDouble();
    final lockRatio = _activeTimeMs == 0 ? 0 : _lockedTimeMs / _activeTimeMs;
    final masteryThreshold = masteryThresholds[widget.level]!;
    final success = avgError <= masteryThreshold.avgErrorMax &&
        stdDev <= masteryThreshold.stabilityMax &&
        lockRatio >= masteryThreshold.lockRatioMin &&
        _driftCount <= masteryThreshold.driftCountMax;

    final sessionId = await SessionRepository.instance.recordSession(
      exerciseId: widget.exercise.id,
      modeLabel: _modeTitle(widget.exercise.mode),
      startedAtMs: _sessionStartMs!,
      endedAtMs: endedAtMs,
      avgErrorCents: avgError,
      stabilityScore: stability,
      driftCount: _driftCount,
    );
    await SessionRepository.instance.recordAttempt(
      sessionId: sessionId,
      exerciseId: widget.exercise.id,
      levelId: widget.level.name.toUpperCase(),
      assisted: false,
      success: success,
      targetNote: widget.config.targetNote,
      targetOctave: widget.config.targetOctave,
      avgErrorCents: avgError,
    );
    await SessionRepository.instance.recordDriftEvents(
      sessionId: sessionId,
      events: List<DriftEventWrite>.from(_driftEvents),
    );
    if (success) {
      await SessionRepository.instance.recordMastery(
        exerciseId: widget.exercise.id,
        levelId: widget.level.name.toUpperCase(),
        sourceSessionId: sessionId,
      );
    }
    _sessionStartMs = null;
    _absErrors.clear();
    _effectiveErrors.clear();
    _driftCount = 0;
    _activeTimeMs = 0;
    _lockedTimeMs = 0;
    _lastFrameTimestampMs = null;
    _lastDriftAfterTimestamp = -1;
    _driftEvents.clear();
    _pendingSnippetWrites.clear();
  }

  @override
  void dispose() {
    _persistSessionIfNeeded();
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
                ElevatedButton(
                  onPressed: () => setState(() {
                    if (_sessionStartMs == null) {
                      _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
                      _absErrors.clear();
                      _effectiveErrors.clear();
                      _driftCount = 0;
                      _activeTimeMs = 0;
                      _lockedTimeMs = 0;
                      _lastFrameTimestampMs = null;
                      _lastDriftAfterTimestamp = -1;
                      _driftEvents.clear();
                    }
                    _engine.onIntent(TrainingIntent.start);
                  }),
                  child: const Text('Start'),
                ),
                ElevatedButton(onPressed: () => setState(() => _engine.onIntent(TrainingIntent.pause)), child: const Text('Pause')),
                ElevatedButton(onPressed: () => setState(() => _engine.onIntent(TrainingIntent.resume)), child: const Text('Resume')),
                ElevatedButton(
                  onPressed: () async {
                    setState(() => _engine.onIntent(TrainingIntent.stop));
                    await _persistSessionIfNeeded();
                  },
                  child: const Text('Stop'),
                ),
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

String _midiToNoteLabel(int? midi) {
  if (midi == null) {
    return '—';
  }
  final note = _notes[midi % 12];
  final octave = (midi ~/ 12) - 1;
  return '$note$octave';
}

Color _pitchClassColor(int? midi) {
  if (midi == null) {
    return Colors.blueGrey;
  }
  final hues = [220.0, 205.0, 190.0, 170.0, 145.0, 95.0, 62.0, 40.0, 24.0, 0.0, 320.0, 275.0];
  return HSVColor.fromAHSV(1, hues[midi % 12], 0.72, 0.95).toColor();
}
