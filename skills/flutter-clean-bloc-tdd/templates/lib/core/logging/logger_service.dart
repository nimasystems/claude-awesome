import 'package:logger/logger.dart';

/// The single logging facade. `print`/`debugPrint` are banned by lint.
///
/// Every message and error text goes through [redact] so secrets and PII
/// never reach a log sink.
class LoggerService {
  LoggerService._(this._logger);

  /// Process-wide instance. Replace with [configure] at bootstrap or in tests.
  static LoggerService I = LoggerService._(
    Logger(printer: SimplePrinter()),
  );

  final Logger _logger;

  /// Keys whose values are masked (case-insensitive, `_`/`-` ignored).
  static const Set<String> sensitiveKeys = {
    'password',
    'pin',
    'otp',
    'token',
    'accesstoken',
    'refreshtoken',
    'authorization',
    'cvv',
    'cvc',
    'cardnumber',
    'pan',
    'email',
    'phone',
    'address',
  };

  static final RegExp _cardLike = RegExp(r'\b\d{13,19}\b');
  static final RegExp _keyValue = RegExp(
    r'''["']?([A-Za-z_\-]+)["']?\s*[:=]\s*["']?([^,"'}\s]+)["']?''',
  );

  /// Replaces the active logger (per-flavor level, or capture in tests).
  static void configure(Logger logger) => I = LoggerService._(logger);

  /// Masks sensitive `key: value` / `key=value` pairs and card-like numbers.
  static String redact(String input) {
    final masked = input.replaceAllMapped(_keyValue, (m) {
      final key = m[1]!.toLowerCase().replaceAll(RegExp('[_-]'), '');
      return sensitiveKeys.contains(key) ? '${m[1]}: ***' : m[0]!;
    });
    return masked.replaceAll(_cardLike, '****');
  }

  /// Local tracing. Stripped from release by the per-flavor level.
  void debug(String message) => _logger.d(redact(message));

  /// Lifecycle, navigation, key user actions.
  void info(String message) => _logger.i(redact(message));

  /// Recoverable failures.
  void warning(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.w(
        redact(message),
        error: error == null ? null : redact('$error'),
        stackTrace: stackTrace,
      );

  /// Unexpected failures.
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(
        redact(message),
        error: error == null ? null : redact('$error'),
        stackTrace: stackTrace,
      );
}
