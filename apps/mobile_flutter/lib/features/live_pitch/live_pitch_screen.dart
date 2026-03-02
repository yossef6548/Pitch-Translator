import 'package:flutter/material.dart';
import 'package:pt_contracts/pt_contracts.dart';

import '../../exercises/exercise_catalog.dart';
import 'live_pitch_controller.dart';
import 'widgets/live_pitch_meter.dart';
import 'widgets/session_metrics_panel.dart';

class LivePitchScreen extends StatefulWidget {
  const LivePitchScreen({
    super.key,
    required this.exercise,
    required this.level,
    required this.config,
  });

  final ExerciseDefinition exercise;
  final LevelId level;
  final ExerciseConfig config;

  @override
  State<LivePitchScreen> createState() => _LivePitchScreenState();
}

class _LivePitchScreenState extends State<LivePitchScreen> {
  late final LivePitchController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LivePitchController(
      exercise: widget.exercise,
      level: widget.level,
      config: widget.config,
    );
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Live Pitch • ${widget.exercise.id}')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final vm = _controller.viewModel;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target: ${widget.config.targetNote}${widget.config.targetOctave}',
                ),
                const SizedBox(height: 16),
                LivePitchMeter(state: vm.uiState),
                const SizedBox(height: 16),
                Text('State: ${vm.uiState.id.name}'),
                Text('Cents: ${vm.uiState.displayCents} ${vm.uiState.arrow}'),
                const SizedBox(height: 16),
                if (vm.errorMessage != null) ...[
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(vm.errorMessage!),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SessionMetricsPanel(
                  avgErrorCents: vm.avgErrorCents,
                  stabilityScore: vm.stabilityScore,
                  driftCount: vm.driftCount,
                  duration: vm.duration,
                ),
                const Spacer(),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () async {
                        try {
                          await _controller.startSession();
                        } catch (e, st) {
                          debugPrint('Error starting session: $e\n$st');
                        }
                      },
                      child: const Text('Start'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await _controller.pause();
                        } catch (e, st) {
                          debugPrint('Error pausing session: $e\n$st');
                        }
                      },
                      child: const Text('Pause'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await _controller.resume();
                        } catch (e, st) {
                          debugPrint('Error resuming session: $e\n$st');
                        }
                      },
                      child: const Text('Resume'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await _controller.stopSession();
                        } catch (e, st) {
                          debugPrint('Error stopping session: $e\n$st');
                        }
                      },
                      child: const Text('Stop'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
