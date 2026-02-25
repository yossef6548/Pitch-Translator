import 'dart:convert';

import 'package:pt_contracts/pt_contracts.dart';

import '../training/training_engine.dart';

class ReplayHarnessResult {
  final List<LivePitchStateId> visitedStates;
  final List<ReplayTransition> transitions;
  final LivePitchUiState finalState;

  const ReplayHarnessResult({
    required this.visitedStates,
    required this.transitions,
    required this.finalState,
  });

  bool visited(LivePitchStateId state) => visitedStates.contains(state);

  ReplayTransition? firstTransitionTo(LivePitchStateId state) {
    for (final transition in transitions) {
      if (transition.to == state) return transition;
    }
    return null;
  }
}

class ReplayTransition {
  final int timestampMs;
  final LivePitchStateId from;
  final LivePitchStateId to;

  const ReplayTransition({
    required this.timestampMs,
    required this.from,
    required this.to,
  });
}

class ReplayHarness {
  ReplayHarness(this.engine);

  final TrainingEngine engine;

  ReplayHarnessResult runFrames(List<DspFrame> frames) {
    final visited = <LivePitchStateId>[engine.state.id];
    final transitions = <ReplayTransition>[];
    var previous = engine.state.id;

    for (final frame in frames) {
      engine.onDspFrame(frame);
      if (previous != engine.state.id) {
        transitions.add(ReplayTransition(
          timestampMs: frame.timestampMs,
          from: previous,
          to: engine.state.id,
        ));

        visited.add(engine.state.id);
        previous = engine.state.id;
      }
    }

    return ReplayHarnessResult(
      visitedStates: visited,
      transitions: transitions,
      finalState: engine.state,
    );
  }

  static List<DspFrame> parseJsonl(String jsonl) {
    return jsonl
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => DspFrame.fromJson(json.decode(line) as Map<String, dynamic>))
        .toList(growable: false);
  }
}
