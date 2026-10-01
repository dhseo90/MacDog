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

  require_match '^상태: v1\.9\.2 GitHub Release publish' "$DOC" "published release status"
  require_match 'published GitHub Release는 \[v1\.9\.2\]' "$DOC" "published release is v1.9.2"
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
  require_match 'PR \[#43\]' "$DOC" "merged PR"
  require_match '3756b1abc4306add7ab77aa106b3952e6043f1ab' "$DOC" "code merge head"
  require_match 'ce099bbbe7267058bd1fc7e75b160c976d24f9c7' "$DOC" "signed tag object"
  require_match '6d65189a71d2dd0266f18bb8a44f101f760d461ac8682e4c84ad6219c5569df7' \
    "$DOC" "published DMG checksum"
  require_match '6225175233edcfd82ec3d93f9865b46b7ab47b5a3fdf5db623f1a70212ecb16e' \
    "$DOC" "installed executable checksum"
  require_match '주간 sample 2125' "$DOC" "weekly history preserved"
  require_match 'reset-window 기록 12건' "$DOC" "past windows preserved"
  require_match 'Published `v1\.9\.2` DMG \| 있음' "$DOC" "published DMG evidence"
  require_match 'Finder drag-and-drop와 그래프 보존 \| 사용자 설치' "$DOC" \
    "install and graph preserve evidence"
  require_match '마지막 커밋에 맞춥니다' "$DOC" "tag will follow last commit"
  require_absent_match 'Published `v1\.9\.2` DMG \| 없음' "$DOC" \
    "stale unpublished DMG"

  require_match 'Would preserve usage history file:' "$UNINSTALL" \
    "uninstall preserves weekly history"
  reject_match_uninstall_wipe

  require_match 'V192ReleaseReadiness\.md' "$README" "README release document link"
  require_match 'V192ReleaseReadiness\.md' "$ROADMAP" "ROADMAP release document link"
  require_match 'releases/tag/v1\.9\.2' "$README" "README still links published v1.9.2"
  require_match '현재 잔여 사용량' "$README" "README remaining amount copy"
  require_match '% 표기' "$README" "README percent sign copy"
  require_match 'GitHub Release publish·Finder 재설치·그래프 보존 완료' "$ROADMAP" \
    "ROADMAP published status"
  require_match '그래프 history를 남겨' "$ROADMAP" "ROADMAP history preserve"
  require_match 'published `v1\.9\.2`' "$QUALITY" "QualityAndRelease published"
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
