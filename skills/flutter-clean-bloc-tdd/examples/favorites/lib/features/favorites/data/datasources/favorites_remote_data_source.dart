import 'package:app_name/core/config/env.dart';
import 'package:app_name/core/fixtures/fixture_loader.dart';
import 'package:app_name/features/favorites/data/datasources/favorites_client.dart';
import 'package:app_name/features/favorites/data/models/favorite_venue_dto.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Remote source of the user's favorites. Thin: errors propagate and the
/// repository's `guard()` maps them (including `DioException`).
abstract interface class FavoritesRemoteDataSource {
  /// Fetches all favorites.
  Future<List<FavoriteVenueDto>> getFavorites();

  /// Deletes the favorite for [venueId].
  Future<void> removeFavorite(String venueId);
}

/// Talks to the REST API.
@Environment(Env.api)
@LazySingleton(as: FavoritesRemoteDataSource)
class FavoritesApiDataSource implements FavoritesRemoteDataSource {
  /// Creates the data source on top of the shared [Dio].
  FavoritesApiDataSource(Dio dio) : _client = FavoritesClient(dio);

  final FavoritesClient _client;

  @override
  Future<List<FavoriteVenueDto>> getFavorites() => _client.getFavorites();

  @override
  Future<void> removeFavorite(String venueId) =>
      _client.deleteFavorite(venueId);
}

/// Serves `assets/fixtures/favorites.json`; removals are kept in memory so
/// the mock flavor behaves like the real API within a session.
@Environment(Env.mock)
@LazySingleton(as: FavoritesRemoteDataSource)
class FavoritesMockDataSource implements FavoritesRemoteDataSource {
  /// Creates the mock data source.
  FavoritesMockDataSource(this._fixtures);

  final FixtureLoader _fixtures;
  final Set<String> _removedIds = {};

  @override
  Future<List<FavoriteVenueDto>> getFavorites() async =>
      (await _fixtures.list('favorites.json'))
          .map(FavoriteVenueDto.fromJson)
          .where((d) => !_removedIds.contains(d.id))
          .toList();

  @override
  Future<void> removeFavorite(String venueId) async => _removedIds.add(venueId);
}
