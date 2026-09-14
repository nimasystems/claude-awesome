import 'package:json_annotation/json_annotation.dart';

part 'favorite_venue_dto.g.dart';

/// Wire model for an item of `GET /v1/favorites`.
///
/// Hand-written because there is no OpenAPI spec for this endpoint.
@JsonSerializable(createToJson: false)
class FavoriteVenueDto {
  /// Creates a [FavoriteVenueDto].
  const FavoriteVenueDto({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.addedAt,
  });

  /// Decodes a JSON object.
  factory FavoriteVenueDto.fromJson(Map<String, dynamic> json) =>
      _$FavoriteVenueDtoFromJson(json);

  final String id;
  final String name;
  final String imageUrl;
  final DateTime addedAt;
}
