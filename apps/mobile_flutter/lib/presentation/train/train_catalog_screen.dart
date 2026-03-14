import 'package:flutter/material.dart';

import '../../analytics/session_repository.dart';
import '../../app/router.dart';
import '../../domain/exercises/exercise_catalog.dart';
import '../../domain/exercises/progress_snapshot.dart';

class TrainCatalogScreen extends StatelessWidget {
  const TrainCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Train')),
      body: FutureBuilder<ProgressSnapshot>(
        future: _loadProgress(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load progression.'));
          }
          final progress = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final level in LevelId.values) ...[
                _LevelSection(level: level, progress: progress),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<ProgressSnapshot> _loadProgress() async {
    final mastered = await SessionRepository.instance.masteredExerciseLevelKeys();
    return ProgressSnapshot(mastered: mastered);
  }
}

class _LevelSection extends StatelessWidget {
  const _LevelSection({required this.level, required this.progress});

  final LevelId level;
  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final levelUnlocked = ExerciseCatalog.levelUnlocked(progress, level);
    if (!levelUnlocked) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.lock),
          title: Text('Level ${level.name.toUpperCase()}'),
          subtitle: const Text('Complete earlier level mastery to unlock.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Level ${level.name.toUpperCase()}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final mode in ExerciseCatalog.modeOrder)
          _ModeGroup(mode: mode, level: level, progress: progress),
      ],
    );
  }
}

class _ModeGroup extends StatelessWidget {
  const _ModeGroup({required this.mode, required this.level, required this.progress});

  final ModeId mode;
  final LevelId level;
  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final modeUnlocked = ExerciseCatalog.modeUnlocked(progress, mode, level);
    final exercises = ExerciseCatalog.all.where((e) => e.mode == mode).toList();

    return ExpansionTile(
      initiallyExpanded: modeUnlocked,
      leading: Icon(modeUnlocked ? Icons.tune : Icons.lock),
      title: Text(mode.name.toUpperCase()),
      subtitle: Text(modeUnlocked ? 'Available' : 'Locked'),
      children: [
        for (final exercise in exercises)
          _ExerciseTile(exercise: exercise, level: level, progress: progress, modeUnlocked: modeUnlocked),
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.level,
    required this.progress,
    required this.modeUnlocked,
  });

  final ExerciseDefinition exercise;
  final LevelId level;
  final ProgressSnapshot progress;
  final bool modeUnlocked;

  @override
  Widget build(BuildContext context) {
    final unlocked = modeUnlocked && exercise.unlockRule(progress, level);
    final mastered = progress.isMastered(exercise.id, level);
    final config = exercise.configForLevel(level);

    return ListTile(
      leading: Icon(mastered ? Icons.check_circle : (unlocked ? Icons.play_arrow : Icons.lock)),
      title: Text(exercise.name),
      subtitle: Text(
        'ID ${exercise.id} • tol ${config.toleranceCents.round()}¢ • drift ${config.driftThresholdCents.round()}¢',
      ),
      trailing: mastered ? const Chip(label: Text('Mastered')) : null,
      onTap: !unlocked
          ? null
          : () => Navigator.of(context).pushNamed(
                AppRoutes.livePitch,
                arguments: LivePitchRouteArgs(exercise: exercise, level: level),
              ),
    );
  }
}
