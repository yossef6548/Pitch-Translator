import 'package:flutter/material.dart';

import '../../../core/time.dart';

class SessionMetricsPanel extends StatelessWidget {
  const SessionMetricsPanel({
    super.key,
    required this.avgErrorCents,
    required this.stabilityScore,
    required this.driftCount,
    required this.duration,
  });

  final double avgErrorCents;
  final double stabilityScore;
  final int driftCount;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Avg error: ${avgErrorCents.toStringAsFixed(1)} cents'),
            Text('Stability: ${stabilityScore.toStringAsFixed(1)}%'),
            Text('Drift count: $driftCount'),
            Text('Duration: ${formatDuration(duration)}'),
          ],
        ),
      ),
    );
  }
}
