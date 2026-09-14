import 'package:app_name/design_system/theme/app_theme.dart';
import 'package:app_name/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps widgets inside a themed, localized [MaterialApp].
extension PumpApp on WidgetTester {
  /// Pumps [widget] as the app's home.
  ///
  /// Set [wrapInScaffold] to false for Views that build their own [Scaffold].
  Future<void> pumpApp(
    Widget widget, {
    bool wrapInScaffold = true,
    ThemeData? theme,
    Locale? locale,
  }) {
    return pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: wrapInScaffold ? Scaffold(body: widget) : widget,
      ),
    );
  }
}
