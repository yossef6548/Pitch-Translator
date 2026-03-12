import 'package:flutter/material.dart';

import '../../../core/time.dart';

class SessionMetricsPanel extends StatelessWidget {
  const SessionMetricsPanel({
    super.key,
    required this.avgErrorCents,
    required this.stabilityCents,
    required this.lockRatio,
    required this.driftCount,
    required this.duration,
  });

  final double avgErrorCents;
  final double stabilityCents;
  final double lockRatio;
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
            Text('Stability (std dev): ${stabilityCents.toStringAsFixed(1)} cents'),
            Text('Lock ratio: ${(lockRatio * 100).toStringAsFixed(1)}%'),
            Text('Drift count: $driftCount'),
            Text('Duration: ${formatDuration(duration)}'),
          ],
        ),
      ),
    );
  }
}
