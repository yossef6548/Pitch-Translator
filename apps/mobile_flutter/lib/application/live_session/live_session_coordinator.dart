import 'dart:async';
import 'dart:math' as math;

import 'package:permission_handler/permission_handler.dart';
import 'package:pt_contracts/pt_contracts.dart';

import '../../analytics/session_repository.dart';
import '../../audio/native_audio_bridge.dart';
import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../domain/exercises/exercise_catalog.dart';
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
  Timer? _firstFrameTimer;
  bool _firstFrameReceived = false;
  final List<double> _absErrors = <double>[];
  final List<double> _effectiveErrors = <double>[];
  final List<DriftEventWrite> _driftEvents = <DriftEventWrite>[];
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
    _frameSubscription = _bridge.frames().listen((frame) {
      if (!_firstFrameReceived) {
        _firstFrameReceived = true;
        _firstFrameTimer?.cancel();
        _firstFrameTimer = null;
      }
      _onFrame(frame);
    });
    _engine.onIntent(TrainingIntent.start);
    _emit(LiveSessionState(stage: LiveSessionStage.running, uiState: _engine.state));

    // Health check: if no frame arrives within the timeout, stop capture and
    // report noInputDetected so the UI can surface an actionable error.
    _firstFrameTimer = Timer(_bridge.firstFrameTimeout, () {
      // Guard: if stop/pause was called concurrently, _firstFrameTimer will
      // have been cancelled and nulled already; double-check stage to be safe.
      if (_state.stage != LiveSessionStage.running) return;
      _firstFrameTimer = null;
      _bridge.stop().then((_) async {
        await _frameSubscription?.cancel();
        _frameSubscription = null;
        _engine.onIntent(TrainingIntent.stop);
        _emit(const LiveSessionState(
          stage: LiveSessionStage.completed,
          failure: LiveSessionFailure.noInputDetected,
          errorMessage: 'No audio input detected. Check your microphone and try again.',
        ));
      }, onError: (Object error) {
        AppLogger.error('Failed to stop bridge during no-input timeout', error);
      });
    });
  }

  Future<void> pause() async {
    _firstFrameTimer?.cancel();
    _firstFrameTimer = null;
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
    _firstFrameTimer?.cancel();
    _firstFrameTimer = null;
    await _bridge.stop();
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    _engine.onIntent(TrainingIntent.stop);

    final metrics = _buildMetrics();
    final endedAtMs = DateTime.now().millisecondsSinceEpoch;
    final startedAtMs = endedAtMs - _activeDurationMs;

    try {
      final sessionId = await _sessionRepository.recordSession(
        exerciseId: exercise.id,
        modeLabel: exercise.mode.name,
        startedAtMs: startedAtMs,
        endedAtMs: endedAtMs,
        avgErrorCents: metrics.avgErrorCents,
        stabilityCents: metrics.stabilityCents,
        lockRatio: metrics.lockRatio,
        driftCount: metrics.driftCount,
      );

      await _sessionRepository.recordAttempt(
        sessionId: sessionId,
        exerciseId: exercise.id,
        levelId: level.name,
        assisted: false,
        success: metrics.lockRatio > 0,
        avgErrorCents: metrics.avgErrorCents,
      );

      if (_driftEvents.isNotEmpty) {
        await _sessionRepository.recordDriftEvents(
          sessionId: sessionId,
          events: _driftEvents,
        );
      }
    } catch (error) {
      AppLogger.error('Session persistence failure', error);
      _emit(LiveSessionState(
        stage: LiveSessionStage.completed,
        uiState: _engine.state,
        metrics: metrics,
        failure: LiveSessionFailure.persistenceFailed,
        errorMessage: 'Failed to persist session data.',
      ));
      throw SessionPersistenceError('Failed to persist session: $error');
    }

    _emit(LiveSessionState(
      stage: LiveSessionStage.completed,
      uiState: _engine.state,
      metrics: metrics,
    ));
  }

  void setSemitoneWidthPxW(double width) {
    _engine.setSemitoneWidthPxW(width);
  }

  Future<bool> openPermissionSettings() {
    return openAppSettings();
  }

  Future<void> dispose() async {
    _firstFrameTimer?.cancel();
    _firstFrameTimer = null;
    await _frameSubscription?.cancel();
    await _bridge.stop();
    await _bridge.dispose();
    await _stateController.close();
  }

  void _onFrame(DspFrame frame) {
    final prevDriftCount = _engine.confirmedDriftCount;
    _engine.onDspFrame(frame);

    // Accumulate newly-confirmed drift events for later persistence.
    if (_engine.confirmedDriftCount > prevDriftCount) {
      final event = _engine.lastDriftEvent;
      if (event != null) {
        _driftEvents.add(DriftEventWrite(
          eventIndex: _driftEvents.length,
          confirmedAtMs: frame.timestampMs,
          beforeMidi: event.beforeMidi,
          beforeCents: event.beforeCents,
          beforeFreqHz: event.before.freqHz,
          afterMidi: event.afterMidi,
          afterCents: event.afterCents,
          afterFreqHz: event.after.freqHz,
        ));
      }
    }

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
      driftCount: _engine.confirmedDriftCount,
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
    _driftEvents.clear();
    _firstFrameReceived = false;
    _firstFrameTimer?.cancel();
    _firstFrameTimer = null;
    _activeDurationMs = 0;
    _lockedDurationMs = 0;
    _lastFrameAtMs = null;
  }
}
