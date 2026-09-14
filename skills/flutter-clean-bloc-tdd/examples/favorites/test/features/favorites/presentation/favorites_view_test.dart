import 'package:app_name/core/error/failures.dart';
import 'package:app_name/design_system/widgets/app_empty_view.dart';
import 'package:app_name/design_system/widgets/app_error_view.dart';
import 'package:app_name/design_system/widgets/app_loader.dart';
import 'package:app_name/features/favorites/domain/entities/favorite_venue.dart';
import 'package:app_name/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:app_name/features/favorites/presentation/bloc/favorites_event.dart';
import 'package:app_name/features/favorites/presentation/bloc/favorites_state.dart';
import 'package:app_name/features/favorites/presentation/pages/favorites_page.dart';
import 'package:app_name/features/favorites/presentation/widgets/favorite_venue_tile.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';

class _MockFavoritesBloc extends MockBloc<FavoritesEvent, FavoritesState>
    implements FavoritesBloc {}

FavoriteVenue _venue(String id, String name) => FavoriteVenue(
  id: id,
  name: name,
  imageUrl: Uri.parse('https://cdn.example.com/$id.jpg'),
  addedAt: DateTime.utc(2026, 9, 2, 12),
);

final FavoriteVenue _v1 = _venue('v1', 'Blue Note');
final FavoriteVenue _v2 = _venue('v2', 'Jazz Cellar');
final _loaded = FavoritesState(
  status: FavoritesStatus.loaded,
  favorites: [_v1, _v2],
);

void main() {
  late _MockFavoritesBloc bloc;

  setUp(() => bloc = _MockFavoritesBloc());

  Future<void> pumpView(WidgetTester tester) => tester.pumpApp(
    BlocProvider<FavoritesBloc>.value(
      value: bloc,
      child: const FavoritesView(),
    ),
  );

  group('FavoritesView', () {
    testWidgets('shows the title', (tester) async {
      when(() => bloc.state).thenReturn(const FavoritesState());
      await pumpView(tester);
      expect(find.text('Favorites'), findsOneWidget);
    });

    for (final status in [FavoritesStatus.initial, FavoritesStatus.loading]) {
      testWidgets('shows a loader when $status', (tester) async {
        when(() => bloc.state).thenReturn(FavoritesState(status: status));
        await pumpView(tester);
        expect(find.byType(AppLoader), findsOneWidget);
      });
    }

    testWidgets('shows the empty view when loaded with no favorites', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(const FavoritesState(status: FavoritesStatus.loaded));
      await pumpView(tester);
      expect(find.byType(AppEmptyView), findsOneWidget);
      expect(find.text('No favorites yet.'), findsOneWidget);
    });

    testWidgets('shows a localized error and retry dispatches '
        'FavoritesRequested', (tester) async {
      when(() => bloc.state).thenReturn(
        const FavoritesState(
          status: FavoritesStatus.failure,
          failure: NetworkFailure('offline'),
        ),
      );
      await pumpView(tester);

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('No internet connection.'), findsOneWidget);
      expect(find.text('offline'), findsNothing);

      await tester.tap(find.byKey(AppErrorView.retryKey));
      verify(() => bloc.add(const FavoritesRequested())).called(1);
    });

    testWidgets('shows only visible favorites when loaded', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(_loaded.copyWith(pendingRemovalIds: {'v2'}));
      await pumpView(tester);

      expect(find.byType(FavoriteVenueTile), findsOneWidget);
      expect(find.text('Blue Note'), findsOneWidget);
      expect(find.text('Jazz Cellar'), findsNothing);
      // Rendered in the device timezone, so compute the expected local date.
      final added = DateFormat.yMMMd('en').format(_v1.addedAt.toLocal());
      expect(find.text('Added $added'), findsOneWidget);
    });

    testWidgets('tapping remove dispatches FavoriteRemoved for that venue', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(_loaded);
      await pumpView(tester);

      await tester.tap(find.byKey(FavoriteVenueTile.removeKey('v2')));

      verify(() => bloc.add(const FavoriteRemoved('v2'))).called(1);
    });

    testWidgets('remove button has an accessible tooltip', (tester) async {
      when(() => bloc.state).thenReturn(_loaded);
      await pumpView(tester);

      expect(find.byTooltip('Remove Blue Note from favorites'), findsOneWidget);
    });

    testWidgets('shows a snackbar when a removal fails', (tester) async {
      whenListen(
        bloc,
        Stream.value(
          _loaded.copyWith(
            removalError: () =>
                const FavoriteRemovalError('v1', NetworkFailure('x')),
          ),
        ),
        initialState: _loaded,
      );
      await pumpView(tester);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text("Couldn't remove favorite. No internet connection."),
        findsOneWidget,
      );
    });

    testWidgets('does not show a snackbar for unrelated state changes', (
      tester,
    ) async {
      whenListen(
        bloc,
        Stream.value(_loaded.copyWith(pendingRemovalIds: {'v1'})),
        initialState: _loaded,
      );
      await pumpView(tester);
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('FavoritesPage', () {
    tearDown(GetIt.instance.reset);

    testWidgets('resolves the bloc from getIt and requests favorites', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(const FavoritesState());
      GetIt.instance.registerFactory<FavoritesBloc>(() => bloc);

      await tester.pumpApp(const FavoritesPage());

      expect(find.byType(FavoritesView), findsOneWidget);
      verify(() => bloc.add(const FavoritesRequested())).called(1);
    });
  });
}
