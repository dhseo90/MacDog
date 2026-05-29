#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/release-candidate.yml"
DRAFT_WORKFLOW="$ROOT_DIR/.github/workflows/release-draft.yml"
STABLE_WORKFLOW="$ROOT_DIR/.github/workflows/release-stable.yml"

die() {
  echo "error: $*" >&2
  exit 1
}

require_match() {
  local pattern="$1"
  /usr/bin/grep -Eq -- "$pattern" "$WORKFLOW" || die "missing expected release workflow pattern: $pattern"
}

require_draft_match() {
  local pattern="$1"
  /usr/bin/grep -Eq -- "$pattern" "$DRAFT_WORKFLOW" || die "missing expected draft release workflow pattern: $pattern"
}

require_stable_match() {
  local pattern="$1"
  /usr/bin/grep -Eq -- "$pattern" "$STABLE_WORKFLOW" || die "missing expected stable release workflow pattern: $pattern"
}

[[ -f "$WORKFLOW" ]] || die "release candidate workflow missing: $WORKFLOW"
[[ -f "$DRAFT_WORKFLOW" ]] || die "draft release workflow missing: $DRAFT_WORKFLOW"

require_match 'workflow_dispatch'
require_match 'MACDOG_RELEASE_VERSION'
require_match './script/check\.sh --no-run'
require_match './script/package_release\.sh --skip-build'
require_match 'hdiutil verify'
require_match 'shasum -a 256 -c'
require_match 'actions/upload-artifact@v4'
require_match 'unsigned-release-candidate'
require_match '\.dmg\.sha256'

require_draft_match 'workflow_dispatch'
require_draft_match 'contents: write'
require_draft_match 'UNSIGNED-DRAFT'
require_draft_match './script/check\.sh --no-run'
require_draft_match './script/package_release\.sh --skip-build'
require_draft_match 'hdiutil verify'
require_draft_match 'shasum -a 256 -c'
require_draft_match 'gh "\$\{args\[@\]\}"'
require_draft_match '--draft'
require_draft_match '--notes-file'
require_draft_match '\.dmg\.sha256'

if [[ -f "$STABLE_WORKFLOW" ]]; then
  require_stable_match 'workflow_dispatch'
  require_stable_match 'contents: write'
  require_stable_match 'SIGNED-STABLE'
  require_stable_match 'public-stable-release'
  require_stable_match './script/check\.sh --no-run'
  require_stable_match './script/build_and_run\.sh --no-run'
  require_stable_match 'codesign.+--options[ =]runtime|--options[ =]runtime.+codesign'
  require_stable_match 'Contents/MacOS/codex-usage'
  require_stable_match 'notarytool submit'
  require_stable_match 'stapler staple'
  require_stable_match 'spctl --assess'
  require_stable_match 'shasum -a 256 -c'
  require_stable_match 'gh release create'
  require_stable_match '--latest'
fi

"$ROOT_DIR/script/verify_distribution_gate.sh" >/dev/null

echo "Release workflow verification ok"
