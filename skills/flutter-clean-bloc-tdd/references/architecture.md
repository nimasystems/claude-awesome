# Architecture reference

## Contents
1. Project layout
2. Core types (Failure, AppException, UseCase)
3. Domain layer
4. Data layer (DTOs, clients, mappers, data sources, repository `guard()`)
5. Dependency injection (injectable + environments)
6. Flavors and bootstrap
7. Routing (go_router)
8. Cross-cutting services (logging, analytics, connectivity)

---

## 1. Project layout

```
lib/
  main_dev.dart · main_staging.dart · main_prod.dart   # each: bootstrap(Flavor.x)
  bootstrap.dart
  app/
    app.dart                  # MaterialApp.router + MultiBlocProvider (app-scoped blocs)
    di/        injector.dart · injector.config.dart (gen) · register_module.dart
    flavor/    flavor.dart (Flavor enum + FlavorConfig)
    router/    app_router.dart · routes.dart · guards.dart · app_shell.dart · go_router_refresh_stream.dart
    observer/  app_bloc_observer.dart
  core/
    config/       env.dart (Env.mock/Env.api + --dart-define AppConfig — in core so data/ can import it)
    error/        failures.dart · exceptions.dart · guard.dart
    usecase/      usecase.dart
    logging/      logger_service.dart
    network/      interceptors/ (auth, logging) · api/ (GENERATED retrofit + DTOs — never edit)
    cache/        hive_service.dart · box_names.dart
    sync/         outbox_store.dart · sync_service.dart
    analytics/    analytics_service.dart · analytics_event.dart (sealed) · firebase_/noop_ impls
    connectivity/ connectivity_cubit.dart
    extensions/   context_x.dart (context.l10n) · failure_message_x.dart
    fixtures/     fixture_loader.dart
  design_system/  theme/ (app_theme.dart; app_tokens.dart only if GENERATED upstream) · widgets/ · gallery/
  features/<feature>/domain|data|presentation
  l10n/  arb/app_en.arb (+ other locales) · gen/ (generated)
test/  mirrors lib/ (per layer — see testing-tdd.md)
integration_test/
```

Naming: files `snake_case.dart`; constants `lowerCamelCase` (no SCREAMING_CASE); use cases verb-noun (`RemoveFavorite`); events past-tense verb phrases (`FavoriteRemoved`, `FavoritesRequested`); impls `XRepositoryImpl`, data sources `XApiDataSource` / `XMockDataSource`. Imports: `package:<app>/...` absolute across features, relative OK inside a feature; no barrel files that leak `data/`.

## 2. Core types

Copy from `templates/lib/core/` for new projects.

```dart
// core/error/failures.dart
sealed class Failure extends Equatable {
  const Failure(this.message, {this.cause});
  final String message;
  final Object? cause;
  @override
  List<Object?> get props => [message];
}
final class NetworkFailure extends Failure { const NetworkFailure(super.message, {super.cause}); }
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.code, super.cause});
  final int? code;
  @override List<Object?> get props => [message, code];
}
final class AuthFailure extends Failure { const AuthFailure(super.message, {super.cause}); }
final class NotFoundFailure extends Failure { const NotFoundFailure(super.message, {super.cause}); }
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}, super.cause});
  final Map<String, String> fieldErrors;
  @override List<Object?> get props => [message, fieldErrors];
}
final class CacheFailure extends Failure { const CacheFailure(super.message, {super.cause}); }
final class UnknownFailure extends Failure {
  const UnknownFailure({String message = 'Something went wrong', super.cause}) : super(message);
}
```

Add domain-specific failures (e.g. `PaymentFailure(declineCode)`, `DeviceFailure`) as new `final class`es — sealed keeps `switch` exhaustive in the UI mapper. Avoid a coarse 5-type hierarchy distinguished only by message strings.

