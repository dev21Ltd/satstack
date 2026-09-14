class TlsPinException implements Exception {
  TlsPinException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PinnedHttpResponse {
  final int statusCode;
  final String body;
  const PinnedHttpResponse(this.statusCode, this.body);
}
