# Example: favorites feature (verified)

A complete feature built by following this skill. It was verified on Flutter 3.44 / Dart 3.12 together with `templates/`: build_runner, gen-l10n, `dart format` and `flutter analyze --fatal-infos` were clean, all 88 tests passed, and line coverage was 93.3%.

**What it shows:**
- A list with loading, empty, error-with-retry and loaded states.
- Optimistic removal with rollback, using `concurrent()` plus a pending guard for each id.
- A one-shot snackbar with identity (`FavoriteRemovalError`).
- A hand-written retrofit client and `json_serializable` DTO for an endpoint with no OpenAPI spec.
- Stateful mock and API data sources selected by `@Environment`.
- A repository that wraps every call in `guard()`.
- A Page/View split with the bloc provided from `getIt`.

Test techniques:
- A fake `HttpClientAdapter` for API tests, with errors run end-to-end through the repository.
- `Completer`-ordered concurrency tests.
- `MockBloc` view tests.
- A page test that checks the bloc is resolved from `getIt`.

## Drop-in

1. Copy `templates/` into the app, then copy `lib/`, `test/` and `assets/fixtures/favorites.json` from here, and replace `app_name` with your package name.
2. Merge `app_en.favorites.arb.json` into `lib/l10n/arb/app_en.arb`.
3. Register `assets/fixtures/` under `flutter: assets:` and set `flutter: generate: true`.
4. Add the dependencies below (keep `pubspec.yaml` sorted), then run `make gen l10n analyze test`.

```yaml
dependencies:
  bloc_concurrency: ^0.3.0
  dio: ^5.11.1
  equatable: ^2.1.0
  flutter_bloc: ^9.1.1
  flutter_localizations: { sdk: flutter }
  fpdart: ^1.2.0
  get_it: ^9.2.1
  go_router: ^18.0.1
  injectable: ^3.0.0
  intl: ^0.20.2
  json_annotation: ^4.12.0
  logger: ^2.8.0
  retrofit: ^4.10.0
dev_dependencies:
  bloc_test: ^10.0.0
  build_runner: ^2.15.1
  injectable_generator: ^3.1.3
  json_serializable: ^6.14.1
  mocktail: ^1.0.5
  retrofit_generator: ^10.2.9
  very_good_analysis: ^10.3.0
```

The DI smoke test (`test/app/di/injector_test.dart` in a real app) depends on every registered feature, so it isn't included here. Add one that resolves the graph for both `Env.mock` and `Env.api`.
