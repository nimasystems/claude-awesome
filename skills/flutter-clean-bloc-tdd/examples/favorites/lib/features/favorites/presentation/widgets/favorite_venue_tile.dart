import 'package:app_name/core/extensions/context_x.dart';
import 'package:app_name/features/favorites/domain/entities/favorite_venue.dart';
import 'package:flutter/material.dart';

/// A favorite venue row with a remove action.
class FavoriteVenueTile extends StatelessWidget {
  /// Creates a [FavoriteVenueTile].
  const FavoriteVenueTile({
    required this.venue,
    required this.onRemove,
    super.key,
  });

  /// Key of the remove button for the venue with [venueId], for tests.
  static Key removeKey(String venueId) => Key('favorite_remove_$venueId');

  final FavoriteVenue venue;

  /// Called when the user taps remove.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: CircleAvatar(
        foregroundImage: NetworkImage(venue.imageUrl.toString()),
        // Image failures fall back to the placeholder icon below.
        onForegroundImageError: (_, _) {},
        child: const Icon(Icons.storefront),
      ),
      title: Text(venue.name),
      subtitle: Text(l10n.favoritesAddedOn(venue.addedAt.toLocal())),
      trailing: IconButton(
        key: removeKey(venue.id),
        icon: const Icon(Icons.favorite),
        tooltip: l10n.favoritesRemoveTooltip(venue.name),
        onPressed: onRemove,
      ),
    );
  }
}
