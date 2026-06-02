#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_SOURCE="$ROOT_DIR/Sources/MacDog/MacDogCharacterProfile.swift"
RUNNER_SOURCE="$ROOT_DIR/Sources/MacDog/RunnerIconRenderer.swift"
DESKTOP_SOURCE="$ROOT_DIR/Sources/MacDog/DesktopPetSpriteSet.swift"
POPOVER_SOURCE="$ROOT_DIR/Sources/MacDog/UsagePopoverView.swift"
TAB_RENDERER="$ROOT_DIR/script/render_popover_tab_art.swift"
TAB_MANIFEST="$ROOT_DIR/Sources/MacDog/Resources/CharacterProfiles/codex-pup-tab-art.json"
RESOURCE_ROOT="$ROOT_DIR/Sources/MacDog/Resources"
RUNNER_DIR="$RESOURCE_ROOT/Runner"
DESKTOP_DIR="$RESOURCE_ROOT/DesktopPet"
TAB_DIR="$RESOURCE_ROOT/PopoverTabs"
EXPECTED_PNGS="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-expected-pngs.XXXXXX")"
ACTUAL_PNGS="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-actual-pngs.XXXXXX")"
trap 'rm -f "$EXPECTED_PNGS" "$ACTUAL_PNGS"' EXIT

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

require_png() {
  require_file "$1"
  printf '%s\n' "$1" >>"$EXPECTED_PNGS"
}

png_property() {
  local file="$1"
  local property="$2"
  sips -g "$property" "$file" 2>/dev/null | awk -v property="$property:" '$1 == property { print $2 }'
}

require_png_dimensions() {
  local file="$1"
  local expected_width="$2"
  local expected_height="$3"
  local width
  local height
  width="$(png_property "$file" pixelWidth)"
  height="$(png_property "$file" pixelHeight)"
  [[ "$width" == "$expected_width" && "$height" == "$expected_height" ]] || die "unexpected PNG size for $file: ${width}x${height}, expected ${expected_width}x${expected_height}"
}

require_png_alpha() {
  local file="$1"
  local has_alpha
  has_alpha="$(png_property "$file" hasAlpha)"
  [[ "$has_alpha" == "yes" ]] || die "PNG must keep transparent-background alpha channel: $file"
}

require_profile_png() {
  local file="$1"
  local expected_width="$2"
  local expected_height="$3"
  require_png "$file"
  require_png_dimensions "$file" "$expected_width" "$expected_height"
  require_png_alpha "$file"
}

require_text_match() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if command -v rg >/dev/null 2>&1; then
    rg -q -- "$pattern" "$file" || die "missing character profile guard: $description"
  else
    /usr/bin/grep -Eq -- "$pattern" "$file" || die "missing character profile guard: $description"
  fi
}

require_png_series() {
  local dir="$1"
  local prefix="$2"
  local count="$3"
  local expected_width="$4"
  local expected_height="$5"

  for index in $(seq 0 $((count - 1))); do
    require_profile_png "$dir/$prefix-$index.png" "$expected_width" "$expected_height"
  done
}

require_file "$PROFILE_SOURCE"
require_file "$RUNNER_SOURCE"
require_file "$DESKTOP_SOURCE"
require_file "$POPOVER_SOURCE"
require_file "$TAB_RENDERER"
require_file "$TAB_MANIFEST"

require_text_match 'static let codexPup' "$PROFILE_SOURCE" "Codex Pup is the active character profile"
require_text_match 'runner: RunnerAssetCatalog' "$PROFILE_SOURCE" "profile owns runner assets"
require_text_match 'desktopPet: DesktopPetAssetCatalog' "$PROFILE_SOURCE" "profile owns desktop pet assets"
require_text_match 'popoverTabs: PopoverTabAssetCatalog' "$PROFILE_SOURCE" "profile owns popover tab artwork"

