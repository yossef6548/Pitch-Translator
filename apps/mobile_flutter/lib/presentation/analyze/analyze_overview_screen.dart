import 'package:flutter/material.dart';

import '../../analytics/session_repository.dart';
import 'session_detail_screen.dart';

class AnalyzeOverviewScreen extends StatefulWidget {
  const AnalyzeOverviewScreen({super.key});

  @override
  State<AnalyzeOverviewScreen> createState() => _AnalyzeOverviewScreenState();
}

class _AnalyzeOverviewScreenState extends State<AnalyzeOverviewScreen> {
  late Future<_AnalyzeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  void _retry() => setState(() => _future = _loadData());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analyze')),
      body: FutureBuilder<_AnalyzeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry analyze loading'),
              ),
            );
          }
          final data = snapshot.data!;
          if (data.sessions.isEmpty) {
            return const Center(child: Text('No sessions yet. Complete a session to unlock analytics.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Retention snapshot'),
                  subtitle: Text(
                    'Mastered ${data.retention.masteredCount} • '
                    '7d ${(data.retention.retained7DayRatio * 100).round()}% • '
                    '30d ${(data.retention.retained30DayRatio * 100).round()}%',
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Trend series'),
                  subtitle: Text('Points: ${data.trend.length}'),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Weakness heatmap data'),
                  subtitle: Text('${data.weakness.length} note/octave cells tracked'),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Mode-level percentiles'),
                  subtitle: Text('${data.percentiles.length} groups available'),
                ),
              ),
              const SizedBox(height: 8),
              Text('Recent sessions', style: Theme.of(context).textTheme.titleMedium),
              for (final session in data.sessions)
                Card(
                  child: ListTile(
                    title: Text('${session.exerciseId} • ${session.modeLabel}'),
                    subtitle: Text(
                      'Error ${session.avgErrorCents.toStringAsFixed(1)}¢ • '
                      'Lock ${(session.lockRatio * 100).round()}% • '
                      'Drift ${session.driftCount}',
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(sessionId: session.id),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<_AnalyzeData> _loadData() async {
    final repo = SessionRepository.instance;
    return _AnalyzeData(
      sessions: await repo.recentSessions(),
      trend: await repo.trendSeries(),
      weakness: await repo.weaknessMap(),
      drift: await repo.recentDriftEvents(limit: 10),
      retention: await repo.retentionSnapshot(),
      percentiles: await repo.modeLevelPercentiles(),
    );
  }
}

class _AnalyzeData {
  const _AnalyzeData({
    required this.sessions,
    required this.trend,
    required this.weakness,
    required this.drift,
    required this.retention,
    required this.percentiles,
  });

  final List<SessionRecord> sessions;
  final List<TrendPoint> trend;
  final List<WeaknessMapCell> weakness;
  final List<DriftEventWithSessionRecord> drift;
  final RetentionSnapshot retention;
  final List<ModeLevelPercentile> percentiles;
}
