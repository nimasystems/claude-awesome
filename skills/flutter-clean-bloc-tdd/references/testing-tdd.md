# Testing & TDD reference

## Contents
1. The loop
2. Test layout
3. Mocks, fakes, fallbacks
4. Domain & use case tests
5. Data tests (mapper, repository `guard()`, API data source over a fake adapter)
6. Bloc tests
7. Widget tests
8. Goldens
9. Contract tests & simulators
10. Integration tests
11. Coverage & verify

---

## 1. The loop

For each unit, in the feature order (entity → contract → use case → mapper → repository → bloc → view):

1. Write the failing test(s) for ONE unit. Run it: `flutter test path/to/x_test.dart`. **See it fail for the right reason** — a compile error is acceptable only for a brand-new unit; for a change to existing code it must be an assertion failure.
2. Write the minimum code to pass. Run again.
3. Refactor with tests green. Next unit.

**Granularity:** ideal is one test → one change. Acceptable under time pressure: write the full test file for one class, run it red, implement the class. Not acceptable: implementing a whole layer (or feature) and back-filling tests. Mutation check for tricky logic: temporarily break it (swap `droppable()` for `concurrent()`, remove a guard) and confirm a test fails.

Core/shared types (`Failure`, `AppException.toFailure`, `guard`, value objects) get tests first too. Generated code (retrofit clients, DTOs, `injector.config.dart`) is not unit-tested — test mappers and the code that uses them.

Bug fix: reproduce with a failing test at the lowest layer that exhibits it, then fix.

## 2. Layout

Mirror `lib/` at **layer** granularity — one file per layer per feature is fine; split when a file passes ~300 lines.

```
test/
  flutter_test_config.dart          # alchemist config, goldens CI-only
  helpers/  pump_app.dart · hive_helper.dart · flow_harness.dart
  helpers/fixtures.dart              # fixture('x.json') reads assets/fixtures/ — the SAME files the mock data sources load
  core/error/failures_test.dart · exceptions_test.dart
  features/favorites/
    domain/favorites_usecases_test.dart
    data/favorites_data_test.dart            # mapper + repository impl
    presentation/favorites_bloc_test.dart
    presentation/favorites_view_test.dart
  design_system/goldens/
integration_test/app_flow_test.dart   # runs against Env.mock
```

## 3. Mocks, fakes, fallbacks

- `mocktail` only (no codegen). `class _MockFavoritesRepository extends Mock implements FavoritesRepository {}`.
- `MockBloc<E, S>` / `MockCubit<S>` from bloc_test for widget tests.
- Prefer a hand-written **fake** when the collaborator is stateful (a transport, a store, a stream source): real behaviour, controllable inputs, recorded outputs (`sentCommands`, `emit(...)`).
- `setUpAll(() { registerFallbackValue(const RemoveFavoriteParams('x')); registerFallbackValue(const NoParams()); });` for every type used with `any()`.
- Entities for tests: small top-level builders (`FavoriteVenue _venue({String id = 'v1'}) => ...`) in the test file or `helpers/fixtures.dart`.
- Tests needing `getIt`: register in `setUp`, `tearDown(GetIt.instance.reset)`.

## 4. Domain & use case

```dart
void main() {
  late _MockFavoritesRepository repository;
  late RemoveFavorite removeFavorite;

  setUp(() {
    repository = _MockFavoritesRepository();
    removeFavorite = RemoveFavorite(repository);
  });

  test('delegates to repository and returns its result', () async {
    when(() => repository.removeFavorite('v1')).thenAnswer((_) async => const Right(unit));

    final result = await removeFavorite(const RemoveFavoriteParams('v1'));

    expect(result, const Right<Failure, Unit>(unit));
    verify(() => repository.removeFavorite('v1')).called(1);
  });
}
```

Entities: test `props` equality and every derived getter. Failures/exceptions: test each `statusCode → Failure` mapping.

## 5. Data

```dart
group('FavoritesRepositoryImpl', () {
  late _MockRemote remote;
  late FavoritesRepositoryImpl repository;
  setUp(() { remote = _MockRemote(); repository = FavoritesRepositoryImpl(remote); });

  test('maps DTOs to entities on success', () async {
    when(remote.getFavorites).thenAnswer((_) async => [_dto]);
    final result = await repository.getFavorites();
    expect(result.getOrElse((_) => []), [_entity]);
  });

  test('ApiException 401 → AuthFailure', () async {
    when(remote.getFavorites).thenThrow(const ApiException('unauthorized', statusCode: 401));
    expect(await repository.getFavorites(), isA<Left<Failure, List<FavoriteVenue>>>()
        .having((l) => l.value, 'failure', isA<AuthFailure>()));
  });

  test('unexpected error → UnknownFailure (never throws)', () async {
    when(remote.getFavorites).thenThrow(StateError('boom'));
    final result = await repository.getFavorites();
    expect(result.getLeft().toNullable(), isA<UnknownFailure>());
  });
});
```

Mapper tests: build DTO from the fixture JSON (`fixtureList('favorites.json')`), assert the entity — this also catches DTO/fixture drift. Tests of `FixtureLoader`/mock data sources using `rootBundle` need `TestWidgetsFlutterBinding.ensureInitialized()` and the fixture listed under `flutter: assets:`.

**API data source + client (retrofit, generated or hand-written):** don't mock Dio. Give a real `Dio` a fake `HttpClientAdapter` that records requests and returns canned `ResponseBody`s; assert method/path/body, and run errors end-to-end through the repository so `guard()` mapping is covered:

