import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Spacing tokens exposed as a [ThemeExtension].
///
/// Minimal stand-in until generated design tokens exist.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  /// Creates spacing tokens.
  const AppSpacing({required this.sm, required this.md, required this.lg});

  /// Default scale.
  static const regular = AppSpacing(sm: 8, md: 16, lg: 24);

  final double sm;
  final double md;
  final double lg;

  @override
  AppSpacing copyWith({double? sm, double? md, double? lg}) => AppSpacing(
    sm: sm ?? this.sm,
    md: md ?? this.md,
    lg: lg ?? this.lg,
  );

  @override
  AppSpacing lerp(covariant ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
    );
  }
}

/// App themes.
abstract final class AppTheme {
  /// Light theme with design tokens attached.
  static final ThemeData light = ThemeData(
    extensions: const [AppSpacing.regular],
  );
}

/// Token access from widgets.
extension AppTokensContextX on BuildContext {
  /// Spacing tokens of the current theme ([AppSpacing.regular] if absent).
  AppSpacing get spacing =>
      Theme.of(this).extension<AppSpacing>() ?? AppSpacing.regular;
}
