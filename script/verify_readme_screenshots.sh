#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$ROOT_DIR/README.md"
GENERATED_DOCS_DIR="$ROOT_DIR/Assets/Generated/Docs"
README_IMAGE_DIR="$ROOT_DIR/Docs/Images/README"
XCRUN="/usr/bin/xcrun"

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

required_images=(
  "Docs/Images/README/PopoverTabs/macdog-popover-codex.png"
  "Docs/Images/README/PopoverTabs/macdog-popover-mac.png"
  "Docs/Images/README/PopoverTabs/macdog-popover-sleep.png"
  "Docs/Images/README/PopoverTabs/macdog-popover-battery.png"
  "Docs/Images/README/PopoverTabs/macdog-popover-settings.png"
  "Docs/Images/README/macdog-desktop-pet-front.png"
)

for image in "${required_images[@]}"; do
  [[ -f "$ROOT_DIR/$image" ]] || die "README image missing: $image"
  /usr/bin/grep -Fq "$image" "$README" || die "README does not reference required image: $image"
done

if [[ -d "$README_IMAGE_DIR" ]]; then
  extra_images="$(
    find "$README_IMAGE_DIR" -type f \( \
      -iname '*.png' -o \
      -iname '*.jpg' -o \
      -iname '*.jpeg' -o \
      -iname '*.gif' -o \
      -iname '*.webp' -o \
      -iname '*.svg' -o \
      -iname '*.icns' -o \
      -iname '*.ico' \
    \) -print | while IFS= read -r file; do
      relative="${file#$ROOT_DIR/}"
      is_required=0
      for required_image in "${required_images[@]}"; do
        if [[ "$relative" == "$required_image" ]]; then
          is_required=1
          break
        fi
      done
      if [[ "$is_required" == "0" ]]; then
        printf '%s\n' "$relative"
      fi
    done
  )"

  if [[ -n "$extra_images" ]]; then
    echo "$extra_images" >&2
    die "README image directory contains unreferenced image artifacts"
  fi
fi

[[ -x "$XCRUN" ]] || die "xcrun not found at $XCRUN"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

render_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-readme-screenshots.XXXXXX")"
trap 'rm -rf "$render_dir"' EXIT

MACDOG_RENDER_README_SCREENSHOTS=1 \
MACDOG_RENDER_README_SCREENSHOTS_OUTPUT_DIR="$render_dir" \
  "$XCRUN" swift test --filter PopoverScreenshotRendererTests >/dev/null

for image in "${required_images[@]}"; do
  relative="${image#Docs/Images/README/}"
  rendered="$render_dir/$relative"
  [[ -f "$rendered" ]] || die "README renderer did not generate expected image: $relative"
  if ! /usr/bin/cmp -s "$ROOT_DIR/$image" "$rendered"; then
    echo "committed: $image" >&2
    if command -v /usr/bin/shasum >/dev/null 2>&1; then
      /usr/bin/shasum -a 256 "$ROOT_DIR/$image" "$rendered" >&2
    fi
    die "README image is stale; regenerate README screenshots from PopoverScreenshotRendererTests"
  fi
done

echo "README screenshot image hygiene and freshness ok"
