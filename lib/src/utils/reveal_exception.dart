/// A reveal failure that may trigger an instant theme change.
class RevealException implements Exception {
  /// Creates an error with a readable message and optional underlying cause.
  const RevealException(this.message, [this.cause]);

  /// Human-readable explanation of the failure.
  final String message;

  /// Underlying error, when available.
  final Object? cause;

  @override
  String toString() =>
      'RevealException: $message${cause == null ? '' : ' ($cause)'}';
}

/// Receives reveal errors, including capture and shape fallback failures.
typedef RevealErrorCallback =
    void Function(Object error, StackTrace stackTrace);
