import 'package:app_name/core/error/exceptions.dart';
import 'package:app_name/core/error/failures.dart';
import 'package:app_name/core/logging/logger_service.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

/// Runs [body] and converts its outcome to an `Either`.
///
/// - [AppException] → its typed failure (logged as warning).
/// - [DioException] → mapped via [appExceptionFromDio] (Dio always throws
///   `DioException`; interceptors cannot change the thrown type). If an
///   interceptor rejected with an [AppException] as `error`, that wins.
/// - anything else → [UnknownFailure] (logged as error).
///
/// Never throws. This is the only sanctioned catch-all in the data layer.
Future<Either<Failure, T>> guard<T>(
  String tag,
  Future<T> Function() body,
) async {
  try {
    return Right(await body());
  } on AppException catch (e, s) {
    LoggerService.I.warning('$tag failed', e, s);
    return Left(e.toFailure());
  } on DioException catch (e, s) {
    final mapped = switch (e.error) {
      final AppException inner => inner,
      _ => appExceptionFromDio(e),
    };
    LoggerService.I.warning('$tag failed', mapped, s);
    return Left(mapped.toFailure());
  } catch (e, s) {
    LoggerService.I.error('$tag unexpected', e, s);
    return Left(UnknownFailure(cause: e));
  }
}
