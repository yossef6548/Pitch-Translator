import 'dart:math';

import 'package:pt_contracts/pt_contracts.dart';

class DspUiBinding {
  const DspUiBinding({
    required this.xOffsetPx,
    required this.deformPx,
    required this.saturation,
    required this.haloIntensity,
    required this.displayCents,
    required this.arrow,
    required this.errorReadoutVisible,
  });

  final double xOffsetPx;
  final double deformPx;
  final double saturation;
  final double haloIntensity;
  final String displayCents;
  final String arrow;
  final bool errorReadoutVisible;
}

DspUiBinding bindDspToUi({
  required DspFrame frame,
  required double? effectiveError,
  required LivePitchStateId state,
  required ExerciseConfig config,
  required double semitoneWidthPxW,
}) {
  if (state == LivePitchStateId.lowConfidence || effectiveError == null) {
    return const DspUiBinding(
      xOffsetPx: 0,
      deformPx: 0,
      saturation: PtConstants.lowConfidenceSaturation,
      haloIntensity: 0,
      displayCents: '—',
      arrow: '',
      errorReadoutVisible: false,
    );
  }

  final centsError = frame.centsError!
      .clamp(-PtConstants.centsErrorClamp, PtConstants.centsErrorClamp);
  final absError = effectiveError.abs();
  final e = (absError / config.driftThresholdCents).clamp(0.0, 1.0);
  final shouldRenderRigid =
      state == LivePitchStateId.locked && absError <= config.toleranceCents;
  final xOffset = shouldRenderRigid ? 0.0 : (centsError / 100.0) * semitoneWidthPxW;
  final deform = shouldRenderRigid ? 0.0 : e * PtConstants.maxDeformPx;

  var saturation = 1.0 - (e * 0.6);
  if (state == LivePitchStateId.locked) saturation = PtConstants.lockedSaturation;
  if (state == LivePitchStateId.seekingLock) saturation = PtConstants.seekingLockSaturation;
  if (state == LivePitchStateId.driftConfirmed) {
    saturation = PtConstants.driftConfirmedSaturation;
  }

  double haloIntensity;
  if (state == LivePitchStateId.locked) {
    haloIntensity = 1.0;
  } else if (state == LivePitchStateId.seekingLock) {
    final t = frame.timestampMs / 1000.0;
    haloIntensity = 0.65 + 0.15 * sin(2 * pi * t / 1.2);
  } else if (state == LivePitchStateId.driftConfirmed) {
    haloIntensity = 0.2;
  } else {
    haloIntensity = 0.4 + 0.3 * e;
  }

  final arrow = absError <= config.toleranceCents ? '' : (centsError > 0 ? '↑' : '↓');
  return DspUiBinding(
    xOffsetPx: xOffset,
    deformPx: deform,
    saturation: saturation,
    haloIntensity: haloIntensity,
    displayCents: '${centsError.round()}',
    arrow: arrow,
    errorReadoutVisible: true,
  );
}
