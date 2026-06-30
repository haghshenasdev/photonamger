class AnalysisException implements Exception {
  final String message;

  const AnalysisException(this.message);

  @override
  String toString() {
    return message;
  }
}
