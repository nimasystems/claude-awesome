import 'package:app_name/core/error/failures.dart';
import 'package:app_name/core/extensions/failure_message_x.dart';
import 'package:app_name/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(
    () async => l10n = await AppLocalizations.delegate.load(const Locale('en')),
  );

  final cases = <(Failure, String Function(AppLocalizations))>[
    (const NetworkFailure('x'), (l) => l.errorNoConnection),
    (const AuthFailure('x'), (l) => l.errorSessionExpired),
    (const NotFoundFailure('x'), (l) => l.errorNotFound),
    (const ServerFailure('x', code: 500), (l) => l.errorGeneric),
    (const ValidationFailure('x'), (l) => l.errorGeneric),
    (const CacheFailure('x'), (l) => l.errorGeneric),
    (const UnknownFailure(), (l) => l.errorGeneric),
  ];

  for (final (failure, expected) in cases) {
    test('${failure.runtimeType} maps to its localized message', () {
      expect(failure.toMessage(l10n), expected(l10n));
    });
  }

  test('ValidationFailure with field errors shows the first field error', () {
    const failure = ValidationFailure('x', fieldErrors: {'name': 'Too short'});
    expect(failure.toMessage(l10n), 'Too short');
  });

  test('never exposes the developer message', () {
    expect(
      const ServerFailure('SQL timeout on shard 3').toMessage(l10n),
      isNot(contains('SQL')),
    );
  });
}
