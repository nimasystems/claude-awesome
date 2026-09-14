import 'package:app_name/core/error/failures.dart';
import 'package:app_name/core/usecase/usecase.dart';
import 'package:app_name/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

/// Params for [RemoveFavorite].
class RemoveFavoriteParams extends Equatable {
  /// Creates [RemoveFavoriteParams].
  const RemoveFavoriteParams(this.venueId);

  /// Id of the venue to remove from favorites.
  final String venueId;

  @override
  List<Object?> get props => [venueId];
}

/// Removes a venue from the signed-in user's favorites.
@injectable
class RemoveFavorite implements UseCase<Unit, RemoveFavoriteParams> {
  /// Creates [RemoveFavorite].
  const RemoveFavorite(this._repository);

  final FavoritesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(RemoveFavoriteParams params) =>
      _repository.removeFavorite(params.venueId);
}
