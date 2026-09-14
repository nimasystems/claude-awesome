import 'dart:async';

import 'package:app_name/core/error/failures.dart';
import 'package:app_name/core/usecase/usecase.dart';
import 'package:app_name/features/favorites/domain/entities/favorite_venue.dart';
import 'package:app_name/features/favorites/domain/usecases/get_favorites.dart';
import 'package:app_name/features/favorites/domain/usecases/remove_favorite.dart';
import 'package:app_name/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:app_name/features/favorites/presentation/bloc/favorites_event.dart';
import 'package:app_name/features/favorites/presentation/bloc/favorites_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetFavorites extends Mock implements GetFavorites {}

class _MockRemoveFavorite extends Mock implements RemoveFavorite {}

FavoriteVenue _venue(String id) => FavoriteVenue(
  id: id,
  name: 'Venue $id',
  imageUrl: Uri.parse('https://cdn.example.com/$id.jpg'),
  addedAt: DateTime.utc(2026, 9, 2),
);

final FavoriteVenue _v1 = _venue('v1');
final FavoriteVenue _v2 = _venue('v2');

void main() {
  late _MockGetFavorites getFavorites;
  late _MockRemoveFavorite removeFavorite;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const RemoveFavoriteParams('x'));
  });

  setUp(() {
    getFavorites = _MockGetFavorites();
    removeFavorite = _MockRemoveFavorite();
  });

  FavoritesBloc build() => FavoritesBloc(getFavorites, removeFavorite);

  final loaded = FavoritesState(
    status: FavoritesStatus.loaded,
    favorites: [_v1, _v2],
  );

  group('FavoritesState', () {
    test('visible hides pending removals', () {
      expect(loaded.copyWith(pendingRemovalIds: {'v1'}).visible, [_v2]);
    });

    test('isEmpty is true only when loaded with nothing visible', () {
      expect(const FavoritesState().isEmpty, isFalse);
      expect(
        const FavoritesState(status: FavoritesStatus.loaded).isEmpty,
        isTrue,
      );
      expect(loaded.isEmpty, isFalse);
      expect(loaded.copyWith(pendingRemovalIds: {'v1', 'v2'}).isEmpty, isTrue);
    });

    test('copyWith can reset nullable failures', () {
      const failed = FavoritesState(
        failure: NetworkFailure('x'),
        removalError: FavoriteRemovalError('v1', NetworkFailure('y')),
      );
      final reset = failed.copyWith(failure: () => null);
      expect(reset.failure, isNull);
      expect(
        reset.removalError,
        const FavoriteRemovalError('v1', NetworkFailure('y')),
      );
    });
  });

  test('initial state is FavoritesStatus.initial with no data', () {
    expect(build().state, const FavoritesState());
  });

  group('FavoritesRequested', () {
    blocTest<FavoritesBloc, FavoritesState>(
      'emits [loading, loaded] with favorites on success',
      setUp: () => when(
        () => getFavorites(any()),
      ).thenAnswer((_) async => Right([_v1, _v2])),
      build: build,
      act: (bloc) => bloc.add(const FavoritesRequested()),
      expect: () => [
        const FavoritesState(status: FavoritesStatus.loading),
        loaded,
      ],
      verify: (_) => verify(() => getFavorites(const NoParams())).called(1),
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'emits [loading, loaded] with an empty list',
      setUp: () => when(
        () => getFavorites(any()),
      ).thenAnswer((_) async => const Right([])),
      build: build,
      act: (bloc) => bloc.add(const FavoritesRequested()),
      expect: () => [
        const FavoritesState(status: FavoritesStatus.loading),
        isA<FavoritesState>().having((s) => s.isEmpty, 'isEmpty', isTrue),
      ],
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'emits [loading, failure] with the failure',
      setUp: () => when(
        () => getFavorites(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline'))),
      build: build,
      act: (bloc) => bloc.add(const FavoritesRequested()),
      expect: () => [
        const FavoritesState(status: FavoritesStatus.loading),
        const FavoritesState(
          status: FavoritesStatus.failure,
          failure: NetworkFailure('offline'),
        ),
      ],
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'retry clears the previous failure while loading',
      setUp: () => when(
        () => getFavorites(any()),
      ).thenAnswer((_) async => Right([_v1])),
      build: build,
      seed: () => const FavoritesState(
        status: FavoritesStatus.failure,
        failure: NetworkFailure('offline'),
      ),
      act: (bloc) => bloc.add(const FavoritesRequested()),
      expect: () => [
        const FavoritesState(status: FavoritesStatus.loading),
        FavoritesState(status: FavoritesStatus.loaded, favorites: [_v1]),
      ],
    );

    late Completer<Either<Failure, List<FavoriteVenue>>> load;
    blocTest<FavoritesBloc, FavoritesState>(
      'drops a second request while one is in flight (droppable)',
      setUp: () {
        load = Completer();
        when(() => getFavorites(any())).thenAnswer((_) => load.future);
      },
      build: build,
      act: (bloc) async {
        bloc
          ..add(const FavoritesRequested())
          ..add(const FavoritesRequested());
        await pumpEventQueue();
        load.complete(Right([_v1]));
      },
      expect: () => [
        const FavoritesState(status: FavoritesStatus.loading),
        FavoritesState(status: FavoritesStatus.loaded, favorites: [_v1]),
      ],
      verify: (_) => verify(() => getFavorites(any())).called(1),
    );
  });

  group('FavoriteRemoved', () {
    blocTest<FavoritesBloc, FavoritesState>(
      'hides the venue immediately, then drops it on success',
      setUp: () => when(
        () => removeFavorite(any()),
      ).thenAnswer((_) async => const Right(unit)),
      build: build,
      seed: () => loaded,
      act: (bloc) => bloc.add(const FavoriteRemoved('v1')),
      expect: () => [
        loaded.copyWith(pendingRemovalIds: {'v1'}),
        FavoritesState(status: FavoritesStatus.loaded, favorites: [_v2]),
      ],
      verify: (_) => verify(
        () => removeFavorite(const RemoveFavoriteParams('v1')),
      ).called(1),
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'rolls back and exposes removalError when removal fails',
      setUp: () => when(
        () => removeFavorite(any()),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline'))),
      build: build,
      seed: () => loaded,
      act: (bloc) => bloc.add(const FavoriteRemoved('v1')),
      expect: () => [
        isA<FavoritesState>().having((s) => s.visible, 'visible', [_v2]),
        loaded.copyWith(
          removalError: () =>
              const FavoriteRemovalError('v1', NetworkFailure('offline')),
        ),
      ],
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'clears a previous removalError on a new attempt',
      setUp: () => when(
        () => removeFavorite(any()),
      ).thenAnswer((_) async => const Right(unit)),
      build: build,
      seed: () => loaded.copyWith(
        removalError: () =>
            const FavoriteRemovalError('v1', NetworkFailure('x')),
      ),
      act: (bloc) => bloc.add(const FavoriteRemoved('v2')),
      expect: () => [
        loaded.copyWith(pendingRemovalIds: {'v2'}),
        FavoritesState(status: FavoritesStatus.loaded, favorites: [_v1]),
      ],
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'is ignored when the list is not loaded',
      build: build,
      seed: () => const FavoritesState(status: FavoritesStatus.loading),
      act: (bloc) => bloc.add(const FavoriteRemoved('v1')),
      expect: () => <FavoritesState>[],
      verify: (_) => verifyNever(() => removeFavorite(any())),
    );

    late Completer<Either<Failure, Unit>> first;
    late Completer<Either<Failure, Unit>> second;
    blocTest<FavoritesBloc, FavoritesState>(
      'ignores a duplicate removal of a pending venue',
      setUp: () {
        first = Completer();
        when(() => removeFavorite(any())).thenAnswer((_) => first.future);
      },
      build: build,
      seed: () => loaded,
      act: (bloc) async {
        bloc
          ..add(const FavoriteRemoved('v1'))
          ..add(const FavoriteRemoved('v1'));
        await pumpEventQueue();
        first.complete(const Right(unit));
      },
      expect: () => [
        loaded.copyWith(pendingRemovalIds: {'v1'}),
        FavoritesState(status: FavoritesStatus.loaded, favorites: [_v2]),
      ],
      verify: (_) => verify(() => removeFavorite(any())).called(1),
    );

    blocTest<FavoritesBloc, FavoritesState>(
      'removals of different venues run concurrently and resolve independently',
      setUp: () {
        first = Completer();
        second = Completer();
        when(
          () => removeFavorite(const RemoveFavoriteParams('v1')),
        ).thenAnswer((_) => first.future);
        when(
          () => removeFavorite(const RemoveFavoriteParams('v2')),
        ).thenAnswer((_) => second.future);
      },
      build: build,
      seed: () => loaded,
      act: (bloc) async {
        bloc
          ..add(const FavoriteRemoved('v1'))
          ..add(const FavoriteRemoved('v2'));
        await pumpEventQueue();
        // v2 finishes first and fails; v1 then succeeds.
        second.complete(const Left(ServerFailure('boom', code: 500)));
        await pumpEventQueue();
        first.complete(const Right(unit));
      },
      expect: () => [
        loaded.copyWith(pendingRemovalIds: {'v1'}),
        loaded.copyWith(pendingRemovalIds: {'v1', 'v2'}),
        loaded.copyWith(
          pendingRemovalIds: {'v1'},
          removalError: () => const FavoriteRemovalError(
            'v2',
            ServerFailure('boom', code: 500),
          ),
        ),
        FavoritesState(
          status: FavoritesStatus.loaded,
          favorites: [_v2],
          removalError: const FavoriteRemovalError(
            'v2',
            ServerFailure('boom', code: 500),
          ),
        ),
      ],
    );
    blocTest<FavoritesBloc, FavoritesState>(
      'two concurrent removals failing identically each emit a distinct error',
      setUp: () {
        first = Completer();
        second = Completer();
        when(
          () => removeFavorite(const RemoveFavoriteParams('v1')),
        ).thenAnswer((_) => first.future);
        when(
          () => removeFavorite(const RemoveFavoriteParams('v2')),
        ).thenAnswer((_) => second.future);
      },
      build: build,
      seed: () => loaded,
      act: (bloc) async {
        bloc
          ..add(const FavoriteRemoved('v1'))
          ..add(const FavoriteRemoved('v2'));
        await pumpEventQueue();
        first.complete(const Left(NetworkFailure('offline')));
        await pumpEventQueue();
        second.complete(const Left(NetworkFailure('offline')));
      },
      skip: 2,
      expect: () => [
        loaded.copyWith(
          pendingRemovalIds: {'v2'},
          removalError: () =>
              const FavoriteRemovalError('v1', NetworkFailure('offline')),
        ),
        loaded.copyWith(
          removalError: () =>
              const FavoriteRemovalError('v2', NetworkFailure('offline')),
        ),
      ],
    );
  });
}
