import 'package:app_name/core/usecase/usecase.dart';
import 'package:app_name/features/favorites/domain/usecases/get_favorites.dart';
import 'package:app_name/features/favorites/domain/usecases/remove_favorite.dart';
import 'package:app_name/features/favorites/presentation/bloc/favorites_event.dart';
import 'package:app_name/features/favorites/presentation/bloc/favorites_state.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Loads favorites and removes them optimistically with rollback on failure.
@injectable
class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  /// Creates the bloc.
  FavoritesBloc(this._getFavorites, this._removeFavorite)
    : super(const FavoritesState()) {
    on<FavoritesRequested>(_onRequested, transformer: droppable());
    on<FavoriteRemoved>(_onRemoved, transformer: concurrent());
  }

  final GetFavorites _getFavorites;
  final RemoveFavorite _removeFavorite;

  Future<void> _onRequested(
    FavoritesRequested event,
    Emitter<FavoritesState> emit,
  ) async {
    emit(state.copyWith(status: FavoritesStatus.loading, failure: () => null));
    final result = await _getFavorites(const NoParams());
    emit(
      result.fold(
        (failure) => state.copyWith(
          status: FavoritesStatus.failure,
          failure: () => failure,
        ),
        (favorites) => state.copyWith(
          status: FavoritesStatus.loaded,
          favorites: favorites,
        ),
      ),
    );
  }

  Future<void> _onRemoved(
    FavoriteRemoved event,
    Emitter<FavoritesState> emit,
  ) async {
    if (state.status != FavoritesStatus.loaded ||
        state.pendingRemovalIds.contains(event.venueId)) {
      return;
    }
    // Optimistic: hide immediately, keep the source list for rollback.
    emit(
      state.copyWith(
        pendingRemovalIds: {...state.pendingRemovalIds, event.venueId},
        removalError: () => null,
      ),
    );
    final result = await _removeFavorite(RemoveFavoriteParams(event.venueId));
    // Re-read state after the await: other removals may have completed.
    final pending = {...state.pendingRemovalIds}..remove(event.venueId);
    emit(
      result.fold(
        (failure) => state.copyWith(
          pendingRemovalIds: pending,
          removalError: () => FavoriteRemovalError(event.venueId, failure),
        ),
        (_) => state.copyWith(
          pendingRemovalIds: pending,
          favorites: state.favorites
              .where((f) => f.id != event.venueId)
              .toList(),
        ),
      ),
    );
  }
}
