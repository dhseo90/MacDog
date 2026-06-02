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
  require_file_contains "$file" "Apple Developer Program"
  require_file_contains "$file" "현재 구현 계획에서 제외"
done

require_file_match "$ROADMAP" 'signed stable.*v1\.1\.0.*제외|signed stable.*현재 계획에서 삭제'
require_file_match "$ROADMAP" 'WidgetKit.*확인.*source|WidgetKit.*source.*확인'
require_file_match "$ROADMAP" '실제.*위젯 UI.*확인하지 못했습니다'

dry_run_output="$("$PACKAGE_SCRIPT" --dry-run)"
require_output_contains "$dry_run_output" "Signing: local ad-hoc build only; Developer ID signing and notarization are not performed"
require_output_contains "$dry_run_output" "excluded from the current implementation plan"
require_output_contains "$dry_run_output" "Gatekeeper: GitHub Release notes must clearly say this DMG is not notarized and may show a macOS warning."
require_output_contains "$dry_run_output" "GitHub Release:"

require_file_contains "$DRAFT_WORKFLOW" "UNSIGNED-DRAFT"
require_file_contains "$DRAFT_WORKFLOW" "--draft"
if /usr/bin/grep -Eq -- '--prerelease|isPrerelease|MACDOG_PRERELEASE|inputs\.prerelease|Mark the draft release as a prerelease' "$DRAFT_WORKFLOW"; then
  die "draft release workflow must not mark v1.1.0 releases as prerelease"
fi

if [[ -f "$STABLE_WORKFLOW" ]]; then
  require_file_contains "$STABLE_WORKFLOW" "SIGNED-STABLE"
  require_file_contains "$RELEASE_DOC" "release-stable.yml"
  require_file_match "$RELEASE_DOC" 'release-stable\.yml.*v1\.1\.0.*제외|signed stable.*v1\.1\.0.*제외'
fi

echo "Distribution gate verification ok"
