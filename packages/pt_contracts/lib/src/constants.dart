/// Constants placeholder (sync with specs before implementation).
///
/// These values MUST match `dsp-ui-binding.md` once you copy canonical specs into /specs.
class PtConstants {
  static const double minConfidence = 0.60;
  static const double recoveryConfidence = 0.65;

  static const int lockAcquireTimeMs = 300;
  static const int lockRequiredBeforeDriftMs = 500;
  static const int driftCandidateTimeMs = 200;
  static const int driftConfirmTimeMs = 250;

  static const int effectiveErrorWindowMs = 150;
  static const double centsErrorClamp = 50.0;
}
