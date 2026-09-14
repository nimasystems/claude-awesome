# Tooling, CI & release reference

## Contents
1. analysis_options.yaml
2. Makefile (the verify gate)
3. Codegen chain
4. l10n
5. Design tokens
6. CI pipeline
7. Secrets & env staging
8. Releases, changelog, commits

---

## 1. analysis_options.yaml

Copy `templates/analysis_options.yaml`. Key points:

- `include: package:very_good_analysis/analysis_options.yaml`, run with `flutter analyze --fatal-infos`.
- Exclude generated code: `**/*.g.dart`, `**/*.freezed.dart`, `**/*.config.dart`, `**/*.gr.dart`, `**/*.mocks.dart`, `lib/core/network/api/**`, generated tokens.
- `errors: todo: ignore`.
- Deliberate relaxations (keep them — they match the architecture):
  - `public_member_api_docs: false` — docs by convention, not lint.
  - `lines_longer_than_80_chars: false` — `dart format` handles code.
  - `one_member_abstracts: false` — single-method interfaces are DI/mock seams.
  - `avoid_catches_without_on_clauses: false` — the `guard()` catch-all.
- Never downgrade `avoid_print`; use `LoggerService`.
- Common `--fatal-infos` traps: redundant default args (`@InjectableInit(preferRelativeImports: false)`, `String.fromEnvironment('X', defaultValue: '')`); `sort_pub_dependencies` after `flutter pub add` (it appends — re-sort `pubspec.yaml`); `prefer_const_constructors` in tests (`dart fix --apply`).
- Local packages (`packages/<name>`) have their own `analysis_options.yaml` including the same base.

## 2. Makefile

Copy `templates/Makefile`. Recipes run under bash with `-eu -o pipefail`. Targets:

| Target | Command |
|---|---|
| `run-dev` / `run-staging` | `flutter run --flavor <x> -t lib/main_<x>.dart` |
| `gen` | `dart run build_runner build --delete-conflicting-outputs` |
| `gen-api` | `dart run swagger_parser` (then `gen`) |
| `format` | `dart format lib/ test/` (add `tool/` if it exists) |
| `analyze` | `flutter analyze --fatal-infos` |
| `test` | `flutter test --coverage` |
| `coverage` | strip generated files + enforce ≥80% |
| `l10n` | `flutter gen-l10n` |
| `test-e2e` | integration tests on simulator |
| **`verify`** | `gen-api gen l10n format analyze test coverage` — Definition of Done |
| `release-patch/minor/major`, `release-prod` | tag-driven CD |
| `push-envs` | validate `envs/local` and push GitHub secrets |

`help` target self-documents via `## comments`. Wrap only what people run; don't hide one-off flags.

## 3. Codegen chain (order matters)

1. Edit the contract `docs/api/openapi.yaml` (never the generated clients).
2. `make gen-api` → `swagger_parser` writes retrofit clients (split by tag, `client_postfix: Client`, root client) and freezed DTOs into `lib/core/network/api/` (`json_serializer: freezed`, `use_freezed3: true`, `enums_to_json: true`, `unknown_enum_value: true` for forward-compatible enums).
3. `make gen` → build_runner emits `*.g.dart`/`*.freezed.dart`, `injector.config.dart`, Hive adapters.
4. Update mappers, mock data sources, fixtures, tests.

Generated files are **gitignored** (append `templates/gitignore.append` to `.gitignore`) and regenerated in CI — keeps diffs clean and proves generation works. Consequence: run `make gen l10n` right after cloning, before analyze/test. If a project commits generated files instead, follow the project.

`build.yaml` can scope builders to folders to speed up build_runner on large apps.

## 4. l10n

`l10n.yaml`:
```yaml
arb-dir: lib/l10n/arb
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/l10n/gen
nullable-getter: false
```
- `context.l10n` extension in `core/extensions/context_x.dart`.
- One toolchain only (not `intl_utils`/`flutter_intl` alongside gen-l10n).
- Placeholders + plurals via ICU; every key has `@key.description`.
- Tests pump with `AppLocalizations.localizationsDelegates` (in `pumpApp`).

## 5. Design tokens

- Tokens are generated upstream (design repo → `docs/design-system/build/flutter/app_tokens.dart`) and copied in by `make sync-tokens`; excluded from lint.
- `AppTheme.light/dark` builds `ThemeData` + `ThemeExtension<AppTokens>`; widgets read `context.tokens`.
- Responsive sizing via layout constraints/`MediaQuery`; avoid sprinkling `flutter_screenutil` `.w/.sp` in every widget.

## 6. CI (GitHub Actions)

`quality` job, Flutter pinned (`subosito/flutter-action@v2`, exact version matching local + golden baselines):

```
flutter pub get
make gen-api && dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed lib/ test/
flutter analyze --fatal-infos
CI=true flutter test --coverage
coverage gate (≥80%, generated files removed):
  dart pub global activate remove_from_coverage
  dart pub global run remove_from_coverage -f coverage/lcov.info \
    -r '\.g\.dart$' -r '\.freezed\.dart$' -r '\.config\.dart$' -r '\.gr\.dart$' -r '\.mocks\.dart$' \
    -r 'l10n/gen/' -r 'app_tokens\.dart$'
  awk over LF/LH → fail below 80
upload coverage artifact (if: always())
```

- Extra jobs for side projects that ship with the app: device simulator (`npm ci && npm test`), pipeline scripts (shell/Ruby/Python tests — tooling is tested too).
- Runner choice is measured: self-hosted was ~2.6× faster for a large suite; sharding was rejected because fixed per-run cost dominated. Measure before optimising.
- `concurrency:` group per branch with `cancel-in-progress: true`.

## 7. Secrets & env staging

- Never in source: no API keys, service-account JSON, MQTT/DB credentials in Dart files (even dev flavors). Runtime config via `--dart-define`/`--dart-define-from-file` (gitignored file), build secrets via CI.
- `envs/` convention:
  - `envs/template/` (tracked) with `__REPLACE_ME__` placeholders;
  - `envs/local/` (gitignored) filled by the developer;
  - `envs/push-envs.sh` (via `make push-envs [DRY_RUN=1] [SCOPE=repo|production|all]`) validates shapes (URL, base64, PEM, JSON; opens the keystore with `keytool`) and **rejects any placeholder token** before calling `gh secret set`.
- CI decodes secrets to files in a step and deletes them in an `if: always()` cleanup step.
- Mobile signing: iOS `fastlane match` (readonly in CI); Android base64 keystore secret.

## 8. Releases, changelog, commits

- **Conventional Commits** (`feat:`, `fix:`, `refactor:`, `test:`, `chore:`, `ci:`...). `git-cliff` (`cliff.toml`) renders tester-facing notes, filtering `chore/ci/build/style`.
- Version name from the git tag (`vX.Y.Z`), build number from `github.run_number`; `pubspec.yaml` version isn't bumped by CI (`--build-name`/`--build-number`).
- `make release-patch|minor|major` → `scripts/release.sh` (semver bump from latest tag, confirm unless `FORCE=1`, push tag) → CD builds Android/iOS in parallel → Firebase App Distribution + GitHub Release. `make release-prod VERSION=` promotes an existing tag to TestFlight/Play.
- Single root `fastlane/` with `platform :ios` and `platform :android` lanes, `bundle exec fastlane --env staging|production`; exact versions pinned in `Gemfile.lock`.
