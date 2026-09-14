import 'package:app_name/design_system/theme/app_theme.dart';
import 'package:app_name/design_system/widgets/app_empty_view.dart';
import 'package:app_name/design_system/widgets/app_error_view.dart';
import 'package:app_name/design_system/widgets/app_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('AppSpacing', () {
    test('copyWith overrides only the given values', () {
      final copy = AppSpacing.regular.copyWith(md: 20);
      expect(copy.md, 20);
      expect(copy.sm, AppSpacing.regular.sm);
      expect(copy.lg, AppSpacing.regular.lg);
    });

    test('lerp interpolates and ignores foreign extensions', () {
      const a = AppSpacing(sm: 0, md: 0, lg: 0);
      const b = AppSpacing(sm: 10, md: 20, lg: 30);
      expect(a.lerp(b, 0.5).md, 10);
      expect(a.lerp(null, 0.5), a);
    });

    testWidgets('context.spacing falls back to regular without a theme', (
      tester,
    ) async {
      late AppSpacing spacing;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            spacing = context.spacing;
            return const SizedBox.shrink();
          },
        ),
      );
      expect(spacing, AppSpacing.regular);
    });
  });

  testWidgets('AppLoader shows a progress indicator', (tester) async {
    await tester.pumpApp(const AppLoader());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppEmptyView shows its message', (tester) async {
    await tester.pumpApp(const AppEmptyView(message: 'Nothing here'));
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('AppErrorView shows message and calls onRetry', (tester) async {
    var retries = 0;
    await tester.pumpApp(
      AppErrorView(message: 'Oops', onRetry: () => retries++),
    );

    expect(find.text('Oops'), findsOneWidget);
    await tester.tap(find.byKey(AppErrorView.retryKey));
    expect(retries, 1);
  });
}
