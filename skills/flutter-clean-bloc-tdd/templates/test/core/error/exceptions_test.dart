import 'package:app_name/core/error/exceptions.dart';
import 'package:app_name/core/error/failures.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiException.toFailure', () {
    const cases = <int?, Type>{
      401: AuthFailure,
      403: AuthFailure,
      404: NotFoundFailure,
      422: ValidationFailure,
      500: ServerFailure,
      null: ServerFailure,
    };

    for (final MapEntry(key: code, value: type) in cases.entries) {
      test('$code → $type', () {
        final failure = ApiException('x', statusCode: code).toFailure();
        expect(failure.runtimeType, type);
        expect(failure.message, 'x');
      });
    }

    test('ServerFailure keeps the status code', () {
      expect(
        const ApiException('x', statusCode: 503).toFailure(),
        const ServerFailure('x', code: 503),
      );
    });
  });

  test('NetworkException → NetworkFailure', () {
    expect(
      const NetworkException('offline').toFailure(),
      const NetworkFailure('offline'),
    );
  });

  test('CacheException → CacheFailure', () {
    expect(
      const CacheException('disk').toFailure(),
      const CacheFailure('disk'),
    );
  });

  group('appExceptionFromDio', () {
    final options = RequestOptions(path: '/x');

    test('timeouts and connection errors → NetworkException', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(
          appExceptionFromDio(
            DioException(requestOptions: options, type: type),
          ),
          isA<NetworkException>(),
          reason: '$type',
        );
      }
    });

    test('badResponse → ApiException with status code', () {
      final e = DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: 404),
      );
      expect(
        appExceptionFromDio(e),
        isA<ApiException>().having((a) => a.statusCode, 'statusCode', 404),
      );
    });
  });
}
