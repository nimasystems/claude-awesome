import 'package:app_name/app/di/injector.dart';
import 'package:app_name/core/extensions/context_x.dart';
import 'package:app_name/core/extensions/failure_message_x.dart';
import 'package:app_name/design_system/widgets/app_empty_view.dart';
import 'package:app_name/design_system/widgets/app_error_view.dart';
import 'package:app_name/design_system/widgets/app_loader.dart';
import 'package:app_name/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:app_name/features/favorites/presentation/bloc/favorites_event.dart';
import 'package:app_name/features/favorites/presentation/bloc/favorites_state.dart';
import 'package:app_name/features/favorites/presentation/widgets/favorite_venue_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Favorites screen: provides a screen-scoped [FavoritesBloc].
class FavoritesPage extends StatelessWidget {
  /// Creates the page.
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<FavoritesBloc>()..add(const FavoritesRequested()),
    child: const FavoritesView(),
  );
}

/// Renders [FavoritesState]. Public so widget tests can pump it with a mock.
class FavoritesView extends StatelessWidget {
  /// Creates the view.
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<FavoritesBloc, FavoritesState>(
      listenWhen: (previous, current) =>
          current.removalError != null &&
          previous.removalError != current.removalError,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.favoritesRemoveFailed(
                state.removalError!.failure.toMessage(l10n),
              ),
            ),
          ),
        ),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.favoritesTitle)),
        body: BlocBuilder<FavoritesBloc, FavoritesState>(
          builder: (context, state) => switch (state.status) {
            FavoritesStatus.initial ||
            FavoritesStatus.loading => const AppLoader(),
            FavoritesStatus.failure => AppErrorView(
              message: state.failure!.toMessage(l10n),
              onRetry: () =>
                  context.read<FavoritesBloc>().add(const FavoritesRequested()),
            ),
            FavoritesStatus.loaded when state.isEmpty => AppEmptyView(
              message: l10n.favoritesEmpty,
            ),
            FavoritesStatus.loaded => _FavoritesList(state: state),
          },
        ),
      ),
    );
  }
}

class _FavoritesList extends StatelessWidget {
  const _FavoritesList({required this.state});

  final FavoritesState state;

  @override
  Widget build(BuildContext context) {
    final venues = state.visible;
    return ListView.builder(
      itemCount: venues.length,
      itemBuilder: (context, index) {
        final venue = venues[index];
        return FavoriteVenueTile(
          key: ValueKey(venue.id),
          venue: venue,
          onRemove: () =>
              context.read<FavoritesBloc>().add(FavoriteRemoved(venue.id)),
        );
      },
    );
  }
}
