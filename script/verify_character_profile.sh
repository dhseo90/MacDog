#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_SOURCE="$ROOT_DIR/Sources/MacDog/MacDogCharacterProfile.swift"
RUNNER_SOURCE="$ROOT_DIR/Sources/MacDog/RunnerIconRenderer.swift"
DESKTOP_SOURCE="$ROOT_DIR/Sources/MacDog/DesktopPetSpriteSet.swift"
POPOVER_SOURCE="$ROOT_DIR/Sources/MacDog/UsagePopoverView.swift"
TAB_RENDERER="$ROOT_DIR/script/render_popover_tab_art.swift"
RESOURCE_ROOT="$ROOT_DIR/Sources/MacDog/Resources"
RUNNER_DIR="$RESOURCE_ROOT/Runner"
DESKTOP_DIR="$RESOURCE_ROOT/DesktopPet"
TAB_DIR="$RESOURCE_ROOT/PopoverTabs"

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
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

  for index in $(seq 0 $((count - 1))); do
    require_file "$dir/$prefix-$index.png"
  done
}

require_file "$PROFILE_SOURCE"
require_file "$RUNNER_SOURCE"
require_file "$DESKTOP_SOURCE"
require_file "$POPOVER_SOURCE"
require_file "$TAB_RENDERER"

require_text_match 'static let codexPup' "$PROFILE_SOURCE" "Codex Pup is the active character profile"
require_text_match 'runner: RunnerAssetCatalog' "$PROFILE_SOURCE" "profile owns runner assets"
require_text_match 'desktopPet: DesktopPetAssetCatalog' "$PROFILE_SOURCE" "profile owns desktop pet assets"
require_text_match 'popoverTabs: PopoverTabAssetCatalog' "$PROFILE_SOURCE" "profile owns popover tab artwork"

require_text_match 'MacDogCharacterProfile\.codexPup\.runner\.frameCount' "$RUNNER_SOURCE" "menu bar runner frame count comes from the profile"
require_text_match 'profile\.runner\.framePrefix' "$RUNNER_SOURCE" "menu bar runner frame prefix comes from the profile"
require_text_match 'profile\.desktopPet\.asset\(for: pose\)' "$DESKTOP_SOURCE" "desktop pet poses come from the profile"
require_text_match 'MacDogCharacterProfile\.codexPup\.popoverTabs\.artwork\(for: self\)' "$POPOVER_SOURCE" "tab buttons come from the profile"
require_text_match '"DesktopPet"' "$TAB_RENDERER" "tab artwork renderer reads the desktop pet directory"
require_text_match '"pup-idle-front-0\.png"' "$TAB_RENDERER" "tab artwork is generated from the Codex Pup desktop sprite"

require_png_series "$RUNNER_DIR" "pup-runner" 8
require_png_series "$DESKTOP_DIR" "pup-run-right" 8
require_png_series "$DESKTOP_DIR" "pup-run-up" 8
require_png_series "$DESKTOP_DIR" "pup-run-down" 8
require_png_series "$DESKTOP_DIR" "pup-idle-front" 4
require_png_series "$DESKTOP_DIR" "pup-idle-side" 4
require_png_series "$DESKTOP_DIR" "pup-rest" 4
require_png_series "$DESKTOP_DIR" "pup-alert" 4

for tab in codex mac sleep battery; do
  require_file "$TAB_DIR/$tab-tab.png"
  width="$(sips -g pixelWidth "$TAB_DIR/$tab-tab.png" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
  height="$(sips -g pixelHeight "$TAB_DIR/$tab-tab.png" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"
  [[ "$width" == "256" && "$height" == "256" ]] || die "unexpected tab artwork size for $tab-tab.png: ${width}x${height}"
done

echo "Character profile ok: Codex Pup links runner, desktop pet, and popover tab assets"
