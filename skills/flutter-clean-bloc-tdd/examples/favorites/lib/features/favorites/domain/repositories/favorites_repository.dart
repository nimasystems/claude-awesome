import 'package:app_name/core/error/failures.dart';
import 'package:app_name/features/favorites/domain/entities/favorite_venue.dart';
import 'package:fpdart/fpdart.dart';

/// Access to the signed-in user's favorite venues.
abstract interface class FavoritesRepository {
  /// Favorites for the signed-in user, in the order the server returns them.
  Future<Either<Failure, List<FavoriteVenue>>> getFavorites();

  /// Removes the venue with [venueId] from favorites.
  Future<Either<Failure, Unit>> removeFavorite(String venueId);
}
