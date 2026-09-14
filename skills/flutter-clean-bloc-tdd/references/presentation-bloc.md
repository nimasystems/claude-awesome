# Presentation & BLoC reference

## Contents
1. State design
2. Events
3. Bloc body (fold, concurrency, optimistic updates)
4. Cubit shape
5. Page / View split and providing blocs
6. One-shot effects
7. Failure → localized message
8. Widgets, theming, l10n
9. Anti-patterns

---

## 1. State: one class, status enum, copyWith

Full verified version: `examples/favorites/lib/features/favorites/presentation/bloc/favorites_state.dart`.

```dart
/// A rolled-back removal. venueId gives it identity: two equal failures for
/// different venues are distinct states, so each fires its own snackbar.
final class FavoriteRemovalError extends Equatable {
  const FavoriteRemovalError(this.venueId, this.failure);
  final String venueId;
  final Failure failure;
  @override
  List<Object?> get props => [venueId, failure];
}

enum FavoritesStatus { initial, loading, loaded, failure }

class FavoritesState extends Equatable {
  const FavoritesState({
    this.status = FavoritesStatus.initial,
    this.favorites = const [],
    this.pendingRemovalIds = const {},
    this.failure,
    this.removalError,
  });

  final FavoritesStatus status;
  final List<FavoriteVenue> favorites;            // server truth, intact during optimistic removal
  final Set<String> pendingRemovalIds;            // hidden while removal is in flight
  final Failure? failure;                         // load failure → full-screen error + retry
  final FavoriteRemovalError? removalError;       // one-shot → snackbar (see §6)

  List<FavoriteVenue> get visible => favorites.where((f) => !pendingRemovalIds.contains(f.id)).toList();
  bool get isEmpty => status == FavoritesStatus.loaded && visible.isEmpty;

  FavoritesState copyWith({
    FavoritesStatus? status,
    List<FavoriteVenue>? favorites,
    Set<String>? pendingRemovalIds,
    Failure? Function()? failure,                         // closure = can reset to null
    FavoriteRemovalError? Function()? removalError,
  }) =>
      FavoritesState(
        status: status ?? this.status,
        favorites: favorites ?? this.favorites,
        pendingRemovalIds: pendingRemovalIds ?? this.pendingRemovalIds,
        failure: failure != null ? failure() : this.failure,
        removalError: removalError != null ? removalError() : this.removalError,
      );

  @override
  List<Object?> get props => [status, favorites, pendingRemovalIds, failure, removalError];
}
```

Why not sealed `Loading/Loaded/Error` subclasses: data must survive transitions — optimistic rollback needs the source list, and refresh must keep the list on screen (§3). Derived UI logic (`visible`, `isEmpty`, `canSubmit`) lives as getters on the state — testable without widgets.

Multi-phase flows use a richer enum (`CheckoutStatus { loading, ready, applyingVoucher, confirming, success, failure }`).

## 2. Events

```dart
sealed class FavoritesEvent extends Equatable {
  const FavoritesEvent();
  @override
  List<Object?> get props => [];
}

/// Screen opened or user tapped retry.
final class FavoritesRequested extends FavoritesEvent {
  const FavoritesRequested();
}

/// User swiped/tapped remove on a venue.
final class FavoriteRemoved extends FavoritesEvent {
  const FavoriteRemoved(this.venueId);
  final String venueId;
  @override
  List<Object?> get props => [venueId];
}
```

One `on<Subtype>` per event (not a single handler with `event.when`). Events, state and bloc are three separate files (plain imports, no `part of`).

## 3. Bloc

