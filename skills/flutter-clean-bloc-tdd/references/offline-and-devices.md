# Offline, cross-feature sync & device apps

## Contents
1. Fetch strategies (cache-aside repository)
2. Offline mutation outbox
3. Network-aware blocs
4. Cross-feature updates
5. BLE / Wi-Fi / MQTT device apps
6. Device simulator & contract spec

---

## 1. Fetch strategies

For browse-type data (lists, catalogs, reference data) — not for transactional flows (checkout, payments), which stay remote-only.

```dart
// core/cache/fetch_strategy.dart
enum FetchStrategy { localFirst, localFirstWithTtl, remoteFirst, localOnly, remoteOnly }
```

- The **bloc/use-case caller chooses** per call: `localFirstWithTtl` on open, `remoteFirst` on pull-to-refresh, `localOnly` when offline.
- Pass it as part of the use case Params (`GetVenuesParams(filter, strategy: FetchStrategy.remoteFirst)`); domain stays unaware of Hive.
- Implement the orchestration once (`CachedResource<T>` helper or a repository mixin) with injectable local read/write and remote fetch closures + a `CacheValidator` storing `tag:key → timestamp` for TTL. Every feature repository composes it instead of re-implementing branching.
- Local persistence models live in `data/models/` (Hive `TypeAdapter`s or JSON maps in a named box) — domain entities carry no `@HiveType`. Type IDs allocated centrally in `core/cache/hive_type_ids.dart`; box names in `box_names.dart`; version box names on schema change (`hubs_v2`).
- Register adapters centrally (generated `hive_registrar.g.dart`) at bootstrap, not ad hoc inside data sources.
- Malformed remote payloads (`TypeError`/`FormatException` in mapping) are reported to crash reporting as non-fatal and returned as `ServerFailure` — keep serving cached data.

Test matrix per strategy: cache hit / miss / expired / remote failure with cache (returns cache) / remote failure without cache (returns Failure) / write-back after remote.

## 2. Offline mutation outbox

- `OutboxStore` (Hive `outbox` box, JSON records `{id, op, payload, createdAt, attempts, authContext}`), FIFO.
- Repository: on `NetworkFailure` for an idempotent mutation, enqueue and return `Right` with a pending marker (UI shows optimistic state + "will sync").
- `SyncService.start()` at bootstrap: flush on launch and on connectivity regained; delete on success, `incrementAttempts` with backoff on failure, drop + log after N attempts or on auth-context change.
- Inject `id`/`now` for deterministic tests.

## 3. Network-aware blocs

```dart
FavoritesBloc(this._getFavorites, this._connectivity) : super(const FavoritesState()) {
  on<FavoritesRequested>(_onRequested, transformer: droppable());
  on<_ConnectivityRestored>((_, __) => add(const FavoritesRequested()));
  _sub = _connectivity.onStatusChange.where((online) => online).skip(1).listen((_) => add(const _ConnectivityRestored()));
}

@override
Future<void> close() async { await _sub.cancel(); return super.close(); }
```

Use private event classes for internal triggers. Show an app-level offline banner from the app-scoped `ConnectivityCubit`, not per screen.

## 4. Cross-feature updates

A favorite toggled on a detail page must update the list and carousel elsewhere. In order of preference:

1. **Repository stream** — repository exposes `Stream<List<T>> watch...()`; affected blocs subscribe via a `StreamUseCase` + `emit.forEach`. Single source of truth.
2. **Domain event bus** — `AppEventBus` (`emit(event)` / `on<T>()` over a broadcast `StreamController`), typed `sealed class DomainEvent` (`FavoriteChanged(venueId, isFavorite)`). Inject it; subscribers cancel in `close()`. Use when there's no shared repository.
3. Never: blocs holding references to other blocs, or `getIt<OtherBloc>()` inside a bloc.

## 5. BLE / Wi-Fi / MQTT device apps

Layering for firmware-controlled devices (LED controllers, sensors, IoT hubs):

```
features/device/
  domain/  entities/ (DeviceStatus, DeviceFile...)  repositories/device_repository.dart
           usecases/ (ConnectDevice, SendCommand, UploadFile, WatchStatus)
  data/
    transport/  device_transport.dart            # abstract: connect(), disconnect(), send(String), Stream<String> lines, Stream<TransportState>
                ble_transport.dart · websocket_transport.dart · mqtt_transport.dart
    protocol/   device_protocol_codec.dart        # PURE: encode(Command) → String, decode(String) → DeviceMessage (sealed)
    repositories/device_repository_impl.dart     # picks transport, correlates request/response, maps to Failures
  presentation/ bloc/device_connection_bloc.dart  # state machine; PIN dialog shown by the View on AuthRequired status
```

Rules:
- **One codec, N transports** behind an interface — no `if (mode == ble)` branches repeated across methods.
- **Codec is public and pure** — unit-test every message type; never parse inside private service methods.
- **Connection state machine** as an enum in bloc state: `disconnected → scanning → connecting → authenticating → ready`, plus `rebooting` (commands known to reboot the device expect disconnect + auto-reconnect).
- **Request/response over notifications:** send, then `lines.map(codec.decode).where(matches).first.timeout(...)` → `Left(DeviceTimeoutFailure)` on timeout. No bare `Future.delayed` "settle" waits — wait for an observable readiness signal (services discovered, MTU negotiated, `READY` message).
- BLE specifics: subscribe to scan results **before** `startScan`; explicit scan timeout; connect timeout; request MTU and handle refusal as a logged, non-fatal fallback.
- Chunked uploads: configurable chunk size + pacing or ACK-based backpressure; progress as `Stream<double>`; resumable where firmware supports it.
- **Auth/pairing:** the data layer never shows UI. Repository emits `AuthRequired`; the View shows the PIN dialog and dispatches `DevicePinSubmitted`. Stored credentials (secure storage) enable a fast path — also the seam automation/screenshot tests use.
- Broker/device credentials never compiled into the app.

## 6. Device simulator & contract spec

- `tools/device-stub/` — small Node/Dart server speaking the exact device protocol over WebSocket, seeded by JSON scenarios (`empty`, `full`, `mid-playback`, `auth-fail`). Has its own test suite and CI job.
- `protocol-spec.json` — **single source of truth** of named request/response samples, consumed by the simulator's conformance tests **and** a Dart contract test that runs every sample through the real `DeviceProtocolCodec`. Protocol drift fails CI on both sides.
- The Wi-Fi/WebSocket transport doubles as the test transport: smoke tests boot the stub and run real traffic inside `tester.runAsync`; integration/screenshot tests use scenarios for deterministic store screenshots.
