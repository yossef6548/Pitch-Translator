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
  });

  final ExerciseDefinition exercise;
  final LevelId level;
  final double avgError;
  final double lockRatio;
  final int driftCount;
  final double stability;
}

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({super.key, required this.args});

  final SessionSummaryArgs args;

  bool get _passed => args.lockRatio >= 0.5 && args.avgError <= 35;

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
                _passed ? Icons.emoji_events : Icons.refresh,
                color: _passed ? Colors.green : Colors.orange,
              ),
              title: Text(_passed ? 'Pass' : 'Needs another attempt'),
              subtitle: Text('${args.exercise.name} • ${args.level.name.toUpperCase()}'),
            ),
          ),
          _metric('Average error', '${args.avgError.toStringAsFixed(1)}¢'),
          _metric('Stability', '${args.stability.toStringAsFixed(1)}¢'),
          _metric('Lock ratio', '${(args.lockRatio * 100).toStringAsFixed(0)}%'),
          _metric('Drift events', '${args.driftCount}'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.analyze,
              (route) => false,
            ),
            icon: const Icon(Icons.analytics),
            label: const Text('View in Analyze'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.train,
              (route) => false,
            ),
            icon: const Icon(Icons.school),
            label: const Text('Start next exercise'),
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
