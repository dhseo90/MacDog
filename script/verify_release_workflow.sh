#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/release-candidate.yml"

die() {
  echo "error: $*" >&2
  exit 1
}

require_match() {
  local pattern="$1"
  /usr/bin/grep -Eq "$pattern" "$WORKFLOW" || die "missing expected release workflow pattern: $pattern"
}

[[ -f "$WORKFLOW" ]] || die "release candidate workflow missing: $WORKFLOW"

require_match 'workflow_dispatch'
require_match 'MACDOG_RELEASE_VERSION'
require_match './script/check\.sh --no-run'
require_match './script/package_release\.sh --skip-build'
require_match 'hdiutil verify'
require_match 'shasum -a 256 -c'
require_match 'actions/upload-artifact@v4'
require_match 'unsigned-release-candidate'
require_match '\.dmg\.sha256'

echo "Release workflow verification ok"
