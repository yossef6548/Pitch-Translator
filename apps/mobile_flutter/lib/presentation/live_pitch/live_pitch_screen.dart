import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pt_contracts/pt_contracts.dart';

import '../../domain/exercises/exercise_catalog.dart';
import '../../domain/exercises/progression_engine.dart';
import '../../domain/session/session_evaluator.dart';
import 'live_pitch_controller.dart';
import 'live_pitch_view_model.dart';
import 'widgets/live_pitch_meter.dart';
import 'widgets/session_metrics_panel.dart';
import '../../app/router.dart';
import 'session_summary_screen.dart';

class LivePitchScreen extends StatefulWidget {
  const LivePitchScreen({
    super.key,
    required this.exercise,
    required this.level,
    required this.config,
    this.storeAnalytics = true,
    this.voicePromptsEnabled = false,
  });

  final ExerciseDefinition exercise;
  final LevelId level;
  final ExerciseConfig config;
  final bool storeAnalytics;
  final bool voicePromptsEnabled;

  @override
  State<LivePitchScreen> createState() => _LivePitchScreenState();
}

class _LivePitchScreenState extends State<LivePitchScreen>
    with WidgetsBindingObserver {
  late final LivePitchController _controller;
  final SessionEvaluator _sessionEvaluator = const SessionEvaluator();
  bool _didRouteToSummary = false;

  @override
  void initState() {
    super.initState();
    _controller = LivePitchController(
      exercise: widget.exercise,
      level: widget.level,
      config: widget.config,
      storeAnalytics: widget.storeAnalytics,
      voicePromptsEnabled: widget.voicePromptsEnabled,
    );
    WidgetsBinding.instance.addObserver(this);
    _controller.init();
  }

  Future<void> _handleAudioInterruptionSafely() async {
    try {
      await _controller.handleAudioInterruption();
    } catch (error, stackTrace) {
      // Prevent unhandled async exceptions during app backgrounding.
      debugPrint('Error handling audio interruption: $error');
      debugPrint('$stackTrace');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        _controller.viewModel.running) {
      unawaited(_handleAudioInterruptionSafely());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          final shouldRouteToSummary =
              vm.sessionStage == LivePitchSessionStage.completed &&
              vm.failureState == null;
          if (shouldRouteToSummary && !_didRouteToSummary) {
            _didRouteToSummary = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed(
                AppRoutes.sessionSummary,
                arguments: SessionSummaryArgs(
                  exercise: widget.exercise,
                  level: widget.level,
                  avgError: vm.avgErrorCents,
                  lockRatio: vm.lockRatio,
                  driftCount: vm.driftCount,
                  stability: vm.stabilityCents,
                  passed: _sessionEvaluator.passed(
                    SessionMetrics(
                      avgError: vm.avgErrorCents,
                      stability: vm.stabilityCents,
                      lockRatio: vm.lockRatio,
                      driftCount: vm.driftCount,
                    ),
                    widget.level,
                  ),
                ),
              );
            });
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target: ${widget.config.targetNote}${widget.config.targetOctave}',
                ),
                const SizedBox(height: 16),
                LivePitchMeter(
                  state: vm.uiState,
                  onWidthMeasured: _controller.setSemitoneWidthPxW,
                ),
                const SizedBox(height: 16),
                Text('State: ${vm.uiState.id.name}'),
                if (widget.config.showNumericOverlay)
                  Text('Cents: ${vm.uiState.displayCents} ${vm.uiState.arrow}'),
                const SizedBox(height: 16),
                if (vm.errorMessage != null) ...[
                  _FailureStateCard(
                    message: vm.errorMessage!,
                    failureState: vm.failureState,
                    onOpenSettings: _controller.openPermissionSettings,
                  ),
                  const SizedBox(height: 12),
                ],
                if (vm.sessionStage == LivePitchSessionStage.prePermission)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Microphone access is required for real-time pitch detection. '
                        'No audio is stored while tracking; only session metrics are saved.',
                      ),
                    ),
                  ),
                SessionMetricsPanel(
                  avgErrorCents: vm.avgErrorCents,
                  stabilityCents: vm.stabilityCents,
                  lockRatio: vm.lockRatio,
                  driftCount: vm.driftCount,
                  duration: vm.duration,
                ),
                const Spacer(),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: !vm.running &&
                              vm.sessionStage != LivePitchSessionStage.paused
                          ? () async {
                              try {
                                await _controller.startSession();
                              } catch (e, st) {
                                debugPrint('Error starting session: $e\n$st');
                              }
                            }
                          : null,
                      child: const Text('Start'),
                    ),
                    OutlinedButton(
                      onPressed: vm.running
                          ? () async {
                              try {
                                await _controller.pause();
                              } catch (e, st) {
                                debugPrint('Error pausing session: $e\n$st');
                              }
                            }
                          : null,
                      child: const Text('Pause'),
                    ),
                    OutlinedButton(
                      onPressed: !vm.running &&
                              vm.sessionStage == LivePitchSessionStage.paused
                          ? () async {
                              try {
                                await _controller.resume();
                              } catch (e, st) {
                                debugPrint('Error resuming session: $e\n$st');
                              }
                            }
                          : null,
                      child: const Text('Resume'),
                    ),
                    OutlinedButton(
                      onPressed: vm.sessionStage ==
                                  LivePitchSessionStage.running ||
                              vm.sessionStage == LivePitchSessionStage.paused
                          ? () async {
                              try {
                                await _controller.stopSession();
                              } catch (e, st) {
                                debugPrint('Error stopping session: $e\n$st');
                              }
                            }
                          : null,
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

class _FailureStateCard extends StatelessWidget {
  const _FailureStateCard({
    required this.message,
    required this.failureState,
    required this.onOpenSettings,
  });

  final String message;
  final LivePitchFailureState? failureState;
  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.errorContainer;
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (failureState == LivePitchFailureState.permissionDenied) ...[
              const SizedBox(height: 8),
              const Text(
                'If denied permanently:\n'
                '• Android: Settings → Apps → Pitch Translator → Permissions → Microphone\n'
                '• iOS: Settings → Pitch Translator → Microphone',
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  unawaited(onOpenSettings());
                },
                child: const Text('Open OS app settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