require_text_match 'MacDogCharacterProfile\.codexPup\.runner\.frameCount' "$RUNNER_SOURCE" "menu bar runner frame count comes from the profile"
require_text_match 'profile\.runner\.framePrefix' "$RUNNER_SOURCE" "menu bar runner frame prefix comes from the profile"
require_text_match 'profile\.desktopPet\.asset\(for: pose\)' "$DESKTOP_SOURCE" "desktop pet poses come from the profile"
require_text_match 'MacDogCharacterProfile\.codexPup\.popoverTabs\.artwork\(for: self\)' "$POPOVER_SOURCE" "tab buttons come from the profile"
require_text_match 'codex-pup-tab-art\.json' "$TAB_RENDERER" "tab artwork renderer reads the character tab manifest"
require_text_match 'manifest\.desktopSource\.resourceDirectory' "$TAB_RENDERER" "tab artwork renderer reads the desktop pet directory from the manifest"
require_text_match 'manifest\.desktopSource\.resourcePrefix' "$TAB_RENDERER" "tab artwork renderer reads the desktop pet sprite prefix from the manifest"
require_text_match 'item\.resourcePrefix' "$TAB_RENDERER" "tab artwork renderer reads per-tab desktop pet sprite prefix"
require_text_match 'item\.sourceFrameIndex' "$TAB_RENDERER" "tab artwork renderer reads per-tab desktop pet frame"
require_text_match '"characterId"[[:space:]]*:[[:space:]]*"codex-pup"' "$TAB_MANIFEST" "tab artwork manifest belongs to Codex Pup"
require_text_match '"sourcePose"[[:space:]]*:[[:space:]]*"idleFront"' "$TAB_MANIFEST" "tab artwork manifest records the source pose"
require_text_match '"sourcePose"[[:space:]]*:[[:space:]]*"runRight"' "$TAB_MANIFEST" "tab artwork manifest records the active resources pose"
require_text_match '"sourcePose"[[:space:]]*:[[:space:]]*"rest"' "$TAB_MANIFEST" "tab artwork manifest records the sleep pose"
require_text_match '"sourcePose"[[:space:]]*:[[:space:]]*"alert"' "$TAB_MANIFEST" "tab artwork manifest records the battery pose"
require_text_match '"sourcePose"[[:space:]]*:[[:space:]]*"idleSide"' "$TAB_MANIFEST" "tab artwork manifest records the settings pose"
require_text_match '"sourceFrameIndex"[[:space:]]*:[[:space:]]*0' "$TAB_MANIFEST" "tab artwork manifest records the source frame"
require_text_match '"sourceFrameIndex"[[:space:]]*:[[:space:]]*2' "$TAB_MANIFEST" "tab artwork manifest records an active resources frame"
require_text_match '"outputDirectory"[[:space:]]*:[[:space:]]*"PopoverTabs"' "$TAB_MANIFEST" "tab artwork manifest records the tab output directory"

require_png_series "$RUNNER_DIR" "pup-runner" 8 80 48
require_png_series "$DESKTOP_DIR" "pup-run-right" 8 192 204
require_png_series "$DESKTOP_DIR" "pup-run-up" 8 192 204
require_png_series "$DESKTOP_DIR" "pup-run-down" 8 192 204
require_png_series "$DESKTOP_DIR" "pup-idle-front" 4 192 204
require_png_series "$DESKTOP_DIR" "pup-idle-side" 4 192 204
require_png_series "$DESKTOP_DIR" "pup-rest" 4 192 204
require_png_series "$DESKTOP_DIR" "pup-alert" 4 192 204

for tab in codex mac sleep battery settings; do
  require_profile_png "$TAB_DIR/$tab-tab.png" 256 256
done

find "$RESOURCE_ROOT" -type f -name '*.png' -print | sort >"$ACTUAL_PNGS"
sort -o "$EXPECTED_PNGS" "$EXPECTED_PNGS"
if ! diff -u "$EXPECTED_PNGS" "$ACTUAL_PNGS" >/dev/null; then
  diff -u "$EXPECTED_PNGS" "$ACTUAL_PNGS" >&2 || true
  die "unexpected PNG resource detected; remove unused images or register them in MacDogCharacterProfile"
fi

echo "Character profile ok: Codex Pup links runner, desktop pet, and popover tab assets"
