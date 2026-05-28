#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$ROOT_DIR/README.md"

die() {
  echo "error: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "required tool not found: $1"
}

image_width() {
  /usr/bin/sips -g pixelWidth "$1" 2>/dev/null | /usr/bin/awk '/pixelWidth/ { print $2 }'
}

image_height() {
  /usr/bin/sips -g pixelHeight "$1" 2>/dev/null | /usr/bin/awk '/pixelHeight/ { print $2 }'
}

require_readme_reference() {
  local relative_path="$1"
  /usr/bin/grep -Fq "$relative_path" "$README" || die "README does not reference screenshot: $relative_path"
}

require_image_size() {
  local relative_path="$1"
  local expected_width="$2"
  local expected_height="$3"
  local file="$ROOT_DIR/$relative_path"

  [[ -f "$file" ]] || die "screenshot missing: $relative_path"
  require_readme_reference "$relative_path"

  local actual_width
  local actual_height
  actual_width="$(image_width "$file")"
  actual_height="$(image_height "$file")"

  [[ "$actual_width" == "$expected_width" ]] || die "unexpected width for $relative_path: $actual_width != $expected_width"
  [[ "$actual_height" == "$expected_height" ]] || die "unexpected height for $relative_path: $actual_height != $expected_height"
}

require_tool /usr/bin/sips
[[ -f "$README" ]] || die "README missing: $README"

require_image_size "Assets/Generated/Docs/PopoverTabs/macdog-popover-codex.png" 740 816
require_image_size "Assets/Generated/Docs/PopoverTabs/macdog-popover-mac.png" 740 816
require_image_size "Assets/Generated/Docs/PopoverTabs/macdog-popover-sleep.png" 740 816
require_image_size "Assets/Generated/Docs/PopoverTabs/macdog-popover-battery.png" 740 816
require_image_size "Assets/Generated/Docs/macdog-desktop-pet-front.png" 192 204

echo "README screenshot verification ok"
