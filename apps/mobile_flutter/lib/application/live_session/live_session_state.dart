import 'package:pt_contracts/pt_contracts.dart';

import 'live_session_failure.dart';
import 'live_session_metrics.dart';

enum LiveSessionStage { idle, prePermission, ready, running, paused, completed }

class LiveSessionState {
  const LiveSessionState({
    this.stage = LiveSessionStage.idle,
    this.uiState = const LivePitchUiState.idle(),
    this.metrics = const LiveSessionMetrics(),
    this.failure,
    this.errorMessage,
  });

  final LiveSessionStage stage;
  final LivePitchUiState uiState;
  final LiveSessionMetrics metrics;
  final LiveSessionFailure? failure;
  final String? errorMessage;
}
