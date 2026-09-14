import 'package:app_name/core/extensions/context_x.dart';
import 'package:app_name/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Centered error message with a retry button.
class AppErrorView extends StatelessWidget {
  /// Creates an [AppErrorView].
  const AppErrorView({required this.message, required this.onRetry, super.key});

  /// Key of the retry button, for tests.
  static const retryKey = Key('app_error_view_retry');

  /// Localized message to show.
  final String message;

  /// Called when the user taps retry.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(context.spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: context.spacing.md),
          FilledButton(
            key: retryKey,
            onPressed: onRetry,
            child: Text(context.l10n.retry),
          ),
        ],
      ),
    ),
  );
}
