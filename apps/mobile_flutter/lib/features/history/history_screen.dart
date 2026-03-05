import 'package:flutter/material.dart';

import '../../analytics/session_repository.dart';
import '../../core/time.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session History')),
      body: FutureBuilder<List<SessionRecord>>(
        future: SessionRepository.instance.recentSessions(),
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? const <SessionRecord>[];
          if (sessions.isEmpty) {
            return const Center(child: Text('No sessions yet.'));
          }

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return ListTile(
                title: Text('${session.exerciseId} • ${session.modeLabel}'),
                subtitle: Text(
                  'Avg ${session.avgErrorCents.toStringAsFixed(1)}c • Drift ${session.driftCount}',
                ),
                trailing: Text(formatDuration(durationBetweenMs(session.startedAtMs, session.endedAtMs))),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SessionDetailsScreen(session: session),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SessionDetailsScreen extends StatelessWidget {
  const SessionDetailsScreen({super.key, required this.session});

  final SessionRecord session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: const Text('Exercise'), subtitle: Text(session.exerciseId)),
          ListTile(title: const Text('Mode'), subtitle: Text(session.modeLabel)),
          ListTile(title: const Text('Avg Error'), subtitle: Text('${session.avgErrorCents.toStringAsFixed(1)} cents')),
          ListTile(title: const Text('Stability (std dev)'), subtitle: Text('${session.stabilityCents.toStringAsFixed(1)} cents')),
          ListTile(title: const Text('Lock ratio'), subtitle: Text('${(session.lockRatio * 100).toStringAsFixed(1)}%')),
          ListTile(title: const Text('Drift Events'), subtitle: Text('${session.driftCount}')),
          ListTile(
            title: const Text('Duration'),
            subtitle: Text(
              formatDuration(durationBetweenMs(session.startedAtMs, session.endedAtMs)),
            ),
          ),
        ],
      ),
    );
  }
}
