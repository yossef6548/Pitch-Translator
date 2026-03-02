Duration durationBetweenMs(int startedAtMs, int endedAtMs) {
  final delta = endedAtMs - startedAtMs;
  return Duration(milliseconds: delta < 0 ? 0 : delta);
}

String formatDuration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${value.inHours > 0 ? '${value.inHours}:' : ''}$minutes:$seconds';
}
