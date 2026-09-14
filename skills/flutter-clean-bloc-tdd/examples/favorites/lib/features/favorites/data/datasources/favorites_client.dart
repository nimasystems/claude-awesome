import 'package:app_name/features/favorites/data/models/favorite_venue_dto.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'favorites_client.g.dart';

/// Retrofit client for the favorites endpoints (hand-written: no OpenAPI spec).
@RestApi()
abstract class FavoritesClient {
  /// Creates a client on top of [dio].
  factory FavoritesClient(Dio dio) = _FavoritesClient;

  /// `GET /v1/favorites`.
  @GET('/v1/favorites')
  Future<List<FavoriteVenueDto>> getFavorites();

  /// `DELETE /v1/favorites/{id}`.
  @DELETE('/v1/favorites/{id}')
  Future<void> deleteFavorite(@Path('id') String id);
}
