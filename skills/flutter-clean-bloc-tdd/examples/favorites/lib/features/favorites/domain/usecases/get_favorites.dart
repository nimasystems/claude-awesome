import 'package:app_name/core/error/failures.dart';
import 'package:app_name/core/usecase/usecase.dart';
import 'package:app_name/features/favorites/domain/entities/favorite_venue.dart';
import 'package:app_name/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

/// Loads the signed-in user's favorite venues.
@injectable
class GetFavorites implements UseCase<List<FavoriteVenue>, NoParams> {
  /// Creates [GetFavorites].
  const GetFavorites(this._repository);

  final FavoritesRepository _repository;

  @override
  Future<Either<Failure, List<FavoriteVenue>>> call(NoParams params) =>
      _repository.getFavorites();
}
