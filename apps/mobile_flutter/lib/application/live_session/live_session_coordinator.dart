import 'dart:async';
import 'dart:math' as math;

import 'package:permission_handler/permission_handler.dart';
import 'package:pt_contracts/pt_contracts.dart';

import '../../analytics/session_repository.dart';
import '../../audio/native_audio_bridge.dart';
import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../exercises/exercise_catalog.dart';
import '../../training/training_engine.dart';
import 'live_session_failure.dart';
import 'live_session_metrics.dart';
import 'live_session_state.dart';

class LiveSessionCoordinator {
  LiveSessionCoordinator({
    required this.exercise,
    required this.level,
    required this.config,
    NativeAudioBridge? bridge,
    TrainingEngine? engine,
    SessionRepository? sessionRepository,
  })  : _bridge = bridge ?? NativeAudioBridge(),
        _engine = engine ?? TrainingEngine(config: config),
        _sessionRepository = sessionRepository ?? SessionRepository.instance;

  final ExerciseDefinition exercise;
  final LevelId level;
  final ExerciseConfig config;
  final NativeAudioBridge _bridge;
  final TrainingEngine _engine;
  final SessionRepository _sessionRepository;

  final _stateController = StreamController<LiveSessionState>.broadcast();
  LiveSessionState _state = const LiveSessionState(stage: LiveSessionStage.ready);

  Stream<LiveSessionState> get states => _stateController.stream;
  LiveSessionState get state => _state;

  StreamSubscription<DspFrame>? _frameSubscription;
  final List<double> _absErrors = <double>[];
  final List<double> _effectiveErrors = <double>[];
  int _activeDurationMs = 0;
  int _lockedDurationMs = 0;
  int? _lastFrameAtMs;

  void _emit(LiveSessionState value) {
    _state = value;
    _stateController.add(value);
  }

  Future<void> start() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      _emit(const LiveSessionState(
        stage: LiveSessionStage.prePermission,
        failure: LiveSessionFailure.permissionDenied,
        errorMessage: 'Microphone permission is required to start live pitch tracking.',
      ));
      throw AudioBridgeException(AudioBridgeFailure.permissionDenied);
    }

    _resetMetrics();
    await _bridge.start();
    _frameSubscription = _bridge.frames().listen(_onFrame);
    _engine.onIntent(TrainingIntent.start);
    _emit(LiveSessionState(stage: LiveSessionStage.running, uiState: _engine.state));
  }

  Future<void> pause() async {
    await _bridge.stop();
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    _engine.onIntent(TrainingIntent.pause);
    _emit(LiveSessionState(
      stage: LiveSessionStage.paused,
      uiState: _engine.state,
      metrics: _buildMetrics(),
    ));
  }

  Future<void> resume() async {
    await _bridge.start();
    _frameSubscription = _bridge.frames().listen(_onFrame);
    _engine.onIntent(TrainingIntent.resume);
    _emit(LiveSessionState(
      stage: LiveSessionStage.running,
      uiState: _engine.state,
      metrics: _buildMetrics(),
    ));
  }

  Future<void> stop() async {
    await _bridge.stop();
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    _engine.onIntent(TrainingIntent.stop);

    try {
      await _sessionRepository.recordSession(
        exerciseId: exercise.id,
        modeLabel: exercise.mode.name,
        startedAtMs: DateTime.now().millisecondsSinceEpoch - _activeDurationMs,
        endedAtMs: DateTime.now().millisecondsSinceEpoch,
        avgErrorCents: _buildMetrics().avgErrorCents,
        stabilityCents: _buildMetrics().stabilityCents,
        lockRatio: _buildMetrics().lockRatio,
        driftCount: _buildMetrics().driftCount,
      );
    } catch (error) {
      AppLogger.error('Session persistence failure', error);
      throw SessionPersistenceError('Failed to persist session: $error');
    }

    _emit(LiveSessionState(
      stage: LiveSessionStage.completed,
      uiState: _engine.state,
      metrics: _buildMetrics(),
    ));
  }

  Future<void> dispose() async {
    await _frameSubscription?.cancel();
    await _bridge.stop();
    await _bridge.dispose();
    await _stateController.close();
  }

  void _onFrame(DspFrame frame) {
    _engine.onDspFrame(frame);
    if (_lastFrameAtMs != null) {
      final delta = math.max(0, frame.timestampMs - _lastFrameAtMs!);
      _activeDurationMs += delta;
      if (_engine.state.id == LivePitchStateId.locked) {
        _lockedDurationMs += delta;
      }
    }
    _lastFrameAtMs = frame.timestampMs;

    final effectiveError = _engine.state.effectiveError;
    if (effectiveError != null) {
      _absErrors.add(effectiveError.abs());
      _effectiveErrors.add(effectiveError);
    }

    _emit(LiveSessionState(
      stage: LiveSessionStage.running,
      uiState: _engine.state,
      metrics: _buildMetrics(),
    ));
  }

  LiveSessionMetrics _buildMetrics() {
    final avgError = _absErrors.isEmpty
        ? 0.0
        : _absErrors.reduce((a, b) => a + b) / _absErrors.length;
    final stability = _stdDev(_effectiveErrors);
    final lockRatio = _activeDurationMs == 0
        ? 0.0
        : (_lockedDurationMs / _activeDurationMs).clamp(0.0, 1.0);
    return LiveSessionMetrics(
      avgErrorCents: avgError,
      stabilityCents: stability,
      lockRatio: lockRatio,
      driftCount: _engine.lastDriftEvent == null ? 0 : 1,
      activeDurationMs: _activeDurationMs,
    );
  }

  double _stdDev(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((value) => (value - mean) * (value - mean)).reduce((a, b) => a + b) /
            values.length;
    return math.sqrt(variance);
  }

  void _resetMetrics() {
    _absErrors.clear();
    _effectiveErrors.clear();
    _activeDurationMs = 0;
    _lockedDurationMs = 0;
    _lastFrameAtMs = null;
  }
}