```dart
// core/error/exceptions.dart — thrown ONLY by data sources / clients
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});
  final String message;
  final Object? cause;
  Failure toFailure();
}
final class ApiException extends AppException {
  const ApiException(super.message, {this.statusCode, super.cause});
  final int? statusCode;
  @override
  Failure toFailure() => switch (statusCode) {
        401 || 403 => AuthFailure(message, cause: cause),
        404 => NotFoundFailure(message, cause: cause),
        422 => ValidationFailure(message, cause: cause),
        _ => ServerFailure(message, code: statusCode, cause: cause),
      };
}
final class NetworkException extends AppException { ... toFailure() => NetworkFailure(message, cause: cause); }
final class CacheException extends AppException { ... toFailure() => CacheFailure(message, cause: cause); }
```

**Dio errors:** Dio always throws `DioException` — an interceptor cannot change the thrown type (it can only attach an `AppException` as `error` via `handler.reject`). So `guard()` maps `DioException` with `appExceptionFromDio` (preferring an attached `AppException`). Data sources and clients stay thin and never catch.

```dart
// core/usecase/usecase.dart
abstract interface class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}
abstract interface class StreamUseCase<T, Params> {
  Stream<Either<Failure, T>> call(Params params);
}
class NoParams extends Equatable {
  const NoParams();
  @override
  List<Object?> get props => [];
}
```

Use plain `Future<Either<Failure, T>>` — not `TaskEither`. Consume with `.fold(...)`.

## 3. Domain layer

```dart
// domain/entities/favorite_venue.dart — pure Dart, Equatable; add copyWith only when used
class FavoriteVenue extends Equatable {
  const FavoriteVenue({required this.id, required this.name, required this.imageUrl, required this.addedAt});
  final String id;
  final String name;
  final Uri imageUrl;
  final DateTime addedAt; // UTC; convert with toLocal() only when formatting for display
  @override
  List<Object?> get props => [id, name, imageUrl, addedAt];
}

// domain/repositories/favorites_repository.dart
abstract interface class FavoritesRepository {
  /// Favorites for the signed-in user, newest first.
  Future<Either<Failure, List<FavoriteVenue>>> getFavorites();
  Future<Either<Failure, Unit>> removeFavorite(String venueId);
}

// domain/usecases/remove_favorite.dart
class RemoveFavoriteParams extends Equatable {
  const RemoveFavoriteParams(this.venueId);
  final String venueId;
  @override
  List<Object?> get props => [venueId];
}

@injectable
class RemoveFavorite implements UseCase<Unit, RemoveFavoriteParams> {
  const RemoveFavorite(this._repository);
  final FavoritesRepository _repository;
  @override
  Future<Either<Failure, Unit>> call(RemoveFavoriteParams params) => _repository.removeFavorite(params.venueId);
}
```

