class AppError implements Exception {
  const AppError(this.message);

  final String message;

  @override
  String toString() => message;
}

class AudioBridgeError extends AppError {
  const AudioBridgeError(super.message);
}

class SessionPersistenceError extends AppError {
  const SessionPersistenceError(super.message);
}
