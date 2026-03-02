import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pt_contracts/pt_contracts.dart';

import '../../exercises/exercise_catalog.dart';
import '../../analytics/session_repository.dart';
import '../../audio/native_audio_bridge.dart';
import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../training/training_engine.dart';
import 'live_pitch_view_model.dart';

class LivePitchController extends ChangeNotifier {
  LivePitchController({
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

  LivePitchViewModel _viewModel = const LivePitchViewModel.initial();
  LivePitchViewModel get viewModel => _viewModel;

  StreamSubscription<DspFrame>? _frameSubscription;
  int? _startedAtMs;
  int? _lastFrameAtMs;
  int _activeDurationMs = 0;
  int _lockedDurationMs = 0;
  final List<double> _absErrors = <double>[];
  final List<DriftEventWrite> _driftEvents = <DriftEventWrite>[];
  int _lastRecordedDriftTimestamp = -1;
  Completer<void>? _firstFrameCompleter;

  Future<void> init() async {
    _frameSubscription = _bridge.frames().listen(
      _onFrame,
      onError: (error) {
        AppLogger.error('Audio frame stream failed', error);
      },
    );
  }

  Future<void> startSession() async {
    _resetMetrics();
    _firstFrameCompleter = Completer<void>();
    try {
      await _bridge.start();
      await _firstFrameCompleter!.future.timeout(
        _bridge.firstFrameTimeout,
        onTimeout: () async {
          await _bridge.stop();
          throw AudioBridgeException(AudioBridgeFailure.noFramesTimeout);
        },
      );
      _engine.onIntent(TrainingIntent.start);
      _viewModel = const LivePitchViewModel.initial().copyWith(
        running: true,
        uiState: _engine.state,
        clearError: true,
      );
      notifyListeners();
    } on AudioBridgeException catch (error) {
      _viewModel = _viewModel.copyWith(
        running: false,
        errorMessage: _toActionableMessage(error.failure),
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pause() async {
    await _bridge.stop();
    _engine.onIntent(TrainingIntent.pause);
    _viewModel = _viewModel.copyWith(running: false, uiState: _engine.state);
    notifyListeners();
  }

  Future<void> resume() async {
    await _bridge.start();
    _engine.onIntent(TrainingIntent.resume);
    _viewModel = _viewModel.copyWith(
      running: true,
      uiState: _engine.state,
      clearError: true,
    );
    notifyListeners();
  }

  Future<void> stopSession() async {
    await _bridge.stop();
    _engine.onIntent(TrainingIntent.stop);
    final endedAtMs = DateTime.now().millisecondsSinceEpoch;
    final startedAtMs = _startedAtMs;
    _viewModel = _viewModel.copyWith(running: false, uiState: _engine.state);
    notifyListeners();

    if (startedAtMs == null) return;

    try {
      final avgError = _absErrors.isEmpty
          ? 0.0
          : _absErrors.reduce((a, b) => a + b) / _absErrors.length;
      final stability = _activeDurationMs == 0
          ? 0.0
          : (_lockedDurationMs / _activeDurationMs).clamp(0.0, 1.0) * 100.0;

      final sessionId = await _sessionRepository.recordSession(
        exerciseId: exercise.id,
        modeLabel: exercise.mode.name,
        startedAtMs: startedAtMs,
        endedAtMs: endedAtMs,
        avgErrorCents: avgError,
        stabilityScore: stability,
        driftCount: _driftEvents.length,
      );

      await _sessionRepository.recordAttempt(
        sessionId: sessionId,
        exerciseId: exercise.id,
        levelId: level.name,
        assisted: false,
        success: _driftEvents.isEmpty,
        targetNote: config.targetNote,
        targetOctave: config.targetOctave,
        avgErrorCents: avgError,
      );

      await _sessionRepository.recordDriftEvents(
        sessionId: sessionId,
        events: _driftEvents,
      );
      _startedAtMs = null;
    } catch (error) {
      throw SessionPersistenceError('Failed to persist session: $error');
    }
  }

  @override
  void dispose() {
    unawaited(_frameSubscription?.cancel());
    unawaited(_bridge.stop());
    unawaited(_bridge.dispose());
    super.dispose();
  }

  void _onFrame(DspFrame frame) {
    if (_firstFrameCompleter != null && !_firstFrameCompleter!.isCompleted) {
      _firstFrameCompleter!.complete();
    }
    _engine.onDspFrame(frame);

    if (_viewModel.running) {
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
      }

      final drift = _engine.lastDriftEvent;
      if (drift != null &&
          drift.after.timestampMs > _lastRecordedDriftTimestamp) {
        _lastRecordedDriftTimestamp = drift.after.timestampMs;
        _driftEvents.add(
          DriftEventWrite(
            eventIndex: _driftEvents.length,
            confirmedAtMs: DateTime.now().millisecondsSinceEpoch,
            beforeMidi: drift.before.nearestMidi,
            beforeCents: drift.before.centsError,
            beforeFreqHz: drift.before.freqHz,
            afterMidi: drift.after.nearestMidi,
            afterCents: drift.after.centsError,
            afterFreqHz: drift.after.freqHz,
          ),
        );
      }
    }

    final avgError = _absErrors.isEmpty
        ? 0.0
        : _absErrors.reduce((a, b) => a + b) / _absErrors.length;
    final stability = _activeDurationMs == 0
        ? 0.0
        : (_lockedDurationMs / _activeDurationMs).clamp(0.0, 1.0) * 100.0;
    _viewModel = _viewModel.copyWith(
      uiState: _engine.state,
      avgErrorCents: avgError,
      stabilityScore: stability,
      driftCount: _driftEvents.length,
      duration: Duration(milliseconds: _activeDurationMs),
    );
    notifyListeners();
  }

  String _toActionableMessage(AudioBridgeFailure failure) {
    switch (failure) {
      case AudioBridgeFailure.permissionDenied:
        return 'Microphone permission is denied. Enable it in system settings and retry.';
      case AudioBridgeFailure.noFramesTimeout:
        return 'Audio started but no frames arrived. Check mic availability, close other audio apps, then retry.';
      case AudioBridgeFailure.audioFocusDenied:
        return 'Another app has exclusive audio focus. Pause other media/recorders and retry.';
      case AudioBridgeFailure.pluginUnavailable:
        return 'Native audio engine is unavailable on this build. Restart the app or reinstall the latest version.';
      case AudioBridgeFailure.unknown:
        return 'Unexpected audio error. Restart the app and try again.';
    }
  }

  void _resetMetrics() {
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    _lastFrameAtMs = null;
    _activeDurationMs = 0;
    _lockedDurationMs = 0;
    _absErrors.clear();
    _driftEvents.clear();
    _lastRecordedDriftTimestamp = -1;
  }
}
