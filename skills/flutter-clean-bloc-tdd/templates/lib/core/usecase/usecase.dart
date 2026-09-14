import 'package:app_name/core/error/failures.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

/// A single application operation. Implementations are `@injectable`
/// callable classes that depend on repository interfaces only.
abstract interface class UseCase<T, Params> {
  /// Runs the use case.
  Future<Either<Failure, T>> call(Params params);
}

/// A use case that yields a stream of results (live data, watches).
abstract interface class StreamUseCase<T, Params> {
  /// Starts the stream.
  Stream<Either<Failure, T>> call(Params params);
}

/// Params for use cases that take no input.
class NoParams extends Equatable {
  /// Creates [NoParams].
  const NoParams();

  @override
  List<Object?> get props => [];
}
