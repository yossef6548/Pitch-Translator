import 'package:pt_contracts/pt_contracts.dart';

class RelativePitchPrompt {
  final int baseMidi;
  final int operationSemitones;
  final double toleranceCents;

  const RelativePitchPrompt({
    required this.baseMidi,
    required this.operationSemitones,
    this.toleranceCents = 10,
  });

  int get targetMidi => baseMidi + operationSemitones;
}

class RelativePitchResult {
  final bool isCorrect;
  final int targetMidi;
  final int? observedMidi;
  final double? centsError;

  const RelativePitchResult({
    required this.isCorrect,
    required this.targetMidi,
    required this.observedMidi,
    required this.centsError,
  });
}

class RelativePitchEvaluator {
  const RelativePitchEvaluator();

  RelativePitchResult evaluate({
    required RelativePitchPrompt prompt,
    required DspFrame frame,
  }) {
    if (!frame.hasUsablePitch || frame.nearestMidi == null || frame.centsError == null) {
      return RelativePitchResult(
        isCorrect: false,
        targetMidi: prompt.targetMidi,
        observedMidi: frame.nearestMidi,
        centsError: frame.centsError,
      );
    }

    final isCorrectMidi = frame.nearestMidi == prompt.targetMidi;
    final withinTolerance = frame.centsError!.abs() <= prompt.toleranceCents;
    return RelativePitchResult(
      isCorrect: isCorrectMidi && withinTolerance,
      targetMidi: prompt.targetMidi,
      observedMidi: frame.nearestMidi,
      centsError: frame.centsError,
    );
  }
}

class GroupSimulationResult {
  final double lockRatio;
  final int driftEvents;
  final bool confusionDetected;

  const GroupSimulationResult({
    required this.lockRatio,
    required this.driftEvents,
    required this.confusionDetected,
  });
}

class GroupSimulationEvaluator {
  const GroupSimulationEvaluator();

  GroupSimulationResult evaluate({
    required List<DspFrame> frames,
    required int anchorMidi,
    required double toleranceCents,
    required double driftThresholdCents,
    Set<int> confusionNotes = const {},
  }) {
    if (frames.isEmpty) {
      return const GroupSimulationResult(
        lockRatio: 0,
        driftEvents: 0,
        confusionDetected: false,
      );
    }

    var activeMs = 0;
    var lockedMs = 0;
    var driftEvents = 0;
    var confusionDetected = false;
    int? previousTimestamp;
    int? previousConfusionMidi;

    for (final frame in frames) {
      final dt = previousTimestamp == null
          ? 0
          : (frame.timestampMs - previousTimestamp!).clamp(0, 1000);
      previousTimestamp = frame.timestampMs;
      activeMs += dt;

      if (!frame.hasUsablePitch || frame.centsError == null || frame.nearestMidi == null) {
        continue;
      }

      final isLocked = frame.nearestMidi == anchorMidi && frame.centsError!.abs() <= toleranceCents;
      if (isLocked) {
        lockedMs += dt;
      }

      if (!isLocked && frame.centsError!.abs() > driftThresholdCents) {
        driftEvents += 1;
      }

      if (confusionNotes.contains(frame.nearestMidi)) {
        if (previousConfusionMidi != null && previousConfusionMidi != frame.nearestMidi) {
          confusionDetected = true;
        }
        previousConfusionMidi = frame.nearestMidi;
      }
    }

    return GroupSimulationResult(
      lockRatio: activeMs == 0 ? 0 : lockedMs / activeMs,
      driftEvents: driftEvents,
      confusionDetected: confusionDetected,
    );
  }
}

class ListeningPrompt {
  final String expectedNote;
  final int expectedOctave;

  const ListeningPrompt({required this.expectedNote, required this.expectedOctave});
}

class ListeningResponse {
  final String selectedNote;
  final int selectedOctave;

  const ListeningResponse({required this.selectedNote, required this.selectedOctave});
}

class ListeningTranslationEvaluator {
  const ListeningTranslationEvaluator();

  bool evaluate({
    required ListeningPrompt prompt,
    required ListeningResponse response,
  }) {
    return prompt.expectedNote == response.selectedNote &&
        prompt.expectedOctave == response.selectedOctave;
  }
}
