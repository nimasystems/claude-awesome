import 'package:app_name/core/error/failures.dart';
import 'package:app_name/l10n/gen/app_localizations.dart';

/// Maps a [Failure] to a user-facing, localized message.
extension FailureMessageX on Failure {
  /// Never returns [Failure.message] (developer text).
  String toMessage(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNoConnection,
    AuthFailure() => l10n.errorSessionExpired,
    NotFoundFailure() => l10n.errorNotFound,
    ValidationFailure(:final fieldErrors) when fieldErrors.isNotEmpty =>
      fieldErrors.values.first,
    ValidationFailure() ||
    ServerFailure() ||
    CacheFailure() ||
    UnknownFailure() => l10n.errorGeneric,
  };
}
