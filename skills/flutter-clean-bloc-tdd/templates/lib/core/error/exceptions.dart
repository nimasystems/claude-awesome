import 'package:app_name/core/error/failures.dart';
import 'package:dio/dio.dart';

/// Exceptions thrown by data sources and clients. Repositories catch them
/// and convert them with [toFailure]; they never reach the domain or the UI.
sealed class AppException implements Exception {
  /// Base constructor.
  const AppException(this.message, {this.cause});

  /// Developer-facing description.
  final String message;

  /// The underlying error.
  final Object? cause;

  /// The typed [Failure] this exception represents.
  Failure toFailure();

  @override
  String toString() => 'AppException: $message';
}

/// The server responded with a non-success [statusCode].
final class ApiException extends AppException {
  /// Creates an [ApiException].
  const ApiException(super.message, {this.statusCode, super.cause});

  /// HTTP status code, when known.
  final int? statusCode;

  @override
  Failure toFailure() => switch (statusCode) {
    401 || 403 => AuthFailure(message, cause: cause),
    404 => NotFoundFailure(message, cause: cause),
    422 => ValidationFailure(message, cause: cause),
    _ => ServerFailure(message, code: statusCode, cause: cause),
  };
}

/// The request never got a response (offline, timeout).
final class NetworkException extends AppException {
  /// Creates a [NetworkException].
  const NetworkException(super.message, {super.cause});

  @override
  Failure toFailure() => NetworkFailure(message, cause: cause);
}

/// Local storage failed.
final class CacheException extends AppException {
  /// Creates a [CacheException].
  const CacheException(super.message, {super.cause});

  @override
  Failure toFailure() => CacheFailure(message, cause: cause);
}

/// Maps a [DioException] to an [AppException]. Used by the error-mapping
/// interceptor so data sources never deal with Dio errors directly.
AppException appExceptionFromDio(DioException e) => switch (e.type) {
  DioExceptionType.connectionTimeout ||
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout ||
  DioExceptionType.transformTimeout ||
  DioExceptionType.connectionError => NetworkException(
    e.message ?? 'Network error',
    cause: e,
  ),
  DioExceptionType.badResponse => ApiException(
    e.message ?? 'Server error',
    statusCode: e.response?.statusCode,
    cause: e,
  ),
  DioExceptionType.cancel ||
  DioExceptionType.badCertificate ||
  DioExceptionType.unknown => ApiException(
    e.message ?? 'Request failed',
    cause: e,
  ),
};
