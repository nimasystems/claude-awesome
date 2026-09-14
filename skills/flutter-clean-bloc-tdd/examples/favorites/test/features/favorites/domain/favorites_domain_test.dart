import 'package:app_name/core/error/failures.dart';
import 'package:app_name/core/usecase/usecase.dart';
import 'package:app_name/features/favorites/domain/entities/favorite_venue.dart';
import 'package:app_name/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:app_name/features/favorites/domain/usecases/get_favorites.dart';
import 'package:app_name/features/favorites/domain/usecases/remove_favorite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

FavoriteVenue _venue({String id = 'v1', String name = 'Blue Note'}) =>
    FavoriteVenue(
      id: id,
      name: name,
      imageUrl: Uri.parse('https://cdn.example.com/$id.jpg'),
      addedAt: DateTime.utc(2026, 9, 2),
    );

void main() {
  group('FavoriteVenue', () {
    test('instances with the same values are equal', () {
      expect(_venue(), _venue());
    });

    test('instances with different values are not equal', () {
      expect(_venue(), isNot(_venue(id: 'v2')));
      expect(_venue(), isNot(_venue(name: 'Other')));
    });
  });

  group('RemoveFavoriteParams', () {
    test('equality is based on venueId', () {
      expect(
        const RemoveFavoriteParams('v1'),
        const RemoveFavoriteParams('v1'),
      );
      expect(
        const RemoveFavoriteParams('v1'),
        isNot(const RemoveFavoriteParams('v2')),
      );
    });
  });

  group('use cases', () {
    late _MockFavoritesRepository repository;

    setUp(() => repository = _MockFavoritesRepository());

    group('GetFavorites', () {
      test('returns the repository result on success', () async {
        when(
          () => repository.getFavorites(),
        ).thenAnswer((_) async => Right([_venue()]));

        final result = await GetFavorites(repository)(const NoParams());

        expect(result.getRight().toNullable(), [_venue()]);
        verify(() => repository.getFavorites()).called(1);
      });

      test('returns the repository failure', () async {
        when(
          () => repository.getFavorites(),
        ).thenAnswer((_) async => const Left(NetworkFailure('offline')));

        final result = await GetFavorites(repository)(const NoParams());

        expect(result.getLeft().toNullable(), const NetworkFailure('offline'));
      });
    });

    group('RemoveFavorite', () {
      test('delegates venueId to the repository', () async {
        when(
          () => repository.removeFavorite('v1'),
        ).thenAnswer((_) async => const Right(unit));

        final result = await RemoveFavorite(repository)(
          const RemoveFavoriteParams('v1'),
        );

        expect(result, const Right<Failure, Unit>(unit));
        verify(() => repository.removeFavorite('v1')).called(1);
      });

      test('returns the repository failure', () async {
        when(
          () => repository.removeFavorite('v1'),
        ).thenAnswer((_) async => const Left(ServerFailure('boom', code: 500)));

        final result = await RemoveFavorite(repository)(
          const RemoveFavoriteParams('v1'),
        );

        expect(
          result.getLeft().toNullable(),
          const ServerFailure('boom', code: 500),
        );
      });
    });
  });
}
