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

  require_match '^상태: v1\.9\.0 GitHub Release publish' "$DOC" "published release status"
  require_match 'GUI·live Grok billing·Finder drag 관찰 미수행' "$DOC" \
    "unfinished smoke status"
  require_match '미수행' "$DOC" "honest unfinished marker"
  require_match 'MACDOG_APP_VERSION=1\.9\.0 \./script/check\.sh --no-run' "$DOC" \
    "versioned check gate"
  require_match 'verify_v190_selected_provider_contract\.sh --self-test' "$DOC" \
    "v1.9 product gate"
  require_match 'verify_v180_selected_provider_contract\.sh --self-test' "$DOC" \
    "preserved v1.8 product gate"
  require_match 'published GitHub Release는 \[v1\.9\.0\]' "$DOC" "published release is v1.9.0"
  require_match 'b7072003830798bb1603768c4efb0b41409100f6' "$DOC" "published release head"
  require_match 'd5e29a931f589746eb0b584fdf1ae587e0d951a0' "$DOC" "signed tag object"
  require_match '32615383862' "$DOC" "release candidate run"
  require_match '32615634996' "$DOC" "draft release run"
  require_match '375106008' "$DOC" "published release id"
  require_match '471e10a976cafd469a445af0391e21804cec43bb64f595508f2988935af87011' \
    "$DOC" "published DMG checksum"
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
  require_match 'Published `v1\.9\.0` DMG \| 있음' "$DOC" "published DMG evidence"
  require_match 'GitHub Latest `v1\.9\.0`' "$DOC" "github latest release"
  require_match '2e4ba860c1f91e228d5fd54ab7ad1ce5f4680c692fe8caf1290ff9f784cee9b6' \
    "$DOC" "installed executable checksum"
  require_match 'cleanup / final-state \| 통과' "$DOC" "final-state evidence"
  require_match 'gh release edit v1\.9\.0 --latest' "$DOC" "latest release correction"
  require_match '설치는 사용자가 직접 검수' "$DOC" "user-owned UI review"
  require_match '`Stable Release` workflow' "$DOC" "stable workflow scope"
  require_match '승인되지 않았으므로 실행하지 않습니다' "$DOC" "stable workflow exclusion"
  require_absent_match '실제 Grok live smoke \| 통과' "$DOC" "false live completion"
  require_absent_match 'Finder drag-and-drop와 GUI smoke \| 통과' "$DOC" \
    "false GUI completion"
  require_absent_match '`v1\.9\.0` tag와 published DMG는 없습니다' "$DOC" \
    "stale unpublished v1.9.0 claim"

  require_match 'V190ReleaseReadiness\.md' "$README" "README release document link"
  require_match 'V190ReleaseReadiness\.md' "$ROADMAP" "ROADMAP release document link"
  require_match 'published GitHub Release는 \[v1\.9\.0\]' "$DOC" "doc published release"
  require_match 'MacDog-1\.9\.0\.dmg' "$DOC" "doc published installer"
  require_match 'b7072003830798bb1603768c4efb0b41409100f6' "$README" \
    "README v1.9.0 release head"
  require_match 'v1\.9\.0.*미수행' "$ROADMAP" "ROADMAP unfinished smoke"
  require_match 'GUI·live·Finder drag 관찰 미수행' "$PRODUCT_DOC" \
    "product honest smoke status"
  require_match 'GitHub Latest `v1\.9\.0`' "$DOC" "doc github latest"
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
