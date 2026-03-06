class LiveSessionMetrics {
  const LiveSessionMetrics({
    this.avgErrorCents = 0,
    this.stabilityCents = 0,
    this.lockRatio = 0,
    this.driftCount = 0,
    this.activeDurationMs = 0,
  });

  final double avgErrorCents;
  final double stabilityCents;
  final double lockRatio;
  final int driftCount;
  final int activeDurationMs;
}
