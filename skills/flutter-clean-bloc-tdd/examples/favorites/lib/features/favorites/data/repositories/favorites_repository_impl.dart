import 'package:app_name/core/error/failures.dart';
import 'package:app_name/core/error/guard.dart';
import 'package:app_name/features/favorites/data/datasources/favorites_remote_data_source.dart';
import 'package:app_name/features/favorites/data/mappers/favorite_venue_mapper.dart';
import 'package:app_name/features/favorites/domain/entities/favorite_venue.dart';
import 'package:app_name/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

/// Remote-only (transactional) implementation of [FavoritesRepository].
@LazySingleton(as: FavoritesRepository)
class FavoritesRepositoryImpl implements FavoritesRepository {
  /// Creates the repository.
  FavoritesRepositoryImpl(this._remote);

  final FavoritesRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<FavoriteVenue>>> getFavorites() => guard(
    'favorites.getFavorites',
    () async =>
        (await _remote.getFavorites()).map((d) => d.toEntity()).toList(),
  );

  @override
  Future<Either<Failure, Unit>> removeFavorite(String venueId) =>
      guard('favorites.removeFavorite', () async {
        await _remote.removeFavorite(venueId);
        return unit;
      });
}
