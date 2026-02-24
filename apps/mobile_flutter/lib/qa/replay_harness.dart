import 'dart:convert';

import 'package:pt_contracts/pt_contracts.dart';

import '../training/training_engine.dart';

class ReplayHarnessResult {
  final List<LivePitchStateId> visitedStates;
  final LivePitchUiState finalState;

  const ReplayHarnessResult({required this.visitedStates, required this.finalState});

  bool visited(LivePitchStateId state) => visitedStates.contains(state);
}

class ReplayHarness {
  ReplayHarness(this.engine);

  final TrainingEngine engine;

  ReplayHarnessResult runFrames(List<DspFrame> frames) {
    final visited = <LivePitchStateId>[engine.state.id];
    for (final frame in frames) {
      engine.onDspFrame(frame);
      if (visited.last != engine.state.id) {
        visited.add(engine.state.id);
      }
    }
    return ReplayHarnessResult(visitedStates: visited, finalState: engine.state);
  }

  static List<DspFrame> parseJsonl(String jsonl) {
    return jsonl
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => DspFrame.fromJson(json.decode(line) as Map<String, dynamic>))
        .toList(growable: false);
  }
}
