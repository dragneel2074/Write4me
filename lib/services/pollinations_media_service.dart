import 'dart:typed_data';
import 'package:dio/dio.dart';

class PollinationsMediaService {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  Future<Uint8List> generate({
    required String prompt,
    required String model,
    required String apiKey,
    required bool video,
  }) async {
    final endpoint = video ? 'video' : 'image';
    final uri = Uri.parse('https://gen.pollinations.ai/$endpoint/'
            '${Uri.encodeComponent(prompt)}')
        .replace(queryParameters: {'model': model});
    _cancelToken = CancelToken();
    try {
      final response = await _dio.get<List<int>>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $apiKey'},
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(seconds: 30),
        ),
        cancelToken: _cancelToken,
      );
      if (response.statusCode != 200 || response.data == null) {
        throw Exception('Pollinations returned an empty media response.');
      }
      return Uint8List.fromList(response.data!);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw Exception('Generation cancelled.');
      }
      final status = error.response?.statusCode;
      final retryAfter = error.response?.headers.value('retry-after');
      throw Exception(switch (status) {
        401 || 403 => 'The Pollinations API key is invalid or unauthorized.',
        402 => 'Pollinations credits or the API-key budget are exhausted.',
        404 => 'The selected Pollinations model is no longer available.',
        429 =>
          'Pollinations is rate-limiting this model. ${retryAfter == null ? 'Try again later.' : 'Try again after $retryAfter seconds.'}',
        500 ||
        502 ||
        503 ||
        504 =>
          'Pollinations is temporarily unavailable. Please try again.',
        _
            when error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.sendTimeout ||
                error.type == DioExceptionType.receiveTimeout =>
          'Pollinations generation timed out. Please try again.',
        _ when error.type == DioExceptionType.connectionError =>
          'Could not connect to Pollinations. Check your internet connection.',
        _ => 'Pollinations generation failed.',
      });
    }
  }

  void cancel() => _cancelToken?.cancel('Cancelled by user');

  void dispose() {
    cancel();
    _dio.close();
  }
}
