#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V191ReleaseReadiness.md"
PRODUCT_DOC="$ROOT_DIR/Docs/V191MultiProviderUsage.md"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
AGENTS="$ROOT_DIR/AGENTS.md"
SCRIPTS_DOC="$ROOT_DIR/Docs/Scripts.md"
CHECK_SCRIPT="$ROOT_DIR/script/check.sh"
V191_VERIFIER="$ROOT_DIR/script/verify_v191_multi_provider_contract.sh"
V190_VERIFIER="$ROOT_DIR/script/verify_v190_release_readiness.sh"

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify the offline v1.9.1 release-readiness checklist and unfinished-smoke
boundary. This script does not use the network, run GUI apps, install
components, start workflows, create tags, publish releases, or read
~/.grok/auth.json.
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

require_absent_match() {
  local pattern="$1"
  local file="$2"
  local description="$3"
  ! /usr/bin/grep -Eq -- "$pattern" "$file" || die "found $description in $file"
}

verify_contract() {
  local file
  for file in "$DOC" "$PRODUCT_DOC" "$README" "$ROADMAP" "$AGENTS" "$SCRIPTS_DOC" \
    "$CHECK_SCRIPT" "$V191_VERIFIER" "$V190_VERIFIER"; do
    require_file "$file"
  done
  [[ -x "$ROOT_DIR/script/verify_v191_release_readiness.sh" ]] || \
    die "v1.9.1 release-readiness verifier is not executable"
  [[ -x "$V191_VERIFIER" ]] || die "v1.9.1 product verifier is not executable"
  [[ -x "$V190_VERIFIER" ]] || die "v1.9.0 release-readiness verifier is not executable"

  require_match '^상태: 자동 gate 준비' "$DOC" "unpublished readiness status"
  require_match 'published GitHub Release는 `v1\.9\.0` 유지' "$DOC" \
    "published release stays v1.9.0"
  require_match '미수행' "$DOC" "honest unfinished marker"
  require_match 'MACDOG_APP_VERSION=1\.9\.1 \./script/check\.sh --no-run' "$DOC" \
    "versioned check gate"
  require_match 'verify_v191_multi_provider_contract\.sh --self-test' "$DOC" \
    "v1.9.1 product gate"
  require_match 'verify_v191_release_readiness\.sh --self-test' "$DOC" \
    "self gate"
  require_match '사용량 mode' "$DOC" "legacy picker called out as absent"
  require_match '페이스메이커 블록을 두지 않습니다' "$DOC" "Codex tab has no pacemaker block"
  require_match 'Finder drag-and-drop와 GUI smoke \| 미수행' "$DOC" \
    "honest GUI evidence"
  require_match 'Published `v1\.9\.1` DMG \| 없음' "$DOC" "unpublished DMG"
  require_match '실제 Grok live smoke \| 미수행' "$DOC" "honest live evidence"
  require_absent_match '현재 GitHub Release는 \[v1\.9\.1\]' "$README" \
    "unpublished 1.9.1 claimed as current GitHub Release"
  require_absent_match 'MacDog-1\.9\.1\.dmg' "$README" "unpublished 1.9.1 installer"
  require_absent_match '실제 Grok live smoke \| 통과' "$DOC" "false live completion"
  require_absent_match 'Finder drag-and-drop와 GUI smoke \| 통과' "$DOC" \
    "false GUI completion"

  require_match 'V191ReleaseReadiness\.md' "$README" "README release document link"
  require_match 'V191ReleaseReadiness\.md' "$ROADMAP" "ROADMAP release document link"
  require_match '현재 GitHub Release는 \[v1\.9\.0\]' "$README" "README current release"
  require_match '활성 provider' "$README" "README current gauges"
  require_absent_match '사용량 mode`\(`Codex`/`Grok`\)' "$README" \
    "README current settings still exclusive mode picker"
  require_match 'UI 확인 미수행' "$ROADMAP" "honest UI status"
  require_match 'verify_v191_release_readiness\.sh --self-test' "$SCRIPTS_DOC" \
    "Scripts gate entry"
  require_match 'verify_v191_release_readiness\.sh --self-test' "$CHECK_SCRIPT" \
    "check.sh gate"
  require_match 'verify_v191_multi_provider_contract\.sh --self-test' \
    "$CHECK_SCRIPT" "product gate ordering"
  require_match '~/\.grok/auth\.json' "$AGENTS" "AGENTS Grok auth rule"
  require_match '카드에 이름 한 번' "$PRODUCT_DOC" "current gauge card copy"

  echo "v1.9.1 release readiness ok"
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
