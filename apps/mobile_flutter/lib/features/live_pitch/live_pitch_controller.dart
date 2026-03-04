import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
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
  int? _startedAtFrameTimestampMs;
  int? _lastFrameAtMs;
  int? _segmentFrameBaseMs;
  int? _segmentEpochBaseMs;
  int _activeDurationMs = 0;
  int _lockedDurationMs = 0;
  final List<double> _absErrors = <double>[];
  final List<DriftEventWrite> _driftEvents = <DriftEventWrite>[];
  int _lastRecordedDriftTimestamp = -1;
  Completer<void>? _firstFrameCompleter;

  Future<void> init() async {
    AppLogger.info('Initializing live pitch controller frame subscription');
    _frameSubscription = _bridge.frames().listen(
      _onFrame,
      onError: (error) {
        AppLogger.error('Audio frame stream failed', error);
      },
    );
  }

  Future<void> startSession() async {
    if (_viewModel.sessionStage == LivePitchSessionStage.paused) {
      throw StateError(
        'Cannot start a new session while a session is paused. '
        'Resume or stop the current session first.',
      );
    }
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      AppLogger.warning('Microphone permission denied before session start');
      final isPermanent = permission.isPermanentlyDenied ||
          permission.isRestricted ||
          permission.isLimited;
      _viewModel = _viewModel.copyWith(
        running: false,
        sessionStage: LivePitchSessionStage.prePermission,
        failureState: LivePitchFailureState.permissionDenied,
        errorMessage: isPermanent
            ? 'Microphone access is permanently denied. Open app settings and enable microphone permission to continue.'
            : 'Microphone permission is required to start live pitch tracking.',
      );
      notifyListeners();
      throw AudioBridgeException(AudioBridgeFailure.permissionDenied);
    }

    _resetMetrics();
    _firstFrameCompleter = Completer<void>();
    try {
      AppLogger.info('Starting native audio bridge');
      await _bridge.start();
      await _firstFrameCompleter!.future.timeout(
        _bridge.firstFrameTimeout,
        onTimeout: () async {
          await _bridge.stop();
          throw AudioBridgeException(AudioBridgeFailure.noFramesTimeout);
        },
      );
      AppLogger.info('First frame received; transitioning to running session');
      _engine.onIntent(TrainingIntent.start);
      _viewModel = const LivePitchViewModel.initial().copyWith(
        running: true,
        uiState: _engine.state,
        sessionStage: LivePitchSessionStage.running,
        clearError: true,
        clearFailure: true,
      );
      notifyListeners();
    } on AudioBridgeException catch (error) {
      AppLogger.error('Failed to start session', error);
      _viewModel = _viewModel.copyWith(
        running: false,
        sessionStage: LivePitchSessionStage.ready,
        failureState: _toFailureState(error.failure),
        errorMessage: _toActionableMessage(error.failure),
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pause() async {
    await _bridge.stop();
    _engine.onIntent(TrainingIntent.pause);
    _viewModel = _viewModel.copyWith(
      running: false,
      uiState: _engine.state,
      sessionStage: LivePitchSessionStage.paused,
    );
    notifyListeners();
  }

  Future<void> resume() async {
    await _bridge.start();
    _engine.onIntent(TrainingIntent.resume);
    _viewModel = _viewModel.copyWith(
      running: true,
      uiState: _engine.state,
      sessionStage: LivePitchSessionStage.running,
      clearError: true,
      clearFailure: true,
    );
    notifyListeners();
  }

  Future<void> stopSession() async {
    AppLogger.info('Stopping live pitch session');
    AudioBridgeException? stopError;
    try {
      await _bridge.stop();
    } on AudioBridgeException catch (error) {
      stopError = error;
    }
    _engine.onIntent(TrainingIntent.stop);
    final startedAtMs = _startedAtMs;
    final endedAtMs = _resolveEndedAtMs(startedAtMs);
    _viewModel = _viewModel.copyWith(
      running: false,
      uiState: _engine.state,
      sessionStage: LivePitchSessionStage.completed,
    );
    notifyListeners();

    if (startedAtMs == null) {
      if (stopError != null) {
        throw stopError;
      }
      return;
    }

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
      AppLogger.error('Session persistence failure', error);
      throw SessionPersistenceError('Failed to persist session: $error');
    }

    if (stopError != null) {
      throw stopError;
    }
  }

  Future<void> handleAudioInterruption() async {
    _viewModel = _viewModel.copyWith(
      failureState: LivePitchFailureState.audioInterrupted,
      errorMessage:
          'Audio capture was interrupted by the OS or another app. The session was safely stopped and saved.',
    );
    notifyListeners();
    try {
      await stopSession();
    } on SessionPersistenceError catch (error) {
      _viewModel = _viewModel.copyWith(
        failureState: LivePitchFailureState.audioInterrupted,
        errorMessage:
            'Audio capture was interrupted and the session could not be saved: $error',
      );
      notifyListeners();
    } on AudioBridgeException catch (error) {
      _viewModel = _viewModel.copyWith(
        failureState: LivePitchFailureState.audioInterrupted,
        errorMessage:
            'Audio capture was interrupted and the audio session could not be cleanly stopped: $error',
      );
      notifyListeners();
    } catch (_) {
      // Swallow any unexpected errors to avoid propagating from a lifecycle callback.
    }
  }

  Future<bool> openPermissionSettings() {
    return openAppSettings();
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
      final isFirstFrame = _startedAtFrameTimestampMs == null;
      _startedAtFrameTimestampMs ??= frame.timestampMs;
      var isDspTimestampReset = false;
      if (_lastFrameAtMs != null) {
        isDspTimestampReset = frame.timestampMs < _lastFrameAtMs!;
        final delta = math.max(0, frame.timestampMs - _lastFrameAtMs!);
        _activeDurationMs += delta;
        if (_engine.state.id == LivePitchStateId.locked) {
          _lockedDurationMs += delta;
        }
      }
      _lastFrameAtMs = frame.timestampMs;
      if (isFirstFrame || isDspTimestampReset) {
        _segmentFrameBaseMs = frame.timestampMs;
        _segmentEpochBaseMs = _startedAtMs! + _activeDurationMs;
      }

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
            confirmedAtMs: _resolveFrameTimestampToEpoch(
              drift.after.timestampMs,
            ),
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

  int _resolveEndedAtMs(int? startedAtMs) {
    if (startedAtMs == null) return DateTime.now().millisecondsSinceEpoch;
    return startedAtMs + _activeDurationMs;
  }

  int _resolveFrameTimestampToEpoch(int frameTimestampMs) {
    final epochBase = _segmentEpochBaseMs;
    final frameBase = _segmentFrameBaseMs;
    if (epochBase == null || frameBase == null) {
      return DateTime.now().millisecondsSinceEpoch;
    }
    final elapsedMs = math.max(0, frameTimestampMs - frameBase);
    return epochBase + elapsedMs;
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

  LivePitchFailureState _toFailureState(AudioBridgeFailure failure) {
    switch (failure) {
      case AudioBridgeFailure.permissionDenied:
        return LivePitchFailureState.permissionDenied;
      case AudioBridgeFailure.noFramesTimeout:
        return LivePitchFailureState.noInputDetected;
      case AudioBridgeFailure.pluginUnavailable:
        return LivePitchFailureState.unsupportedDevice;
      case AudioBridgeFailure.audioFocusDenied:
      case AudioBridgeFailure.unknown:
        return LivePitchFailureState.audioInterrupted;
    }
  }

  void _resetMetrics() {
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    _startedAtFrameTimestampMs = null;
    _lastFrameAtMs = null;
    _segmentFrameBaseMs = null;
    _segmentEpochBaseMs = null;
    _activeDurationMs = 0;
    _lockedDurationMs = 0;
    _absErrors.clear();
    _driftEvents.clear();
    _lastRecordedDriftTimestamp = -1;
  }
}
