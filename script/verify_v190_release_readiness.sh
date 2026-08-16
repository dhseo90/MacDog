#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V190ReleaseReadiness.md"
PRODUCT_DOC="$ROOT_DIR/Docs/V190GrokUsageAndClaudeHide.md"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
AGENTS="$ROOT_DIR/AGENTS.md"
SCRIPTS_DOC="$ROOT_DIR/Docs/Scripts.md"
CHECK_SCRIPT="$ROOT_DIR/script/check.sh"
V190_VERIFIER="$ROOT_DIR/script/verify_v190_selected_provider_contract.sh"
V180_VERIFIER="$ROOT_DIR/script/verify_v180_release_readiness.sh"

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify the offline v1.9.0 release-readiness checklist and unfinished-smoke
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
    "$CHECK_SCRIPT" "$V190_VERIFIER" "$V180_VERIFIER"; do
    require_file "$file"
  done
  [[ -x "$ROOT_DIR/script/verify_v190_release_readiness.sh" ]] || \
    die "v1.9 release-readiness verifier is not executable"
  [[ -x "$V190_VERIFIER" ]] || die "v1.9 selected-provider verifier is not executable"
  [[ -x "$V180_VERIFIER" ]] || die "v1.8 release-readiness verifier is not executable"

  require_match '^상태: 1차 구현·문서 정렬 완료' "$DOC" "implementation and docs status"
  require_match 'GUI·live Grok billing·published DMG·Finder 설치·final-state' "$DOC" \
    "unfinished smoke status"
  require_match '미수행' "$DOC" "honest unfinished marker"
  require_match 'MACDOG_APP_VERSION=1\.9\.0 \./script/check\.sh --no-run' "$DOC" \
    "versioned check gate"
  require_match 'verify_v190_selected_provider_contract\.sh --self-test' "$DOC" \
    "v1.9 product gate"
  require_match 'verify_v180_selected_provider_contract\.sh --self-test' "$DOC" \
    "preserved v1.8 product gate"
  require_match '현재 GitHub Release는 `v1\.8\.0`' "$DOC" "published release stays v1.8.0"
  require_match '`v1\.9\.0` tag와 published DMG는 없습니다' "$DOC" \
    "no published v1.9.0 claim"
  require_match 'creditUsagePercent' "$DOC" "live Grok field"
  require_match '100 - usedPercent' "$DOC" "Grok remaining calculation"
  require_match '~/\.grok/auth\.json' "$DOC" "Grok auth privacy boundary"
  require_match 'Finder에서 published DMG.*`MacDog\.app`.*`Applications`' "$DOC" \
    "Finder installation boundary"
  require_match 'drag-and-drop' "$DOC" "actual drag-and-drop boundary"
  require_match 'visible mode가 `Codex`/`Grok`' "$DOC" "settings GUI smoke"
  require_match 'verify_release_final_state\.sh --version 1\.9\.0' "$DOC" "final-state gate"
  require_match '릴리즈 증거 기록' "$DOC" "evidence ledger"
  require_match '실제 Grok live smoke \| 미수행' "$DOC" "honest live evidence"
  require_match 'Finder drag-and-drop와 GUI smoke \| 미수행' "$DOC" \
    "honest GUI evidence"
  require_match 'Published `v1\.9\.0` DMG \| 없음' "$DOC" "honest unpublished DMG"
  require_match '사용자가 릴리즈 전 직접 검수' "$DOC" "user-owned UI review"
  require_match '`Stable Release` workflow' "$DOC" "stable workflow scope"
  require_match '승인되지 않았으므로 실행하지 않습니다' "$DOC" "stable workflow exclusion"
  require_absent_match 'v1\.9\.0 GitHub Release publish / published DMG Finder 설치' \
    "$DOC" "completed publish status"
  require_absent_match '실제 Grok live smoke \| 통과' "$DOC" "false live completion"
  require_absent_match 'Finder drag-and-drop와 GUI smoke \| 통과' "$DOC" \
    "false GUI completion"

  require_match 'V190ReleaseReadiness\.md' "$README" "README release document link"
  require_match 'V190ReleaseReadiness\.md' "$ROADMAP" "ROADMAP release document link"
  require_match '현재 GitHub Release는 \[v1\.8\.0\]' "$README" "README current release"
  require_match 'MacDog-1\.8\.0\.dmg' "$README" "README current installer"
  require_match 'v1\.9\.0.*미수행' "$ROADMAP" "ROADMAP unfinished smoke"
  require_match 'GUI·live·published release 미수행' "$PRODUCT_DOC" \
    "product honest smoke status"
  require_match 'verify_v190_release_readiness\.sh --self-test' "$SCRIPTS_DOC" \
    "Scripts gate entry"
  require_match 'verify_v190_release_readiness\.sh --self-test' "$CHECK_SCRIPT" \
    "check.sh gate"
  require_match 'verify_v190_selected_provider_contract\.sh --self-test' \
    "$CHECK_SCRIPT" "product gate ordering"
  require_match '~/\.grok/auth\.json' "$AGENTS" "AGENTS Grok auth rule"

  echo "v1.9.0 release readiness ok"
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
