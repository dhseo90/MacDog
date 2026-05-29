#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$ROOT_DIR/README.md"
GENERATED_DOCS_DIR="$ROOT_DIR/Assets/Generated/Docs"

die() {
  echo "error: $*" >&2
  exit 1
}

[[ -f "$README" ]] || die "README missing: $README"

if /usr/bin/grep -Fq "Assets/Generated/Docs" "$README"; then
  die "README still references generated screenshot artifacts"
fi

if [[ -d "$GENERATED_DOCS_DIR" ]]; then
  generated_images="$(
    find "$GENERATED_DOCS_DIR" -type f \( \
      -iname '*.png' -o \
      -iname '*.jpg' -o \
      -iname '*.jpeg' -o \
      -iname '*.gif' -o \
      -iname '*.webp' -o \
      -iname '*.svg' -o \
      -iname '*.icns' -o \
      -iname '*.ico' \
    \) -print
  )"

  if [[ -n "$generated_images" ]]; then
    echo "$generated_images" >&2
    die "generated README image artifacts must be deleted after review"
  fi
fi

echo "README generated image hygiene ok"
