import 'package:equatable/equatable.dart';

/// Events handled by the favorites bloc.
sealed class FavoritesEvent extends Equatable {
  const FavoritesEvent();

  @override
  List<Object?> get props => [];
}

/// Screen opened or user tapped retry.
final class FavoritesRequested extends FavoritesEvent {
  /// Creates a [FavoritesRequested].
  const FavoritesRequested();
}

/// User tapped remove on a venue.
final class FavoriteRemoved extends FavoritesEvent {
  /// Creates a [FavoriteRemoved] for [venueId].
  const FavoriteRemoved(this.venueId);

  final String venueId;

  @override
  List<Object?> get props => [venueId];
}
