import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../domain/exercises/exercise_catalog.dart';

class SessionSummaryArgs {
  const SessionSummaryArgs({
    required this.exercise,
    required this.level,
    required this.avgError,
    required this.lockRatio,
    required this.driftCount,
    required this.stability,
    required this.passed,
  });

  final ExerciseDefinition exercise;
  final LevelId level;
  final double avgError;
  final double lockRatio;
  final int driftCount;
  final double stability;
  final bool passed;
}

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({super.key, required this.args});

  final SessionSummaryArgs args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Summary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                args.passed ? Icons.emoji_events : Icons.refresh,
                color: args.passed ? Colors.green : Colors.orange,
              ),
              title: Text(args.passed ? 'Pass' : 'Needs another attempt'),
              subtitle: Text('${args.exercise.name} • ${args.level.name.toUpperCase()}'),
            ),
          ),
          _metric('Average error', '${args.avgError.toStringAsFixed(1)}¢'),
          _metric('Stability', '${args.stability.toStringAsFixed(1)}¢'),
          _metric('Lock ratio', '${(args.lockRatio * 100).toStringAsFixed(0)}%'),
          _metric('Drift events', '${args.driftCount}'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushReplacementNamed(
              AppRoutes.livePitch,
              arguments: LivePitchRouteArgs(exercise: args.exercise, level: args.level),
            ),
            icon: const Icon(Icons.replay),
            label: const Text('Retry exercise'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.train),
            icon: const Icon(Icons.skip_next),
            label: const Text('Next exercise'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.analyze),
            icon: const Icon(Icons.analytics),
            label: const Text('View analytics'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.home,
              (route) => false,
            ),
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Card(
      child: ListTile(title: Text(label), trailing: Text(value)),
    );
  }
}
