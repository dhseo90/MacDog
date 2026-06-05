#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_SOURCE="$ROOT_DIR/Sources/MacDog/MacDogCharacterProfile.swift"
RENDERER_SOURCE="$ROOT_DIR/Sources/MacDog/MenuBarIconRenderer.swift"
RESOURCE_ROOT="$ROOT_DIR/Sources/MacDog/Resources"
MENU_BAR_BASELINE_DOC="$ROOT_DIR/Docs/MenuBarCharacterBaseline.md"
DESKTOP_DIR="$RESOURCE_ROOT/DesktopPet"
EXPECTED_COUNT=8
EXPECTED_WIDTH=192
EXPECTED_HEIGHT=204

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

require_text() {
  local pattern="$1"
  local file="$2"
  local description="$3"
  rg -q -- "$pattern" "$file" || die "missing menu bar character baseline: $description"
}

png_property() {
  local file="$1"
  local property="$2"
  sips -g "$property" "$file" 2>/dev/null | awk -v property="$property:" '$1 == property { print $2 }'
}

require_file "$PROFILE_SOURCE"
require_file "$RENDERER_SOURCE"
require_file "$MENU_BAR_BASELINE_DOC"

require_text 'menuBarImage: MenuBarImageAssetCatalog\(sourcePose: \.runRight\)' "$PROFILE_SOURCE" "profile maps menu bar to the current desktop pet run-right pose"
require_text 'profile\.menuBarImage\.sourcePose' "$RENDERER_SOURCE" "renderer reads the menu bar source pose from the profile"
require_text 'profile\.desktopPet\.asset\(for: sourcePose\)' "$RENDERER_SOURCE" "renderer uses desktop pet frames"
require_text 'DesktopPet/pup-run-right-0\.png' "$MENU_BAR_BASELINE_DOC" "baseline documents the current desktop pet source"
require_text '현재 데스크톱 펫 프레임을 직접 축소해 사용합니다' "$MENU_BAR_BASELINE_DOC" "baseline documents the current menu bar source"

actual_count="$(find "$DESKTOP_DIR" -maxdepth 1 -name 'pup-run-right-*.png' | wc -l | awk '{$1=$1; print}')"
if [[ "$actual_count" != "$EXPECTED_COUNT" ]]; then
  die "expected $EXPECTED_COUNT current menu bar source frames, found $actual_count"
fi

for index in $(seq 0 $((EXPECTED_COUNT - 1))); do
  file="$DESKTOP_DIR/pup-run-right-$index.png"
  require_file "$file"

  width="$(png_property "$file" pixelWidth)"
  height="$(png_property "$file" pixelHeight)"
  has_alpha="$(png_property "$file" hasAlpha)"

  [[ "$width" == "$EXPECTED_WIDTH" && "$height" == "$EXPECTED_HEIGHT" ]] || die "unexpected current menu bar source size for $file: ${width}x${height}, expected ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT}"
  [[ "$has_alpha" == "yes" ]] || die "current menu bar source must keep transparent-background alpha channel: $file"
done

echo "Menu bar character baseline ok: source=DesktopPet/pup-run-right frames=$EXPECTED_COUNT size=${EXPECTED_WIDTH}x${EXPECTED_HEIGHT}px"
