import 'package:flutter/material.dart';

import '../../analytics/session_repository.dart';
import '../../app/router.dart';
import '../../domain/exercises/exercise_catalog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadHomeData();
  }

  void _retry() => setState(() => _future = _loadHomeData());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: FutureBuilder<_HomeData>(
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
                label: const Text('Retry loading home data'),
              ),
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ActionCard(
                title: 'Today\'s recommended exercise',
                subtitle:
                    '${data.recommended.name} • ${data.recommendedLevel.name.toUpperCase()}',
                icon: Icons.auto_awesome,
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.livePitch,
                  arguments: LivePitchRouteArgs(
                    exercise: data.recommended,
                    level: data.recommendedLevel,
                  ),
                ),
              ),
              if (data.latestSession != null)
                _ActionCard(
                  title: 'Continue last session',
                  subtitle:
                      '${data.latestSession!.exerciseId} • ${(data.latestSession!.lockRatio * 100).round()}% lock',
                  icon: Icons.play_arrow,
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.livePitch,
                    arguments: LivePitchRouteArgs(
                      exercise: ExerciseCatalog.byId(data.latestSession!.exerciseId),
                      level: LevelId.values.firstWhere(
                        (value) => value.name == data.latestSession!.levelId,
                        orElse: () => LevelId.l1,
                      ),
                    ),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insights),
                  title: const Text('Latest metrics snapshot'),
                  subtitle: Text(
                    'Error ${data.trends.avgErrorCents.toStringAsFixed(1)}¢ • '
                    'Stability ${data.trends.stabilityCents.toStringAsFixed(1)}¢ • '
                    'Lock ${(data.trends.lockRatio * 100).round()}%',
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.trending_down),
                  title: const Text('Recent drift events'),
                  subtitle: Text(
                    data.recentDriftEvents.isEmpty
                        ? 'No drift events captured yet.'
                        : data.recentDriftEvents
                            .take(2)
                            .map((e) => '${e.exerciseId} #${e.event.eventIndex + 1}')
                            .join(' • '),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickLaunch(
                    label: 'Train',
                    icon: Icons.school,
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.train),
                  ),
                  _QuickLaunch(
                    label: 'Analyze',
                    icon: Icons.analytics,
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.analyze),
                  ),
                  _QuickLaunch(
                    label: 'Live',
                    icon: Icons.mic,
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.livePitch,
                      arguments: LivePitchRouteArgs(
                        exercise: data.recommended,
                        level: data.recommendedLevel,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_HomeData> _loadHomeData() async {
    final repo = SessionRepository.instance;
    final mastered = await repo.masteredExerciseLevelKeys();
    final snapshot = ProgressSnapshot(mastered: mastered);

    final recommendedLevel = LevelId.values.firstWhere(
      (level) => ExerciseCatalog.levelUnlocked(snapshot, level),
      orElse: () => LevelId.l1,
    );
    final unlocked = ExerciseCatalog.unlocked(snapshot, recommendedLevel);
    final latest = await repo.latestSession();
    return _HomeData(
      recommended: unlocked.isEmpty ? ExerciseCatalog.all.first : unlocked.first,
      recommendedLevel: recommendedLevel,
      latestSession: latest,
      trends: await repo.recentTrends(),
      recentDriftEvents: await repo.recentDriftEvents(limit: 5),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.recommended,
    required this.recommendedLevel,
    required this.latestSession,
    required this.trends,
    required this.recentDriftEvents,
  });

  final ExerciseDefinition recommended;
  final LevelId recommendedLevel;
  final SessionRecord? latestSession;
  final TrendSnapshot trends;
  final List<DriftEventWithSessionRecord> recentDriftEvents;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}

class _QuickLaunch extends StatelessWidget {
  const _QuickLaunch({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
