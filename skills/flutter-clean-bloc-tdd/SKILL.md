---
name: flutter-clean-bloc-tdd
description: Use when building, scaffolding, refactoring or reviewing a Flutter/Dart app or feature that uses (or should use) Clean Architecture, flutter_bloc (Bloc/Cubit), get_it/injectable, fpdart Either, go_router, dio/retrofit or TDD with bloc_test/mocktail - including new screens, repositories, use cases, API integrations, offline caching, BLE/IoT device apps and CI quality gates.
---

# Flutter: Clean Architecture + BLoC + TDD (house style)

## Overview

This is the house way to build Flutter apps, distilled from four production codebases. The reference layout is **notskip-app**. huboapp and codeapp contributed the caching and offline patterns; led_controller contributed device simulators and contract tests.

**Core principle:** UI is a pure function of state, business logic lives in blocs and use cases, every failure is a typed value, and no production line is written before a failing test.

**Existing project?** Its `CLAUDE.md`/`AGENTS.md` and the code around the change win. Match the local style, and use this skill for whatever they leave unspecified. Verify docs against the code, because docs often describe patterns the code never adopted.

**Worked example:** `examples/favorites/` is a complete feature that compiles, passes `flutter analyze --fatal-infos`, and has 88 passing tests. It shows a list, optimistic removal with rollback, a mock and an API data source, and a Page/View split. Read it before writing a similar feature.

## The stack (defaults for new code)

| Concern | Use | Not |
|---|---|---|
| State | `flutter_bloc` Bloc/Cubit, `equatable`, `bloc_concurrency` | provider, riverpod, setState for business state |
| Errors | `fpdart` `Either<Failure, T>` + sealed `Failure` | dartz, custom `Result`, throwing to UI |
| DI | `get_it` + `injectable` (codegen) | hand-written registration modules |
| Routing | `go_router` (`StatefulShellRoute` for tabs) | Navigator 1.0 push chains |
| HTTP | `dio` + `retrofit`; DTOs generated from OpenAPI (`swagger_parser`), or `json_serializable` when there is no spec | hand-parsed JSON |
| Local | `hive_ce`; `flutter_secure_storage` for tokens; `hydrated_bloc` for UI prefs only | tokens in prefs/hydrated |
| Tests | `mocktail`, `bloc_test`, `alchemist` goldens | mockito codegen |
| Lints | `very_good_analysis`, `flutter analyze --fatal-infos` | plain flutter_lints |
| l10n | official `gen-l10n` (ARB) | intl_utils, hard-coded strings |

Hand-written entities, states and events are `Equatable` classes, not `@freezed`. Freezed is only for generated DTOs.

## Golden rules

1. **TDD.** Red, then green, then refactor, for every unit including core types. Run each test file and watch it fail before writing the code it covers.
2. **Dependency rule:** `presentation → domain ← data`, and every layer may use `core/`. `domain/` is pure Dart (no Flutter, Dio or Hive). `presentation/` never imports `data/`.
3. **No silent failures.** Repositories wrap every call in `guard()` (`templates/lib/core/error/guard.dart`), which maps `AppException` and `DioException` to a typed `Failure`. Data sources stay thin and let errors propagate.
4. **Blocs depend on use cases**, injected through the constructor. They never touch repositories or `getIt`.
5. **One state class per bloc:** a `status` enum plus fields plus `copyWith`. Events are a `sealed` base with past-tense verb subclasses (`FavoritesRequested`, `FavoriteRemoved`).
6. **Tokens only.** No raw hex colors, pixel values or user-facing strings. Use theme extensions (`context.spacing`) and `context.l10n`.
7. **Log via `LoggerService`**, which redacts secrets and PII, and never `print`. Write `///` docs on public APIs.
8. **No secrets in source**, not even for dev flavors. Use `--dart-define` or CI secrets.
9. **Done means `make verify` is green:** gen, l10n, format, analyze, test, and at least 80% coverage. Goldens run only on CI, so a green local run proves nothing about goldens.

## Feature workflow

```
features/<feature>/
  domain/   entities/  repositories/ (abstract interface)  usecases/
  data/     models/ (DTOs, no spec)  datasources/ (<f>_client.dart + interface with @Environment api & mock impls)
            mappers/  repositories/ (*_impl, guard())
  presentation/  bloc/ (x_bloc, x_event, x_state)  pages/ (XPage + public XView)  widgets/
```

Work through these steps in order. For each one, write the test file first, run it red, then implement:

