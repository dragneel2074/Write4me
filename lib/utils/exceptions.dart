class DownloadException implements Exception {
  final int? statusCode;
  final String message;
  final Uri? uri;

  DownloadException(this.message, {this.statusCode, this.uri});

  @override
  String toString() => statusCode != null
      ? 'DownloadException: $message (HTTP $statusCode)'
      : 'DownloadException: $message';
} 