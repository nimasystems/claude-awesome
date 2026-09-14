import 'package:app_name/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Centered message for an empty collection.
class AppEmptyView extends StatelessWidget {
  /// Creates an [AppEmptyView].
  const AppEmptyView({required this.message, super.key});

  /// Localized message to show.
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(context.spacing.lg),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}
