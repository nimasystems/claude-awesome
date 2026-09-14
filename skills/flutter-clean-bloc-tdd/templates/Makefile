.PHONY: help run-dev run-staging gen gen-api format analyze test coverage l10n test-e2e verify

ifeq ($(OS),Windows_NT)
  SHELL := bash.exe
else
  SHELL := /bin/bash
endif
.SHELLFLAGS := -eu -o pipefail -c

COVERAGE_MIN ?= 80

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

run-dev: ## Run dev flavor (mock data, no secrets)
	flutter run --flavor dev -t lib/main_dev.dart

run-staging: ## Run staging flavor (staging API)
	flutter run --flavor staging -t lib/main_staging.dart

gen-api: ## OpenAPI -> retrofit clients + DTOs (skipped if no swagger_parser.yaml)
	@if [ -f swagger_parser.yaml ]; then dart run swagger_parser; else echo "no swagger_parser.yaml, skipping"; fi

gen: ## build_runner (injectable/freezed/json/retrofit/hive)
	dart run build_runner build --delete-conflicting-outputs

l10n: ## gen-l10n from ARB files
	flutter gen-l10n

format: ## Format sources
	dart format lib/ test/

analyze: ## Static analysis, infos are fatal
	flutter analyze --fatal-infos

test: ## Tests with coverage
	flutter test --coverage

coverage: ## Enforce >= COVERAGE_MIN% line coverage excluding generated code
	dart pub global activate remove_from_coverage >/dev/null
	dart pub global run remove_from_coverage -f coverage/lcov.info \
	  -r '\.g\.dart$$' -r '\.freezed\.dart$$' -r '\.config\.dart$$' \
	  -r '\.gr\.dart$$' -r '\.mocks\.dart$$' -r 'l10n/gen/' \
	  -r 'core/network/api/' -r 'app_tokens\.dart$$' -r 'main_.*\.dart$$'
	@PCT=$$(awk -F: '/^LF:/{f+=$$2} /^LH:/{h+=$$2} END{if(f==0)print 0; else printf "%.1f",(h/f)*100}' coverage/lcov.info); \
	  echo "Line coverage: $$PCT%"; \
	  awk -v p="$$PCT" -v m="$(COVERAGE_MIN)" 'BEGIN{exit (p+0 < m+0)}' || { echo "Coverage below $(COVERAGE_MIN)%"; exit 1; }

test-e2e: ## Integration tests (dev flavor, mock data) on a running simulator
	flutter test integration_test --flavor dev

verify: gen-api gen l10n format analyze test coverage ## Definition of Done gate
	@echo "verify passed"