```dart
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions o) handler;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) {
    requests.add(o);
    return handler(o);
  }
  @override
  void close({bool force = false}) {}
}

test('404 surfaces through the repository as NotFoundFailure', () async {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
    ..httpClientAdapter = _FakeAdapter((_) async => ResponseBody.fromString('{}', 404,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]}));
  final result = await FavoritesRepositoryImpl(FavoritesApiDataSource(dio)).removeFavorite('v1');
  expect(result.getLeft().toNullable(), isA<NotFoundFailure>());
});
```

Full version: `examples/favorites/test/features/favorites/data/favorites_data_test.dart`. Hive tests use a temp directory helper (`hive_helper.dart`) and close/delete boxes in `tearDown`.

## 6. Bloc

```dart
blocTest<FavoritesBloc, FavoritesState>(
  'FavoriteRemoved rolls back and exposes removalError when removal fails',
  setUp: () => when(() => removeFavorite(any())).thenAnswer((_) async => const Left(NetworkFailure('offline'))),
  build: build,
  seed: () => FavoritesState(status: FavoritesStatus.loaded, favorites: [_v1, _v2]),
  act: (bloc) => bloc.add(const FavoriteRemoved('v1')),
  expect: () => [
    isA<FavoritesState>().having((s) => s.visible, 'visible', [_v2]),
    isA<FavoritesState>()
        .having((s) => s.visible, 'visible', [_v1, _v2])
        .having((s) => s.removalError?.failure, 'removalError.failure', isA<NetworkFailure>()),
  ],
  verify: (_) => verify(() => removeFavorite(const RemoveFavoriteParams('v1'))).called(1),
);
```

Cover per event: success, each meaningful failure, guards (ignored when not loaded / already pending), concurrency (use `Completer`s to control completion order; `droppable` drops the second tap; two identical concurrent failures still produce distinct one-shot states), and stream cancellation on `close()`. Use `seed:` instead of replaying setup events. Use `.having(...)` matchers when only some fields matter.

## 7. Widget tests

```dart
class _MockFavoritesBloc extends MockBloc<FavoritesEvent, FavoritesState> implements FavoritesBloc {}

Future<void> pumpView(WidgetTester tester, FavoritesBloc bloc) => tester.pumpApp(
      BlocProvider<FavoritesBloc>.value(value: bloc, child: const FavoritesView()),
      wrapInScaffold: false, // the View brings its own Scaffold
    );

testWidgets('tapping retry dispatches FavoritesRequested', (tester) async {
  when(() => bloc.state).thenReturn(const FavoritesState(status: FavoritesStatus.failure, failure: NetworkFailure('x')));
  await pumpView(tester, bloc);
  await tester.tap(find.byKey(AppErrorView.retryKey));
  verify(() => bloc.add(const FavoritesRequested())).called(1);
});

testWidgets('shows snackbar on removalError', (tester) async {
  whenListen(bloc, Stream.value(_loaded.copyWith(removalError: () => const FavoriteRemovalError('v1', NetworkFailure('x')))), initialState: _loaded);
  await pumpView(tester, bloc);
  await tester.pump();
  expect(find.byType(SnackBar), findsOneWidget);
});
```

- `pumpApp` (templates/test/helpers/pump_app.dart) wraps theme + localizations; find text via real l10n strings or keys.
- Test the Page separately only to prove it resolves the bloc from `getIt` and dispatches the start event (`getIt.registerFactory<FavoritesBloc>(() => mock)`).
- One widget test per visual state + each interaction → event.
- **Dates/time zones:** compute the expected text with the same formatter the widget uses (`DateFormat.yMMMd('en').format(date.toLocal())`) instead of hard-coding it; spot-check with `TZ=Pacific/Kiritimati flutter test path` and `TZ=America/Los_Angeles`.
- **Network images:** flutter_test answers every HTTP request with 400, so images fail; widgets must have an error fallback (then tests pass without extra setup). For image-specific assertions use `mocktail_image_network`.

## 8. Goldens

`alchemist`, config in `test/flutter_test_config.dart`: platform goldens off, CI goldens only when `CI=true`. Local `make test` skips them — **a green local run does not validate goldens**. Update on the pinned CI toolchain: `CI=true flutter test --update-goldens test/design_system/`. Golden-test design-system widgets and key screens in light/dark and one long-text locale.

## 9. Contract tests & simulators (APIs, devices)

- When a wire protocol/spec is shared with another system (OpenAPI, BLE text protocol, MQTT topics), keep **one spec file** in the repo and write a contract test that feeds every sample through the real parser/mapper.
- Parsers are public pure functions/classes (`DeviceProtocolCodec.decode(String)`) — never private methods that tests must copy. Use `@visibleForTesting` only for narrow seams.
- For hardware apps, a scenario-seeded simulator (e.g. Node WebSocket stub speaking the device protocol) enables smoke tests in CI, local dev without hardware, and deterministic store screenshots. See offline-and-devices.md.

## 10. Integration tests

`integration_test/` runs the real app on `Flavor.dev` (`Env.mock`) — no network, deterministic fixtures. Cover critical journeys (sign-in → main flow → success). Run via `make test-e2e` on a simulator; screenshots via `integration_test` + driver when needed.

## 11. Coverage & verify

- Gate: ≥80% line coverage after stripping generated files (`*.g.dart`, `*.freezed.dart`, `*.config.dart`, `core/network/api/**`, `main_*.dart`, `bootstrap.dart`) — `remove_from_coverage` + `lcov`.
- `make verify` = gen-api + gen + format + analyze (`--fatal-infos`) + test. Run before every commit/PR and before claiming done; report the actual output.
