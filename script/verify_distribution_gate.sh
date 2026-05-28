#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
RELEASE_DOC="$ROOT_DIR/Docs/ReleasePackaging.md"
PACKAGE_SCRIPT="$ROOT_DIR/script/package_release.sh"
DRAFT_WORKFLOW="$ROOT_DIR/.github/workflows/release-draft.yml"
STABLE_WORKFLOW="$ROOT_DIR/.github/workflows/release-stable.yml"

die() {
  echo "error: $*" >&2
  exit 1
}

require_file_contains() {
  local file="$1"
  local text="$2"
  /usr/bin/grep -Fq -- "$text" "$file" || die "missing distribution gate text in $file: $text"
}

require_file_match() {
  local file="$1"
  local pattern="$2"
  /usr/bin/grep -Eq -- "$pattern" "$file" || die "missing distribution gate pattern in $file: $pattern"
}

require_output_contains() {
  local output="$1"
  local text="$2"
  if [[ "$output" != *"$text"* ]]; then
    die "missing distribution gate dry-run text: $text"
  fi
}

[[ -f "$README" ]] || die "README missing"
[[ -f "$ROADMAP" ]] || die "ROADMAP missing"
[[ -f "$RELEASE_DOC" ]] || die "release packaging doc missing"
[[ -x "$PACKAGE_SCRIPT" ]] || die "package release script missing or not executable"
[[ -f "$DRAFT_WORKFLOW" ]] || die "draft release workflow missing"

for file in "$README" "$ROADMAP" "$RELEASE_DOC"; do
  require_file_contains "$file" "Developer ID signing"
  require_file_contains "$file" "notarization"
  require_file_contains "$file" "Gatekeeper"
done
require_file_contains "$ROADMAP" "hardened runtime"
require_file_contains "$RELEASE_DOC" "stapling"

dry_run_output="$("$PACKAGE_SCRIPT" --dry-run)"
require_output_contains "$dry_run_output" "Signing: local ad-hoc build only; Developer ID signing and notarization are not performed."
require_output_contains "$dry_run_output" "Gatekeeper: unsigned candidates are local validation artifacts and must not be published as public stable releases."
require_output_contains "$dry_run_output" "GitHub Release:"

require_file_contains "$DRAFT_WORKFLOW" "UNSIGNED-DRAFT"
require_file_contains "$DRAFT_WORKFLOW" "--draft"
require_file_contains "$DRAFT_WORKFLOW" "--prerelease"

if [[ -f "$STABLE_WORKFLOW" ]]; then
  require_file_contains "$STABLE_WORKFLOW" "SIGNED-STABLE"
  require_file_contains "$STABLE_WORKFLOW" "public-stable-release"
  require_file_contains "$STABLE_WORKFLOW" "MACDOG_DEVELOPER_ID_APPLICATION_CERT_BASE64"
  require_file_contains "$STABLE_WORKFLOW" "MACDOG_DEVELOPER_ID_APPLICATION"
  require_file_contains "$STABLE_WORKFLOW" "MACDOG_NOTARY_APPLE_ID"
  require_file_contains "$STABLE_WORKFLOW" "MACDOG_NOTARY_TEAM_ID"
  require_file_contains "$STABLE_WORKFLOW" "MACDOG_NOTARY_APP_SPECIFIC_PASSWORD"
  require_file_match "$STABLE_WORKFLOW" 'codesign.+--options[ =]runtime|--options[ =]runtime.+codesign'
  require_file_contains "$STABLE_WORKFLOW" "notarytool"
  require_file_contains "$STABLE_WORKFLOW" "stapler"
  require_file_contains "$STABLE_WORKFLOW" "spctl"
  require_file_contains "$STABLE_WORKFLOW" "gh release create"
  require_file_contains "$STABLE_WORKFLOW" "--latest"
  if /usr/bin/grep -Fq -- "--draft" "$STABLE_WORKFLOW"; then
    die "stable release workflow must not create draft releases"
  fi
else
  echo "Stable release workflow not present; public stable release remains gated."
fi

echo "Distribution gate verification ok"
