#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V193ReleaseReadiness.md"
PRODUCT_DOC="$ROOT_DIR/Docs/V193CodexRemainingCredits.md"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
QUALITY="$ROOT_DIR/Docs/Onboarding/QualityAndRelease.md"
SCRIPTS_DOC="$ROOT_DIR/Docs/Scripts.md"
CHECK_SCRIPT="$ROOT_DIR/script/check.sh"
V193_VERIFIER="$ROOT_DIR/script/verify_v193_codex_remaining_credits_contract.sh"
V192_VERIFIER="$ROOT_DIR/script/verify_v192_release_readiness.sh"

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify the offline v1.9.3 release-readiness checklist. This script does not
use the network, run GUI apps, install components, create tags, or publish.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

require_match() {
  local pattern="$1"
  local file="$2"
  local description="$3"
  /usr/bin/grep -Eq -- "$pattern" "$file" || die "missing $description in $file"
}

verify_contract() {
  local file
  for file in "$DOC" "$PRODUCT_DOC" "$README" "$ROADMAP" "$QUALITY" \
    "$SCRIPTS_DOC" "$CHECK_SCRIPT" "$V193_VERIFIER" "$V192_VERIFIER"; do
    require_file "$file"
  done
  [[ -x "$ROOT_DIR/script/verify_v193_release_readiness.sh" ]] || \
    die "v1.9.3 release-readiness verifier is not executable"
  [[ -x "$V193_VERIFIER" ]] || die "v1.9.3 product verifier is not executable"
  "$V192_VERIFIER" --self-test

  require_match '^상태: v1\.9\.3 GitHub Release 공개' "$DOC" "release status"
  require_match 'Finder 설치와 final-state는 미수행' "$DOC" "install remains undone"
  require_match 'signed annotated tag' "$DOC" "signed tag"
  require_match 'GitHub `Verified`' "$DOC" "verified tag gate"
  require_match 'UNSIGNED-DRAFT' "$DOC" "unsigned draft acknowledgement"
  require_match 'MacDog-1\.9\.3\.dmg\.sha256' "$DOC" "checksum asset"
  require_match 'Finder에서 published DMG' "$DOC" "Finder install boundary"
  require_match 'drag-and-drop' "$DOC" "actual drag-and-drop"
  require_match 'dist/MacDog\.app' "$DOC" "local bundle is not an install"
  require_match '`Stable Release` workflow는 실행하지 않습니다' "$DOC" \
    "stable workflow exclusion"
  require_match 'cleanup_release_smoke_state\.sh --apply' "$DOC" "cleanup gate"
  require_match 'verify_release_final_state\.sh --version 1\.9\.3' "$DOC" \
    "final-state gate"
  require_match 'merge-base --is-ancestor' "$DOC" "branch deletion gate"
  require_match '상하좌우 여백' "$DOC" "screenshot margin"
  require_match '하지 않은 설치와 GUI는 완료로 적지 않는다' "$DOC" \
    "do not mark skipped checks done"

  require_match 'V193ReleaseReadiness\.md' "$README" "README release document link"
  require_match 'V193ReleaseReadiness\.md' "$ROADMAP" "ROADMAP release document link"
  require_match 'releases/tag/v1\.9\.3' "$README" "README links v1.9.3"
  require_match 'published `v1\.9\.2`' "$QUALITY" "previous published release remains"
  require_match 'verify_v193_release_readiness\.sh --self-test' "$SCRIPTS_DOC" \
    "Scripts gate entry"
  require_match 'verify_v193_release_readiness\.sh --self-test' "$CHECK_SCRIPT" \
    "check.sh gate"

  echo "v1.9.3 release readiness ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test) ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

cd "$ROOT_DIR"
verify_contract
echo "v1.9.3 release readiness ok"
