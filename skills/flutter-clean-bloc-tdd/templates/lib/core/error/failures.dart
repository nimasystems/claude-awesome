import 'package:equatable/equatable.dart';

/// A typed, expected failure returned as the `Left` of an `Either`.
///
/// Sealed so presentation code can `switch` exhaustively when mapping a
/// failure to a localized message. Add feature-specific failures as new
/// `final class`es here.
sealed class Failure extends Equatable {
  /// Base constructor.
  const Failure(this.message, {this.cause});

  /// Developer-facing description. Never shown to users.
  final String message;

  /// The underlying error, kept for logging. Excluded from equality.
  final Object? cause;

  @override
  List<Object?> get props => [message];
}

/// No connectivity, timeout or DNS failure.
final class NetworkFailure extends Failure {
  /// Creates a [NetworkFailure].
  const NetworkFailure(super.message, {super.cause});
}

/// The server responded with an error status.
final class ServerFailure extends Failure {
  /// Creates a [ServerFailure].
  const ServerFailure(super.message, {this.code, super.cause});

  /// HTTP status code, when known.
  final int? code;

  @override
  List<Object?> get props => [message, code];
}

/// The session is missing, expired or forbidden.
final class AuthFailure extends Failure {
  /// Creates an [AuthFailure].
  const AuthFailure(super.message, {super.cause});
}

/// The requested resource does not exist.
final class NotFoundFailure extends Failure {
  /// Creates a [NotFoundFailure].
  const NotFoundFailure(super.message, {super.cause});
}

/// Input was rejected; [fieldErrors] maps field name to error text.
final class ValidationFailure extends Failure {
  /// Creates a [ValidationFailure].
  const ValidationFailure(
    super.message, {
    this.fieldErrors = const {},
    super.cause,
  });

  /// Per-field validation errors.
  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [message, fieldErrors];
}

/// Local persistence read/write failed.
final class CacheFailure extends Failure {
  /// Creates a [CacheFailure].
  const CacheFailure(super.message, {super.cause});
}

/// Anything not otherwise classified.
final class UnknownFailure extends Failure {
  /// Creates an [UnknownFailure].
  const UnknownFailure({String message = 'Something went wrong', super.cause})
    : super(message);
}
