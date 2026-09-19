#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V192ReleaseReadiness.md"
PRODUCT_DOC="$ROOT_DIR/Docs/V192MenuBarGlancePolish.md"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
QUALITY="$ROOT_DIR/Docs/Onboarding/QualityAndRelease.md"
SCRIPTS_DOC="$ROOT_DIR/Docs/Scripts.md"
CHECK_SCRIPT="$ROOT_DIR/script/check.sh"
V192_VERIFIER="$ROOT_DIR/script/verify_v192_menu_bar_glance_contract.sh"
V191_VERIFIER="$ROOT_DIR/script/verify_v191_release_readiness.sh"
UNINSTALL="$ROOT_DIR/script/uninstall.sh"

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify the offline v1.9.2 release-readiness checklist. This script does not
use the network, run GUI apps, install components, start workflows, create
tags, publish releases, or read ~/.grok/auth.json.
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
  for file in "$DOC" "$PRODUCT_DOC" "$README" "$ROADMAP" "$QUALITY" "$SCRIPTS_DOC" \
    "$CHECK_SCRIPT" "$V192_VERIFIER" "$V191_VERIFIER" "$UNINSTALL"; do
    require_file "$file"
  done
  [[ -x "$ROOT_DIR/script/verify_v192_release_readiness.sh" ]] || \
    die "v1.9.2 release-readiness verifier is not executable"
  [[ -x "$V192_VERIFIER" ]] || die "v1.9.2 product verifier is not executable"
  "$V191_VERIFIER" --self-test
  reject_v192_in_v191

  require_match '^상태: 릴리즈 준비 / PR 전' "$DOC" "pre-PR status"
  require_match 'published GitHub Release는 `v1\.9\.1`' "$DOC" "published remains v1.9.1"
  require_match 'MACDOG_APP_VERSION=1\.9\.2 \./script/check\.sh --no-run' "$DOC" \
    "versioned check gate"
  require_match 'verify_v192_menu_bar_glance_contract\.sh --self-test' "$DOC" \
    "v1.9.2 product gate"
  require_match 'verify_v192_release_readiness\.sh --self-test' "$DOC" "self gate"
  require_match '현재 잔여 사용량' "$DOC" "remaining amount setting"
  require_match '% 표기' "$DOC" "percent sign setting"
  require_match '별도 uninstall 실실행 항목은 두지 않습니다' "$DOC" \
    "no separate uninstall test"
  require_match 'Finder에서 published DMG' "$DOC" "Finder installation boundary"
  require_match 'drag-and-drop' "$DOC" "actual drag-and-drop boundary"
  require_match '이번 주 그래프가 단순 직선으로 리셋되지 않았는지' "$DOC" \
    "graph preserve during reinstall"
  require_match 'Would preserve' "$DOC" "uninstall dry-run preserve"
  require_match '`Stable Release` workflow' "$DOC" "stable workflow scope"
  require_match '승인되지 않았으므로 실행하지 않습니다' "$DOC" "stable workflow exclusion"
  require_match 'PR 미수행' "$DOC" "honest PR status"
  require_match 'Published `v1\.9\.2` DMG \| 없음' "$DOC" "honest unpublished DMG"
  require_match 'Finder drag-and-drop와 그래프 보존 \| 미수행' "$DOC" \
    "honest install evidence"
  require_absent_match 'Published `v1\.9\.2` DMG \| 있음' "$DOC" \
    "false published v1.9.2 DMG"
  require_absent_match '^상태: v1\.9\.2 GitHub Release publish' "$DOC" \
    "false published status"

  require_match 'Would preserve usage history file:' "$UNINSTALL" \
    "uninstall preserves weekly history"
  reject_match_uninstall_wipe

  require_match 'V192ReleaseReadiness\.md' "$README" "README release document link"
  require_match 'V192ReleaseReadiness\.md' "$ROADMAP" "ROADMAP release document link"
  require_match 'GitHub Release는 \[v1\.9\.1\]' "$README" "README published remains v1.9.1"
  require_match '현재 잔여 사용량' "$README" "README remaining amount copy"
  require_match '% 표기' "$README" "README percent sign copy"
  require_match '릴리즈 준비 / PR 전' "$ROADMAP" "ROADMAP pre-PR status"
  require_match '그래프 history를 남겨' "$ROADMAP" "ROADMAP history preserve"
  require_match '릴리즈 준비 / PR 전' "$QUALITY" "QualityAndRelease pre-PR"
  require_match 'verify_v192_release_readiness\.sh --self-test' "$SCRIPTS_DOC" \
    "Scripts gate entry"
  require_match 'verify_v192_release_readiness\.sh --self-test' "$CHECK_SCRIPT" \
    "check.sh gate"

  echo "v1.9.2 release readiness ok"
}

reject_v192_in_v191() {
  if /usr/bin/grep -Eq 'v1\.9\.2' "$V191_VERIFIER"; then
    die "v1.9.1 release-readiness verifier mentioning v1.9.2"
  fi
}

reject_match_uninstall_wipe() {
  if /usr/bin/grep -Eq 'Would remove usage history file:' "$UNINSTALL"; then
    die "uninstall still wipes weekly history"
  fi
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
echo "v1.9.2 release readiness ok"
