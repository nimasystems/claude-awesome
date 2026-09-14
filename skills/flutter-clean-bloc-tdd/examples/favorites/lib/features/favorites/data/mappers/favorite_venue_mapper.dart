import 'package:app_name/features/favorites/data/models/favorite_venue_dto.dart';
import 'package:app_name/features/favorites/domain/entities/favorite_venue.dart';

/// DTO → entity mapping.
extension FavoriteVenueDtoX on FavoriteVenueDto {
  /// Maps to a domain [FavoriteVenue]; timestamps are normalised to UTC.
  FavoriteVenue toEntity() => FavoriteVenue(
    id: id,
    name: name,
    imageUrl: Uri.parse(imageUrl),
    addedAt: addedAt.toUtc(),
  );
}
