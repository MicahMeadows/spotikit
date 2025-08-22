class SpotikitException implements Exception {
  final String message;
  SpotikitException(this.message);

  @override
  String toString() => 'SpotikitException: $message';
}