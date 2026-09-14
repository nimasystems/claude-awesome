import 'package:app_name/core/logging/logger_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoggerService.redact', () {
    test(
      'masks sensitive key/value pairs regardless of case and separators',
      () {
        final out = LoggerService.redact(
          '{"access_token": "abc123", "Password"=hunter2, name: Ana}',
        );
        expect(out, isNot(contains('abc123')));
        expect(out, isNot(contains('hunter2')));
        expect(out, contains('Ana'));
      },
    );

    test('masks card-like numbers', () {
      expect(
        LoggerService.redact('paid with 4242424242424242 ok'),
        'paid with **** ok',
      );
    });

    test('leaves ordinary text untouched', () {
      expect(LoggerService.redact('loaded 12 venues'), 'loaded 12 venues');
    });
  });
}
