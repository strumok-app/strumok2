class ContentSuppliersException implements Exception {
  final String message;

  const ContentSuppliersException(this.message);

  @override
  String toString() => 'ContentSuppliersException: $message';
}
