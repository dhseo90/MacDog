#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
EXPECTED_APP="$DIST_DIR/MacDog.app"

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

echo "Dist hygiene ok"
