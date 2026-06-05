#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
EXPECTED_APP="$DIST_DIR/MacDog.app"
EXPECTED_VERSION="${MACDOG_RELEASE_VERSION:-${MACDOG_APP_VERSION:-}}"

if [[ ! -d "$DIST_DIR" ]]; then
  echo "Dist hygiene ok: dist directory does not exist yet"
  exit 0
fi

stale_apps=()
while IFS= read -r app_bundle; do
  stale_apps+=("$app_bundle")
done < <(/usr/bin/find "$DIST_DIR" -maxdepth 1 -type d -name "*.app" ! -path "$EXPECTED_APP" -print | /usr/bin/sort)

if (( ${#stale_apps[@]} > 0 )); then
  echo "error: stale app bundles found in dist; keep only dist/MacDog.app" >&2
  for app_bundle in "${stale_apps[@]}"; do
    echo "  - ${app_bundle#$ROOT_DIR/}" >&2
  done
  exit 1
fi

release_dir="$DIST_DIR/release"
if [[ -d "$release_dir" ]]; then
  stale_release_payloads=()
  while IFS= read -r payload_dir; do
    stale_release_payloads+=("$payload_dir")
  done < <(/usr/bin/find "$release_dir" -maxdepth 1 -type d -name "MacDog-*" -print | /usr/bin/sort)

  if (( ${#stale_release_payloads[@]} > 0 )); then
    echo "error: stale release staging payloads found in dist/release; keep only .dmg and .sha256 artifacts" >&2
    for payload_dir in "${stale_release_payloads[@]}"; do
      echo "  - ${payload_dir#$ROOT_DIR/}" >&2
    done
    exit 1
  fi

  release_files=()
  while IFS= read -r file; do
    release_files+=("$file")
  done < <(/usr/bin/find "$release_dir" -maxdepth 1 -type f -name "MacDog-*" -print | /usr/bin/sort)

  if (( ${#release_files[@]} > 0 )); then
    [[ -n "$EXPECTED_VERSION" ]] || {
      echo "error: release artifacts found in dist/release but no current version is set" >&2
      echo "set MACDOG_RELEASE_VERSION or MACDOG_APP_VERSION before checking dist release hygiene" >&2
      exit 1
    }

    unexpected_release_files=()
    for file in "${release_files[@]}"; do
      case "$(basename "$file")" in
        "MacDog-$EXPECTED_VERSION.dmg"|"MacDog-$EXPECTED_VERSION.dmg.sha256"|"MacDog-$EXPECTED_VERSION-release-notes.md")
          ;;
        *)
          unexpected_release_files+=("$file")
          ;;
      esac
    done

    if (( ${#unexpected_release_files[@]} > 0 )); then
      echo "error: non-current release artifacts found in dist/release" >&2
      echo "current version: $EXPECTED_VERSION" >&2
      for file in "${unexpected_release_files[@]}"; do
        echo "  - ${file#$ROOT_DIR/}" >&2
      done
      exit 1
    fi
  fi
fi

echo "Dist hygiene ok"
