import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/exercises/exercise_catalog.dart';
import '../presentation/live_pitch/live_pitch_screen.dart';
import '../presentation/live_pitch/session_summary_screen.dart';
import 'shell.dart';

class AppRoutes {
  static const home = '/';
  static const train = '/train';
  static const analyze = '/analyze';
  static const livePitch = '/live-pitch';
  static const sessionSummary = '/session-summary';
}

class LivePitchRouteArgs {
  const LivePitchRouteArgs({required this.exercise, required this.level});

  final ExerciseDefinition exercise;
  final LevelId level;
}

class _LivePitchSettings {
  const _LivePitchSettings({
    required this.numericOverlay,
    required this.haptics,
    required this.storeAnalytics,
    required this.voicePrompts,
    required this.profile,
  });

  final bool numericOverlay;
  final bool haptics;
  final bool storeAnalytics;
  final bool voicePrompts;
  final String profile;
}

Future<_LivePitchSettings> _loadLivePitchSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return _LivePitchSettings(
    numericOverlay: prefs.getBool('settings.numeric_overlay') ?? true,
    haptics: prefs.getBool('settings.haptics') ?? true,
    storeAnalytics: prefs.getBool('settings.store_analytics') ?? true,
    voicePrompts: prefs.getBool('settings.voice_prompts') ?? false,
    profile: prefs.getString('settings.detection_profile') ?? 'Standard',
  );
}

ExerciseConfig _applyProfileConfig(
  ExerciseConfig base,
  _LivePitchSettings settings,
) {
  double toleranceMultiplier;
  double driftMultiplier;
  switch (settings.profile) {
    case 'Strict':
      toleranceMultiplier = 0.85;
      driftMultiplier = 0.9;
      break;
    case 'Relaxed':
      toleranceMultiplier = 1.2;
      driftMultiplier = 1.15;
      break;
    case 'Standard':
    default:
      toleranceMultiplier = 1.0;
      driftMultiplier = 1.0;
  }

  return ExerciseConfig(
    toleranceCents: base.toleranceCents * toleranceMultiplier,
    driftThresholdCents: base.driftThresholdCents * driftMultiplier,
    driftAwarenessMode: base.driftAwarenessMode,
    countdownMs: base.countdownMs,
    randomizeTargetWithinRange: base.randomizeTargetWithinRange,
    referenceToneEnabled: base.referenceToneEnabled,
    showNumericOverlay: settings.numericOverlay,
    shapeWarpingEnabled: base.shapeWarpingEnabled,
    colorFloodEnabled: base.colorFloodEnabled,
    hapticsEnabled: settings.haptics,
    targetNote: base.targetNote,
    targetOctave: base.targetOctave,
    randomizeMinNote: base.randomizeMinNote,
    randomizeMinOctave: base.randomizeMinOctave,
    randomizeMaxNote: base.randomizeMaxNote,
    randomizeMaxOctave: base.randomizeMaxOctave,
    referenceTimbre: base.referenceTimbre,
    referenceVolume: base.referenceVolume,
  );
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return MaterialPageRoute(builder: (_) => const AppShell());
    case AppRoutes.train:
      return MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 1));
    case AppRoutes.analyze:
      return MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 2));
    case AppRoutes.livePitch:
      final args = settings.arguments as LivePitchRouteArgs?;
      if (args == null) {
        return MaterialPageRoute(builder: (_) => const AppShell());
      }
      return MaterialPageRoute(
        builder: (_) => FutureBuilder<_LivePitchSettings>(
          future: _loadLivePitchSettings(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final loaded = snapshot.data!;
            final baseConfig = args.exercise.configForLevel(args.level);
            final config = _applyProfileConfig(baseConfig, loaded);
            return LivePitchScreen(
              exercise: args.exercise,
              level: args.level,
              config: config,
              storeAnalytics: loaded.storeAnalytics,
              voicePromptsEnabled: loaded.voicePrompts,
            );
          },
        ),
      );
    case AppRoutes.sessionSummary:
      final args = settings.arguments as SessionSummaryArgs?;
      if (args == null) {
        return MaterialPageRoute(builder: (_) => const AppShell());
      }
      return MaterialPageRoute(builder: (_) => SessionSummaryScreen(args: args));
    default:
      return MaterialPageRoute(builder: (_) => const AppShell());
  }
}