- Use cases live in `domain/usecases/` (not `data/`).
- Value objects (`Money` in minor units, `EmailAddress`) live in `core/value_objects/` when shared.
- Business rules (e.g. "can confirm checkout") are getters on entities/state, never in widgets.
- Keep Hive annotations **off** domain entities; persistence models live in `data/` (older projects merged them — don't copy that).

## 4. Data layer

**DTOs & clients — two cases:**

| Situation | DTO | Client |
|---|---|---|
| OpenAPI spec exists | generated by `swagger_parser` (freezed) into `core/network/api/` — gitignored, excluded from lint/coverage, never edited | generated retrofit client per tag |
| No spec | hand-written `@JsonSerializable(createToJson: false)` in `features/<f>/data/models/<x>_dto.dart` | hand-written `@RestApi()` retrofit client in `features/<f>/data/datasources/<f>_client.dart` |

Import generated DTOs `as dto` when names clash with entities. Keep DTO fields wire-shaped (`String imageUrl`, `DateTime addedAt`); conversion happens in the mapper.

**Mappers:** extension methods on the DTO, plus top-level enum converters.

```dart
// data/mappers/favorite_venue_mapper.dart
extension FavoriteVenueDtoX on FavoriteVenueDto {
  FavoriteVenue toEntity() => FavoriteVenue(
        id: id,
        name: name,
        imageUrl: Uri.parse(imageUrl),
        addedAt: addedAt.toUtc(),
      );
}
```

**Data source:** interface + api impl + mock impl in ONE file, selected by DI environment. Thin — no try/catch. The mock impl reads `assets/fixtures/*.json` through `FixtureLoader` (tests read the same files via `test/helpers/fixtures.dart`, so they cannot drift) and **keeps in-memory state** so the dev flavor behaves like the real API within a session.

```dart
// data/datasources/favorites_remote_data_source.dart
abstract interface class FavoritesRemoteDataSource {
  Future<List<FavoriteVenueDto>> getFavorites();
  Future<void> removeFavorite(String venueId);
}

@Environment(Env.api)
@LazySingleton(as: FavoritesRemoteDataSource)
class FavoritesApiDataSource implements FavoritesRemoteDataSource {
  FavoritesApiDataSource(Dio dio) : _client = FavoritesClient(dio);
  final FavoritesClient _client;
  @override
  Future<List<FavoriteVenueDto>> getFavorites() => _client.getFavorites();
  @override
  Future<void> removeFavorite(String venueId) => _client.deleteFavorite(venueId);
}

@Environment(Env.mock)
@LazySingleton(as: FavoritesRemoteDataSource)
class FavoritesMockDataSource implements FavoritesRemoteDataSource {
  FavoritesMockDataSource(this._fixtures);
  final FixtureLoader _fixtures;
  final Set<String> _removedIds = {};
  @override
  Future<List<FavoriteVenueDto>> getFavorites() async => (await _fixtures.list('favorites.json'))
      .map(FavoriteVenueDto.fromJson)
      .where((d) => !_removedIds.contains(d.id))
      .toList();
  @override
  Future<void> removeFavorite(String venueId) async => _removedIds.add(venueId);
}
```

**Repository impl — every call through `guard(tag, body)`:**

```dart
@LazySingleton(as: FavoritesRepository)
class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._remote);
  final FavoritesRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<FavoriteVenue>>> getFavorites() => guard(
        'favorites.getFavorites',
        () async => (await _remote.getFavorites()).map((d) => d.toEntity()).toList(),
      );

  @override
  Future<Either<Failure, Unit>> removeFavorite(String venueId) => guard('favorites.removeFavorite', () async {
        await _remote.removeFavorite(venueId);
        return unit;
      });
}
```

`guard` maps `AppException` → its failure, `DioException` → `appExceptionFromDio(...).toFailure()`, anything else → `UnknownFailure` (logged). Older codebases repeat a private `_guard` per repository with the same shape — fine to keep when matching local style.

## 5. Dependency injection

```dart
// core/config/env.dart (core, so features' data/ can import it)
abstract final class Env {
  static const String mock = 'mock';
  static const String api = 'api';
}

// app/di/injector.dart
final GetIt getIt = GetIt.instance;

@InjectableInit() // no redundant args — very_good_analysis flags them
Future<void> configureDependencies(String environment) async => getIt.init(environment: environment);
```

| Kind | Annotation |
|---|---|
| Repository, data source, client, service | `@LazySingleton(as: Interface)` |
| Use case | `@injectable` |
| Screen bloc/cubit | `@injectable` (new per page); per-screen args via `@factoryParam` |
| App-scoped bloc (auth, connectivity, onboarding) | `@lazySingleton` |
| Env-specific impl | add `@Environment(Env.api)` / `@Environment(Env.mock)` |
| Third-party (FlutterSecureStorage, Connectivity, Dio, AssetBundle) | `@module abstract class RegisterModule` (see `templates/lib/app/di/register_module.dart`) |
| Tunables (debounce durations) | `@Named('searchDebounce') Duration get searchDebounce => const Duration(milliseconds: 300);` |

`getIt` may be called only in: `bootstrap.dart`, pages (`BlocProvider.create`), router guards, and `app.dart`. Never inside blocs, use cases, repositories.

Services needing async init (Hive, sync) use `@preResolve` or are initialised explicitly in `bootstrap` after `configureDependencies` — build graph first, then start services.

## 6. Flavors and bootstrap

```dart
enum Flavor { dev, staging, prod }

class FlavorConfig {
  // apiBaseUrl, wsBaseUrl from --dart-define; diEnvironment: dev→Env.mock, staging/prod→Env.api;
  // logLevel; hasFirebase (false for dev → Firebase skipped, analytics/crash resolve to Noop impls)
}
```

`dev` must run on a fresh clone with **zero secrets** (mock data sources + no Firebase).

```dart
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  await runZonedGuarded(() async {
    FlavorConfig.init(flavor);
    if (FlavorConfig.I.hasFirebase) await Firebase.initializeApp();
    await configureDependencies(FlavorConfig.I.diEnvironment);
    await getIt<HiveService>().init();
    Bloc.observer = AppBlocObserver();          // logs onEvent/onChange/onError — features don't log transitions
    FlutterError.onError = (d) => LoggerService.I.error('FlutterError', d.exception, d.stack);
    getIt<SyncService>().start();               // flush offline outbox
    runApp(const App());
  }, (error, stack) => LoggerService.I.error('Uncaught zone error', error, stack));
}
```

Don't hard-code a flavor config in `main.dart` with a "TODO switch to prod" — each flavor has its own entrypoint.

## 7. Routing

- One `AppRouter.create()` → `GoRouter` with `StatefulShellRoute.indexedStack` for bottom tabs; `GoRoute(path:, name:, builder:)` elsewhere.
- Static paths before param paths (`/event/:id/products` before `/event/:id`).
- `GoRoute.name` == analytics screen slug; an `AnalyticsRouteObserver` logs `screen_view` automatically. Sheets/dialogs log manually.
- Guards are pure functions, unit-tested without widgets:

```dart
abstract final class AppGuards {
  static String? redirect(BuildContext context, GoRouterState state) => resolveRedirect(
        status: getIt<AuthBloc>().state.status,
        onboardingCompleted: getIt<OnboardingCubit>().state.completed,
        location: state.matchedLocation,
      );

  @visibleForTesting
  static String? resolveRedirect({required AuthStatus status, required bool onboardingCompleted, required String location}) { ... }
}
```

- `refreshListenable: GoRouterRefreshStream(Rx.merge([authBloc.stream, onboardingCubit.stream]))` — never trigger `router.refresh()` manually from a `BlocListener`.
- Route args: pass a typed `XArgs` object via `extra` or path params; the page forwards it to the bloc with `getIt<XBloc>(param1: args)`.

## 8. Cross-cutting services

- **LoggerService** (`LoggerService.I.debug/info/warning/error`) wraps `logger`, redacts sensitive keys (password, pin, otp, token, authorization, cvv, card numbers, email, phone, address). `print`/`debugPrint` are banned.
- **AnalyticsService** facade, typed `sealed class AnalyticsEvent`, flavor-branched Firebase/Noop impl, consent-gated (GDPR: off until opt-in, re-applied at launch). Never call `FirebaseAnalytics.instance` from features.
- **CrashReporter** injected through the constructor (not pulled from the service locator inside repository methods).
- **Design tokens:** until generated tokens exist, use a small `ThemeExtension` (`templates/lib/design_system/theme/app_theme.dart` → `AppSpacing` + `context.spacing`) and grow it (colors, radii, typography). Don't name hand-written files `app_tokens.dart` — that path is excluded from lint/coverage for generated tokens.
- **ConnectivityCubit** app-scoped; blocs that need it get a `ConnectivityService` stream via constructor and re-dispatch their load event on reconnect.
- **Secure session:** tokens only in `flutter_secure_storage`. Auth interceptor is a `QueuedInterceptor` (serialises concurrent 401s) that refreshes once, replays, or signs out.
