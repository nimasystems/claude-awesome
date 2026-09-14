import 'package:equatable/equatable.dart';

/// A venue the signed-in user has marked as a favorite.
class FavoriteVenue extends Equatable {
  /// Creates a [FavoriteVenue].
  const FavoriteVenue({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.addedAt,
  });

  /// Venue id; also the id used to remove the favorite.
  final String id;

  /// Display name of the venue.
  final String name;

  /// Cover image of the venue.
  final Uri imageUrl;

  /// When the venue was added to favorites (UTC).
  final DateTime addedAt;

  @override
  List<Object?> get props => [id, name, imageUrl, addedAt];
}
