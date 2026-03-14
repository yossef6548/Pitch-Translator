import 'package:flutter/material.dart';

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
        builder: (_) => LivePitchScreen(
          exercise: args.exercise,
          level: args.level,
          config: args.exercise.configForLevel(args.level),
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
