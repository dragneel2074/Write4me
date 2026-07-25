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
      throw Exception('Pollinations returned ${response.statusCode}');
    }
    return Uint8List.fromList(response.data!);
  }

  void cancel() => _cancelToken?.cancel('Cancelled by user');

  void dispose() {
    cancel();
    _dio.close();
  }
}
