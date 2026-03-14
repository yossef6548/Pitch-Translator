import 'package:flutter/material.dart';

import '../../analytics/session_repository.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Future<_SessionDetailData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Session #${widget.sessionId}')),
      body: FutureBuilder<_SessionDetailData?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('Unable to load session details.'));
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: Text('${data.session.exerciseId} • ${data.session.modeLabel}'),
                  subtitle: Text(
                    'Error ${data.session.avgErrorCents.toStringAsFixed(1)}¢ • '
                    'Stability ${data.session.stabilityCents.toStringAsFixed(1)}¢ • '
                    'Lock ${(data.session.lockRatio * 100).round()}%',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Drift events', style: Theme.of(context).textTheme.titleMedium),
              if (data.events.isEmpty)
                const Card(child: ListTile(title: Text('No drift events captured for this session.'))),
              for (final event in data.events)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.graphic_eq),
                    title: Text('Event #${event.eventIndex + 1}'),
                    subtitle: Text(
                      'Before ${event.beforeCents?.toStringAsFixed(1) ?? '--'}¢ → '
                      'After ${event.afterCents?.toStringAsFixed(1) ?? '--'}¢',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<_SessionDetailData?> _load(int sessionId) async {
    final repo = SessionRepository.instance;
    final session = await repo.sessionById(sessionId);
    if (session == null) return null;
    final events = await repo.driftEventsForSession(sessionId);
    return _SessionDetailData(session: session, events: events);
  }
}

class _SessionDetailData {
  const _SessionDetailData({required this.session, required this.events});

  final SessionRecord session;
  final List<DriftEventRecord> events;
}