```dart
@injectable
class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  FavoritesBloc(this._getFavorites, this._removeFavorite) : super(const FavoritesState()) {
    on<FavoritesRequested>(_onRequested, transformer: droppable());
    on<FavoriteRemoved>(_onRemoved, transformer: concurrent());
  }

  final GetFavorites _getFavorites;
  final RemoveFavorite _removeFavorite;

  Future<void> _onRequested(FavoritesRequested event, Emitter<FavoritesState> emit) async {
    emit(state.copyWith(status: FavoritesStatus.loading, failure: () => null));
    final result = await _getFavorites(const NoParams());
    emit(result.fold(
      (failure) => state.copyWith(status: FavoritesStatus.failure, failure: () => failure),
      (favorites) => state.copyWith(status: FavoritesStatus.loaded, favorites: favorites),
    ));
  }

  Future<void> _onRemoved(FavoriteRemoved event, Emitter<FavoritesState> emit) async {
    if (state.status != FavoritesStatus.loaded || state.pendingRemovalIds.contains(event.venueId)) return;
    // Optimistic: hide immediately, keep the source list intact for rollback.
    emit(state.copyWith(pendingRemovalIds: {...state.pendingRemovalIds, event.venueId}, removalError: () => null));
    final result = await _removeFavorite(RemoveFavoriteParams(event.venueId));
    final pending = {...state.pendingRemovalIds}..remove(event.venueId); // re-read state AFTER await
    emit(result.fold(
      (failure) => state.copyWith(pendingRemovalIds: pending, removalError: () => FavoriteRemovalError(event.venueId, failure)),
      (_) => state.copyWith(
        pendingRemovalIds: pending,
        favorites: state.favorites.where((f) => f.id != event.venueId).toList(),
      ),
    ));
  }
}
```

**Refresh (data already on screen):** don't blank the list. Add `final bool isRefreshing` to state and branch in the handler:

```dart
final hasData = state.status == FavoritesStatus.loaded;
emit(hasData
    ? state.copyWith(isRefreshing: true)
    : state.copyWith(status: FavoritesStatus.loading, failure: () => null));
final result = await _getFavorites(const NoParams());
emit(result.fold(
  (f) => hasData
      ? state.copyWith(isRefreshing: false, refreshError: () => f)       // one-shot snackbar, list stays
      : state.copyWith(status: FavoritesStatus.failure, failure: () => f),
  (list) => state.copyWith(status: FavoritesStatus.loaded, favorites: list, isRefreshing: false),
));
```

The View wraps the list in `RefreshIndicator` (or shows a thin progress bar while `isRefreshing`).

Rules:
- Always read `state` again after an `await` — it may have changed.
- Never `emit` after `isClosed`; for stream subscriptions use `emit.forEach`/`emit.onEach` so cancellation is automatic, or cancel in `close()`.
- Concurrency transformers (`bloc_concurrency`): `droppable()` for load/submit/retry, `restartable()` for search/filters (combine with an injected `@Named` debounce `Duration`), `sequential()` for ordered mutations on the same resource, `concurrent()` + per-id guard for independent item actions.
- Blocs don't log transitions (the `AppBlocObserver` does) and don't know about `BuildContext`, routes, or l10n.
- Streams (chat, live data): `StreamUseCase` + `emit.forEach(stream, onData: ...)`.

## 4. Cubit shape

```dart
@injectable
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._getProfile) : super(const ProfileState());
  final GetProfile _getProfile;

  Future<void> load() async {
    emit(state.copyWith(status: ProfileStatus.loading));
    final result = await _getProfile(const NoParams());
    emit(result.fold(
      (f) => state.copyWith(status: ProfileStatus.failure, failure: () => f),
      (p) => state.copyWith(status: ProfileStatus.loaded, profile: p),
    ));
  }
}
```

Forms: Cubit with field methods (`emailChanged(String)`) and validated value objects (`formz` inputs are fine) in state; `canSubmit` getter.

## 5. Page / View split

Full verified version: `examples/favorites/lib/features/favorites/presentation/pages/favorites_page.dart`.

```dart
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => getIt<FavoritesBloc>()..add(const FavoritesRequested()),
        child: const FavoritesView(),
      );
}

/// Public so widget tests can pump it with a MockBloc.
class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<FavoritesBloc, FavoritesState>(
      listenWhen: (p, c) => c.removalError != null && p.removalError != c.removalError,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          // Say WHAT failed, then why: "Couldn't remove favorite. No internet connection."
          content: Text(l10n.favoritesRemoveFailed(state.removalError!.failure.toMessage(l10n))),
        )),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.favoritesTitle)),
        body: BlocBuilder<FavoritesBloc, FavoritesState>(
          builder: (context, state) => switch (state.status) {
            FavoritesStatus.initial || FavoritesStatus.loading => const AppLoader(),
            FavoritesStatus.failure => AppErrorView(
                message: state.failure!.toMessage(l10n),
                onRetry: () => context.read<FavoritesBloc>().add(const FavoritesRequested()),
              ),
            FavoritesStatus.loaded when state.isEmpty => AppEmptyView(message: l10n.favoritesEmpty),
            FavoritesStatus.loaded => _FavoritesList(state: state),
          },
        ),
      ),
    );
  }
}
```

