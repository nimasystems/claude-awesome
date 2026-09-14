import 'package:app_name/core/error/failures.dart';
import 'package:app_name/features/favorites/domain/entities/favorite_venue.dart';
import 'package:equatable/equatable.dart';

/// A failed optimistic removal. Carries [venueId] so two identical failures
/// for different venues are distinct states (each triggers its own snackbar).
final class FavoriteRemovalError extends Equatable {
  /// Creates a [FavoriteRemovalError].
  const FavoriteRemovalError(this.venueId, this.failure);

  /// The venue whose removal was rolled back.
  final String venueId;

  /// Why it failed.
  final Failure failure;

  @override
  List<Object?> get props => [venueId, failure];
}

/// Load lifecycle of the favorites list.
enum FavoritesStatus { initial, loading, loaded, failure }

/// State of the favorites screen.
class FavoritesState extends Equatable {
  /// Creates a [FavoritesState].
  const FavoritesState({
    this.status = FavoritesStatus.initial,
    this.favorites = const [],
    this.pendingRemovalIds = const {},
    this.failure,
    this.removalError,
  });

  final FavoritesStatus status;

  /// Source of truth from the server; kept intact during optimistic removal
  /// so a failed removal can roll back.
  final List<FavoriteVenue> favorites;

  /// Venues hidden optimistically while their removal is in flight.
  final Set<String> pendingRemovalIds;

  /// Load failure → full-screen error with retry.
  final Failure? failure;

  /// Last rolled-back removal → one-shot snackbar.
  final FavoriteRemovalError? removalError;

  /// Favorites to render (pending removals hidden).
  List<FavoriteVenue> get visible =>
      favorites.where((f) => !pendingRemovalIds.contains(f.id)).toList();

  /// Loaded with nothing to show.
  bool get isEmpty => status == FavoritesStatus.loaded && visible.isEmpty;

  /// Copies with overrides; nullable failures are reset via closures.
  FavoritesState copyWith({
    FavoritesStatus? status,
    List<FavoriteVenue>? favorites,
    Set<String>? pendingRemovalIds,
    Failure? Function()? failure,
    FavoriteRemovalError? Function()? removalError,
  }) => FavoritesState(
    status: status ?? this.status,
    favorites: favorites ?? this.favorites,
    pendingRemovalIds: pendingRemovalIds ?? this.pendingRemovalIds,
    failure: failure != null ? failure() : this.failure,
    removalError: removalError != null ? removalError() : this.removalError,
  );

  @override
  List<Object?> get props => [
    status,
    favorites,
    pendingRemovalIds,
    failure,
    removalError,
  ];
}
