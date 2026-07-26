import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:write4me/services/text_generation_service.dart';

void main() {
  DioException responseError(int status, {String? retryAfter}) {
    final request = RequestOptions(path: '/v1/chat/completions');
    return DioException.badResponse(
      statusCode: status,
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: status,
        headers: retryAfter == null
            ? Headers()
            : Headers.fromMap({
                'retry-after': [retryAfter],
              }),
        data: {
          'error': {'message': 'Provider detail'}
        },
      ),
    );
  }

  test('explains rate limits and retry timing', () {
    final message = providerErrorMessage(
        responseError(429, retryAfter: '30'), 'OpenRouter');

    expect(message, contains('rate-limiting'));
    expect(message, contains('30 seconds'));
  });

  test('explains exhausted provider credits', () {
    final message = providerErrorMessage(responseError(402), 'Pollinations');

    expect(message, contains('credits'));
    expect(message, contains('spending limit'));
  });

  test('asks the user to reload a removed model', () {
    final message = providerErrorMessage(responseError(404), 'Gemini');

    expect(message, contains('no longer available'));
    expect(message, contains('Reload models'));
  });
}
