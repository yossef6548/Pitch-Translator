import 'package:pt_contracts/pt_contracts.dart';

enum LivePitchSessionStage { prePermission, ready, running, paused, completed }

enum LivePitchFailureState {
  permissionDenied,
  noInputDetected,
  unsupportedDevice,
  audioInterrupted,
}

class LivePitchViewModel {
  const LivePitchViewModel({
    required this.uiState,
    required this.avgErrorCents,
    required this.stabilityCents,
    required this.lockRatio,
    required this.driftCount,
    required this.duration,
    required this.running,
    required this.errorMessage,
    required this.sessionStage,
    required this.failureState,
  });

  const LivePitchViewModel.initial()
    : uiState = const LivePitchUiState.idle(),
      avgErrorCents = 0,
      stabilityCents = 0,
      lockRatio = 0,
      driftCount = 0,
      duration = Duration.zero,
      running = false,
      errorMessage = null,
      sessionStage = LivePitchSessionStage.prePermission,
      failureState = null;

  final LivePitchUiState uiState;
  final double avgErrorCents;
  final double stabilityCents;
  final double lockRatio;
  final int driftCount;
  final Duration duration;
  final bool running;
  final String? errorMessage;
  final LivePitchSessionStage sessionStage;
  final LivePitchFailureState? failureState;

  LivePitchViewModel copyWith({
    LivePitchUiState? uiState,
    double? avgErrorCents,
    double? stabilityCents,
    double? lockRatio,
    int? driftCount,
    Duration? duration,
    bool? running,
    String? errorMessage,
    LivePitchSessionStage? sessionStage,
    LivePitchFailureState? failureState,
    bool clearError = false,
    bool clearFailure = false,
  }) {
    return LivePitchViewModel(
      uiState: uiState ?? this.uiState,
      avgErrorCents: avgErrorCents ?? this.avgErrorCents,
      stabilityCents: stabilityCents ?? this.stabilityCents,
      lockRatio: lockRatio ?? this.lockRatio,
      driftCount: driftCount ?? this.driftCount,
      duration: duration ?? this.duration,
      running: running ?? this.running,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      sessionStage: sessionStage ?? this.sessionStage,
      failureState: clearFailure ? null : (failureState ?? this.failureState),
    );
  }
}