1. **Entity:** test equality and derived getters, then write the `Equatable` entity. Add `copyWith` only when something uses it.
2. **Repository contract:** in domain, an `abstract interface class` with methods returning `Future<Either<Failure, T>>`.
3. **Use case:** test against a mocked repository, then write an `@injectable` callable class with `Equatable` Params or `NoParams`.
4. **Data:**
   - Test the DTO and mapper against fixture JSON.
   - Test the repository: Right on success, and every exception type mapped to its failure.
   - Test the API data source with a fake `HttpClientAdapter`.
   - Test the mock data source. It is stateful: a removal stays removed.
5. **Bloc:** `blocTest` every event × outcome, the guards and the concurrency.
6. **View:** widget tests with a `MockBloc` for every status, interaction and one-shot effect. Page test: it resolves the bloc from `getIt` and dispatches the start event.
7. **Wire:** add the route (name = analytics slug) and the ARB keys with descriptions, then run `make verify` and report its real output.

To fix a bug, first write a test that reproduces it at the lowest layer where it shows up.

## Decisions

- **Bloc or Cubit?** Use a Cubit for load-one-thing, form and settings screens. Use a Bloc when there are discrete user events, streams, optimistic updates or transformers.
- **Concurrency:**
  - load, submit or retry → `droppable()`
  - search or filter → `restartable()` with an injected debounce
  - independent per-item actions → `concurrent()` with a per-id pending guard
  - ordered mutations on one resource → `sequential()`
- **Refreshing loaded data:** show the full-screen loader only when there is no data yet. When data is already on screen, keep `status: loaded`, set `isRefreshing`, and report a refresh failure as a one-shot effect.
- **Where the bloc lives:** for a screen, the `XPage` does `BlocProvider(create: (_) => getIt<XBloc>()..add(const XRequested()))` and renders a public `XView`. App-wide blocs (auth, connectivity) are lazy singletons provided above the router.
- **One-shot effects** (snackbar, navigation): a state field plus `BlocListener.listenWhen`. Give the field an identity (e.g. `FavoriteRemovalError(venueId, failure)`) so two equal failures still differ, and clear it when the next attempt starts.
- **Caching:** transactional data is remote-only. Browse lists use a fetch strategy (local-first with a TTL, remote-first on refresh). Offline mutations go through an outbox.

## Reference files (load only what the task needs)

| File | Load when |
|---|---|
| `examples/favorites/` | writing any feature: the complete, verified pattern |
| `references/architecture.md` | scaffolding a project or feature; core types, data layer, DI, flavors, bootstrap, routing |
| `references/presentation-bloc.md` | bloc or cubit, state and events, pages, optimistic updates, refresh, guards |
| `references/testing-tdd.md` | any test: helpers, bloc_test, widget, HTTP adapter, goldens, contract, coverage |
| `references/tooling-ci.md` | lints, Makefile, codegen, l10n, CI, secrets, releases, .gitignore |
| `references/offline-and-devices.md` | caching strategies, outbox, cross-feature events, BLE/Wi-Fi/MQTT devices |
| `templates/` | new project: copy `lib/`, `test/`, `analysis_options.yaml`, `l10n.yaml`, `Makefile`, and append `gitignore.append`; replace `app_name` |

## Red flags: stop and fix

| Thought | Reality |
|---|---|
| "Core `Failure`/`Result` types don't need tests" | Templates ship with tests; keep them. Don't invent a `Result` type; use `Either`. |
| "I'll add tests after the UI works" | Delete the untested code and restart from a failing test. |
| "Sealed state subclasses are cleaner" | One class with a status enum keeps data across transitions, which rollback and refresh need. |
| "A Dio interceptor maps errors to AppException" | It can't change the thrown type. `guard()` handles `DioException`. |
| "Just call the repository from the bloc" | Go through a use case; that's the seam you mock. |
| "`getIt` inside the bloc is quicker" | Constructor injection. `getIt` belongs only in pages, guards and bootstrap. |
| "Hard-code the string or color for now" | Add the ARB key or token now. "For now" ships. |
| "`catch (_) {}` is fine here" | Return a `Failure` via `guard()` or rethrow. |
| "The mock data source can be a no-op" | Then the dev flavor lies. Keep in-memory state. |
| "Tests pass locally, done" | Run `make verify`; goldens and coverage are enforced on CI. |
| "Project docs say freezed states" | Check the code. Code beats docs. |
