import 'package:pt_contracts/pt_contracts.dart';

class LivePitchViewModel {
  const LivePitchViewModel({
    required this.uiState,
    required this.avgErrorCents,
    required this.stabilityScore,
    required this.driftCount,
    required this.duration,
    required this.running,
  });

  const LivePitchViewModel.initial()
      : uiState = const LivePitchUiState.idle(),
        avgErrorCents = 0,
        stabilityScore = 0,
        driftCount = 0,
        duration = Duration.zero,
        running = false;

  final LivePitchUiState uiState;
  final double avgErrorCents;
  final double stabilityScore;
  final int driftCount;
  final Duration duration;
  final bool running;

  LivePitchViewModel copyWith({
    LivePitchUiState? uiState,
    double? avgErrorCents,
    double? stabilityScore,
    int? driftCount,
    Duration? duration,
    bool? running,
  }) {
    return LivePitchViewModel(
      uiState: uiState ?? this.uiState,
      avgErrorCents: avgErrorCents ?? this.avgErrorCents,
      stabilityScore: stabilityScore ?? this.stabilityScore,
      driftCount: driftCount ?? this.driftCount,
      duration: duration ?? this.duration,
      running: running ?? this.running,
    );
  }
}
