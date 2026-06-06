#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() {
  echo "error: $*" >&2
  exit 1
}

require_contains() {
  local output="$1"
  local expected="$2"
  if [[ "$output" != *"$expected"* ]]; then
    die "missing expected version contract text: $expected"
  fi
}

require_failure_contains() {
  local expected="$1"
  shift

  local output
  local status
  set +e
  output="$(env -u MACDOG_APP_VERSION -u MACDOG_RELEASE_VERSION "$@" 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    die "command unexpectedly succeeded without an explicit version: $*"
  fi
  require_contains "$output" "$expected"
}

require_failure_contains \
  "app/release version required; set MACDOG_RELEASE_VERSION or MACDOG_APP_VERSION before running check.sh" \
  "$ROOT_DIR/script/check.sh" --no-run

require_failure_contains \
  "app version required; pass --version VERSION or set MACDOG_APP_VERSION/MACDOG_RELEASE_VERSION" \
  "$ROOT_DIR/script/build_and_run.sh" --no-run

require_failure_contains \
  "app version required; set MACDOG_APP_VERSION or MACDOG_RELEASE_VERSION" \
  "$ROOT_DIR/script/install.sh" --dry-run

require_failure_contains \
  "release version required; pass --version VERSION or set MACDOG_RELEASE_VERSION" \
  "$ROOT_DIR/script/package_release.sh" --dry-run

build_help_output="$("$ROOT_DIR/script/build_and_run.sh" --help)"
require_contains "$build_help_output" "MACDOG_APP_VERSION or MACDOG_RELEASE_VERSION is required unless --version is passed."

install_output="$(MACDOG_APP_VERSION=9.9.9 "$ROOT_DIR/script/install.sh" --dry-run)"
require_contains "$install_output" "App version: 9.9.9"

package_output="$(MACDOG_RELEASE_VERSION=9.9.9 "$ROOT_DIR/script/package_release.sh" --dry-run)"
require_contains "$package_output" "Version: 9.9.9"

if /usr/bin/grep -R -n -E 'default: "v?0\.1\.0"|default: "v?1\.[0-9]+\.[0-9]+"' "$ROOT_DIR/.github/workflows"; then
  die "release workflow must not provide a fallback release version or tag"
fi

echo "Explicit version contract verification ok"
