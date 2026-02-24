/// Constants synchronized with `specs/dsp-ui-binding.md` defaults.
class PtConstants {
  static const double minConfidence = 0.60;
  static const double recoveryConfidence = 0.65;

  static const int lockAcquireTimeMs = 300;
  static const int lockRequiredBeforeDriftMs = 500;
  static const int driftCandidateTimeMs = 200;
  static const int driftConfirmTimeMs = 250;

  static const int effectiveErrorWindowMs = 150;
  static const double vibratoDepthLimitCents = 30.0;
  static const double vibratoRateMinHz = 4.0;
  static const double vibratoRateMaxHz = 8.0;

  static const double centsErrorClamp = 50.0;
  static const double maxDeformPx = 18.0;
  static const double lowConfidenceShapeOpacity = 0.50;
  static const double lowConfidenceSaturation = 0.30;

  static const double seekingLockSaturation = 0.8;
  static const double lockedSaturation = 1.0;
  static const double driftConfirmedSaturation = 0.4;

  static const int defaultCountdownMs = 3000;
  static const double semitoneWidthPx = 160.0;
}
