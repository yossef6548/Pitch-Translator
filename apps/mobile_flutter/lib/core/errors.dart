class AppError implements Exception {
  const AppError(this.message);

  final String message;

  @override
  String toString() => message;
}

class AudioBridgeError extends AppError {
  const AudioBridgeError(super.message);
}

enum AudioBridgeFailure {
  permissionDenied,
  noFramesTimeout,
  audioFocusDenied,
  pluginUnavailable,
  unknown,
}

class AudioBridgeException extends AudioBridgeError {
  AudioBridgeException(this.failure, {String? details})
      : super(_messageForFailure(failure, details));

  final AudioBridgeFailure failure;

  static String _messageForFailure(
    AudioBridgeFailure failure,
    String? details,
  ) {
    final base = switch (failure) {
      AudioBridgeFailure.permissionDenied =>
        'Microphone permission is required to start audio capture.',
      AudioBridgeFailure.noFramesTimeout =>
        'No audio frames were received after starting capture.',
      AudioBridgeFailure.audioFocusDenied =>
        'Audio focus request was denied by the system.',
      AudioBridgeFailure.pluginUnavailable =>
        'Native audio plugin is unavailable on this build.',
      AudioBridgeFailure.unknown => 'An unknown audio error occurred.',
    };
    if (details == null || details.isEmpty) {
      return base;
    }
    return '$base ($details)';
  }
}

class SessionPersistenceError extends AppError {
  const SessionPersistenceError(super.message);
}
