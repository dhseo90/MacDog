#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROADMAP="$ROOT_DIR/ROADMAP.md"
DOC="$ROOT_DIR/Docs/V130NotificationAndTabUIPolish.md"
SCRIPTS_DOC="$ROOT_DIR/Docs/Scripts.md"
SELF_TEST=0

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify the v1.3.0 local-notification planning boundary. This script is
read-only and does not open GUI apps, request notification permission, install
LaunchAgents, run long tests, call live Codex app-server, or push.

Options:
  --self-test  Run the same read-only boundary checks.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

require_executable() {
  [[ -x "$1" ]] || die "missing required executable: $1"
}

require_text() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  /usr/bin/grep -Eq -- "$pattern" "$file" || die "missing $description in $file"
}

require_absent() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if /usr/bin/grep -En -- "$pattern" "$file" >/tmp/macdog-v130-boundary-grep.txt; then
    echo "error: forbidden v1.3.0 planning term found: $description" >&2
    /bin/cat /tmp/macdog-v130-boundary-grep.txt >&2
    /bin/rm -f /tmp/macdog-v130-boundary-grep.txt
    exit 1
  fi

  /bin/rm -f /tmp/macdog-v130-boundary-grep.txt
}

extract_v130_roadmap_section() {
  local output="$1"
  /usr/bin/awk '
    /^## v1\.3\.0 / { capture = 1; print; next }
    capture && /^## / { exit }
    capture { print }
  ' "$ROADMAP" >"$output"
}

verify_local_notification_boundary() {
  require_file "$ROADMAP"
  require_file "$DOC"
  require_file "$SCRIPTS_DOC"
  require_executable "$ROOT_DIR/script/verify_v130_local_notification_boundary.sh"

  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-v130-boundary.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local roadmap_section="$temp_dir/roadmap-v130.md"
  extract_v130_roadmap_section "$roadmap_section"
  [[ -s "$roadmap_section" ]] || die "missing v1.3.0 section in ROADMAP.md"

  local scoped_files=("$roadmap_section" "$DOC")
  local file
  for file in "${scoped_files[@]}"; do
    require_text 'v1\.3\.0.*알림|알림.*v1\.3\.0' "$file" "v1.3.0 notification scope"
    require_text 'Apple Developer 계정.*필요.*없|계정 없이.*로컬 알림|로컬 알림.*계정 없이' "$file" "Apple Developer account not required boundary"
    require_text 'UserNotifications.*로컬 알림|로컬 알림.*UserNotifications' "$file" "UserNotifications local notification boundary"
    require_text '설정 탭.*켜.*macOS 알림 권한|macOS 알림 권한.*설정 탭.*켜' "$file" "user opt-in and macOS permission boundary"
    require_text '기본.*꺼짐|꺼짐.*기본' "$file" "notifications disabled by default"
    require_text '테스트 알림 버튼.*넣지 않습니다|테스트 알림 버튼.*포함하지 않음' "$file" "test notification button excluded"
    require_text 'JSON.*cache.*app-server.*변경하지 않습니다|JSON/cache/app-server.*변경하지 않습니다' "$file" "usage JSON cache app-server contract unchanged"
    require_text '기능명.*나열하지 않습니다|세부.*기능명.*나열하지 않습니다' "$file" "developer-account feature names not listed"

    require_absent 'APNs|Apple Push Notification service|Push Notifications|push token|App ID|provisioning profile|App Group|WidgetKit|Developer ID|notarization|App Store Connect|Stable Release' "$file" "$file"
  done

  require_text 'verify_v130_local_notification_boundary\.sh --self-test' "$SCRIPTS_DOC" "Scripts doc reference"

  echo "v1.3.0 local notification boundary ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test) SELF_TEST=1 ;;
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

if [[ "$SELF_TEST" == "1" ]]; then
  verify_local_notification_boundary
  exit 0
fi

verify_local_notification_boundary