- Page = provider only. View = rendering. Widgets under `widgets/` take plain data + callbacks (no bloc lookups) when practical.
- `AppLoader`, `AppErrorView` (with `retryKey`), `AppEmptyView` are in `templates/lib/design_system/widgets/`.
- Use `BlocSelector`/`context.select` to rebuild only on the slice a widget needs.
- App-scoped blocs: resolved from `getIt` once in `app.dart`, exposed via `MultiBlocProvider` with `BlocProvider.value`.
- Don't hold a bloc in `State` + `initState` + manual `close()` (older pattern) — `BlocProvider(create:)` owns lifecycle.
- `StatefulWidget` only for ephemeral UI concerns (controllers, animations, focus).

## 6. One-shot effects

Snackbars, navigation after success, dialogs: model as state (`removalError`, `refreshError`, `status == success`) + `BlocListener` with `listenWhen` comparing previous/current.

- Give the effect **identity** (wrap the failure with the item id, or an incrementing attempt counter) — `Equatable` failures are equal by value, so two identical failures in a row would otherwise not fire.
- Clear the field when the next attempt starts.
- No side-channel `StreamController`s on the bloc.

Navigation on success: listener calls `context.goNamed(Routes.orderSuccess, extra: state.sale)`.

## 7. Failure → message

```dart
// presentation/failure_message.dart (core or feature)
extension FailureMessageX on Failure {
  String toMessage(AppLocalizations l10n) => switch (this) {
        NetworkFailure() => l10n.errorNoConnection,
        AuthFailure() => l10n.errorSessionExpired,
        NotFoundFailure() => l10n.errorNotFound,
        ValidationFailure(:final fieldErrors) when fieldErrors.isNotEmpty => fieldErrors.values.first,
        ValidationFailure() || ServerFailure() || CacheFailure() || UnknownFailure() => l10n.errorGeneric,
      };
}
```

Exhaustive `switch` on the sealed `Failure` — adding a failure type breaks compilation until the UI handles it. Never show `failure.message` (developer text) to users.

## 8. Widgets, theming, l10n

- Colors/spacing/radii/typography from `AppTokens` via theme extension (`context.tokens.spacing.md`); no `Color(0xFF...)`, no magic numbers.
- Reusable UI in `design_system/widgets/` (AppButton, AppLoader, AppErrorView, AppEmptyView) with a gallery page + golden tests.
- Every user-facing string in `lib/l10n/arb/app_en.arb` (+ other locales), accessed as `context.l10n.key`. Keys are `featureThing` camelCase with `@description`.
- Accessibility: `Semantics` labels on icon-only buttons; tap targets ≥ 48dp.
- Keys for testable widgets live on the widget that renders them (`AppErrorView.retryKey`, `FavoriteVenueTile.removeKey(id)`).
- Network images: always provide an error fallback (`onForegroundImageError`/`errorBuilder`) — also required for widget tests, where every HTTP request returns 400.
- Dates: entities hold UTC; format with `DateFormat.yMMMd(locale).format(date.toLocal())` (or an ARB `DateTime` placeholder) only in the UI.

## 9. Anti-patterns

| Don't | Do |
|---|---|
| `setState` for data a bloc should own | bloc/cubit state |
| Bloc calls repository or `getIt` | inject use cases |
| Bloc imports `package:flutter/material.dart` for `BuildContext`/`Navigator` | expose state; listener navigates |
| God bloc handling 3 screens | one bloc per screen/flow; share via use cases or app-scoped bloc |
| `part of` + freezed unions + `event.when` in one handler | sealed Equatable events, one `on<>` per event |
| Showing `failure.message` or `e.toString()` to users | `failure.toMessage(l10n)` |
| `Future.delayed` to "wait for" state | await the use case / listen to the stream |
