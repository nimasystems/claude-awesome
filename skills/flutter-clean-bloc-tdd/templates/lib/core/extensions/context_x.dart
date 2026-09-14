import 'package:app_name/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// Shortcuts on [BuildContext].
extension ContextX on BuildContext {
  /// Localized strings for the current locale.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
