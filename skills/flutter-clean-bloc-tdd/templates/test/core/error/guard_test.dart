import 'package:app_name/core/error/exceptions.dart';
import 'package:app_name/core/error/failures.dart';
import 'package:app_name/core/error/guard.dart';
import 'package:app_name/core/logging/logger_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logger/logger.dart';

void main() {
  setUpAll(() => LoggerService.configure(Logger(level: Level.off)));

  final options = RequestOptions(path: '/x');

  test('returns Right with the body result', () async {
    expect(await guard('t', () async => 42), const Right<Failure, int>(42));
  });

  test('maps AppException to its typed failure', () async {
    final result = await guard<int>(
      't',
      () => throw const ApiException('nope', statusCode: 401),
    );
    expect(result.getLeft().toNullable(), isA<AuthFailure>());
  });

  test('maps a DioException connection error to NetworkFailure', () async {
    final result = await guard<int>(
      't',
      () => throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      ),
    );
    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
  });

  test('maps a DioException bad response by status code', () async {
    final result = await guard<int>(
      't',
      () => throw DioException.badResponse(
        statusCode: 404,
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 404),
      ),
    );
    expect(result.getLeft().toNullable(), isA<NotFoundFailure>());
  });

  test('prefers an AppException carried inside a DioException', () async {
    final result = await guard<int>(
      't',
      () => throw DioException(
        requestOptions: options,
        error: const ApiException('expired', statusCode: 401),
      ),
    );
    expect(result.getLeft().toNullable(), isA<AuthFailure>());
  });

  test('maps anything else to UnknownFailure and never throws', () async {
    final error = StateError('boom');
    final result = await guard<int>('t', () => throw error);
    expect(
      result.getLeft().toNullable(),
      isA<UnknownFailure>().having((f) => f.cause, 'cause', error),
    );
  });
}
