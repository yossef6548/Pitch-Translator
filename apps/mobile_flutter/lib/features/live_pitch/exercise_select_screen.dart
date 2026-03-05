import 'package:flutter/material.dart';

import '../../analytics/session_repository.dart';
import '../../app/router.dart';
import '../../exercises/exercise_catalog.dart';

class ExerciseSelectScreen extends StatefulWidget {
  const ExerciseSelectScreen({super.key});

  @override
  State<ExerciseSelectScreen> createState() => _ExerciseSelectScreenState();
}

class _ExerciseSelectScreenState extends State<ExerciseSelectScreen> {
  final SessionRepository _sessionRepository = SessionRepository.instance;
  ProgressSnapshot _snapshot = const ProgressSnapshot();
  LevelId _selectedLevel = LevelId.l1;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final mastered = await _sessionRepository.masteredExerciseLevelKeys();
    if (!mounted) return;
    setState(() {
      _snapshot = ProgressSnapshot(mastered: mastered);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Pitch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Level'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: LevelId.values.map((level) {
              final unlocked = ExerciseCatalog.levelUnlocked(_snapshot, level);
              return ChoiceChip(
                label: Text(level.name.toUpperCase()),
                selected: _selectedLevel == level,
                onSelected: unlocked
                    ? (_) => setState(() => _selectedLevel = level)
                    : null,
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 16),
          ...ExerciseCatalog.modeOrder.map((mode) {
            final modeUnlocked = ExerciseCatalog.modeUnlocked(
              _snapshot,
              mode,
              _selectedLevel,
            );
            final modeExercises = ExerciseCatalog.all
                .where((exercise) => exercise.mode == mode)
                .toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mode.name, style: Theme.of(context).textTheme.titleMedium),
                ...modeExercises.map((exercise) {
                  final unlocked = modeUnlocked &&
                      ExerciseCatalog.levelUnlocked(
                          _snapshot, _selectedLevel) &&
                      exercise.unlockRule(_snapshot, _selectedLevel);
                  final lockedReason =
                      !ExerciseCatalog.levelUnlocked(_snapshot, _selectedLevel)
                          ? 'Locked: complete prior level mastery requirements.'
                          : !modeUnlocked
                              ? 'Locked: master previous mode at this level.'
                              : 'Locked: complete prerequisite exercise chain.';
                  return ListTile(
                    title: Text('${exercise.id} • ${exercise.name}'),
                    subtitle: Text(unlocked ? 'Unlocked' : lockedReason),
                    trailing: Icon(
                      unlocked ? Icons.play_arrow : Icons.lock,
                    ),
                    onTap: unlocked
                        ? () => Navigator.of(context).pushNamed(
                              AppRoutes.livePitch,
                              arguments: LivePitchRouteArgs(
                                exercise: exercise,
                                level: _selectedLevel,
                              ),
                            )
                        : null,
                  );
                }),
                const Divider(),
              ],
            );
          }),
        ],
      ),
    );
  }
}
