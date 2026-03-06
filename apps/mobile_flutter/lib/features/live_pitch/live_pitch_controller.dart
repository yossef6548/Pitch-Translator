import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pt_contracts/pt_contracts.dart';

import '../../application/live_session/live_session_coordinator.dart';
import '../../application/live_session/live_session_failure.dart';
import '../../application/live_session/live_session_state.dart';
import '../../exercises/exercise_catalog.dart';
import 'live_pitch_view_model.dart';

class LivePitchController extends ChangeNotifier {
  LivePitchController({
    required this.exercise,
    required this.level,
    required this.config,
    LiveSessionCoordinator? coordinator,
  }) : _coordinator = coordinator ??
            LiveSessionCoordinator(
              exercise: exercise,
              level: level,
              config: config,
            );

  final ExerciseDefinition exercise;
  final LevelId level;
  final ExerciseConfig config;
  final LiveSessionCoordinator _coordinator;

  StreamSubscription<LiveSessionState>? _subscription;

  LivePitchViewModel _viewModel = const LivePitchViewModel.initial();
  LivePitchViewModel get viewModel => _viewModel;

  Future<void> init() async {
    _subscription ??= _coordinator.states.listen(_onState);
  }

  Future<void> startSession() => _coordinator.start();
  Future<void> pause() => _coordinator.pause();
  Future<void> resume() => _coordinator.resume();
  Future<void> stopSession() => _coordinator.stop();

  void setSemitoneWidthPxW(double width) {
    _coordinator.setSemitoneWidthPxW(width);
  }

  Future<void> handleAudioInterruption() async {
    await stopSession();
  }

  Future<bool> openPermissionSettings() {
    return openAppSettings();
  }

  void _onState(LiveSessionState state) {
    _viewModel = _viewModel.copyWith(
      running: state.stage == LiveSessionStage.running,
      uiState: state.uiState,
      sessionStage: _mapStage(state.stage),
      avgErrorCents: state.metrics.avgErrorCents,
      stabilityCents: state.metrics.stabilityCents,
      lockRatio: state.metrics.lockRatio,
      driftCount: state.metrics.driftCount,
      duration: Duration(milliseconds: state.metrics.activeDurationMs),
      failureState: _mapFailure(state.failure),
      errorMessage: state.errorMessage,
    );
    notifyListeners();
  }

  LivePitchSessionStage _mapStage(LiveSessionStage stage) {
    switch (stage) {
      case LiveSessionStage.idle:
      case LiveSessionStage.ready:
        return LivePitchSessionStage.ready;
      case LiveSessionStage.prePermission:
        return LivePitchSessionStage.prePermission;
      case LiveSessionStage.running:
        return LivePitchSessionStage.running;
      case LiveSessionStage.paused:
        return LivePitchSessionStage.paused;
      case LiveSessionStage.completed:
        return LivePitchSessionStage.completed;
    }
  }

  LivePitchFailureState? _mapFailure(LiveSessionFailure? failure) {
    switch (failure) {
      case LiveSessionFailure.permissionDenied:
        return LivePitchFailureState.permissionDenied;
      case LiveSessionFailure.noInputDetected:
        return LivePitchFailureState.noInputDetected;
      case LiveSessionFailure.unsupportedDevice:
        return LivePitchFailureState.unsupportedDevice;
      case LiveSessionFailure.audioInterrupted:
      case LiveSessionFailure.persistenceFailed:
      case LiveSessionFailure.unknown:
        return LivePitchFailureState.audioInterrupted;
      case null:
        return null;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_coordinator.dispose());
    super.dispose();
  }
}
