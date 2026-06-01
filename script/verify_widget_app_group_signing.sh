#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH=""
INSTALL_REPORT=""
SIGNING_REPORT=""
ALLOW_BLOCKED=0
SELF_TEST=0
APP_GROUP_ID="group.com.dhseo.macdog.MacDog"

usage() {
  cat <<USAGE
usage: $0 [--app PATH|--install-report PATH] [--allow-blocked]
       $0 --signing-report PATH [--allow-blocked]
       $0 --self-test

Classify whether the installed MacDog Widget extension is signed in a way that
can exercise App Group shared cache UI. This script is read-only: it does not
open GUI apps, install anything, codesign, notarize, staple, run Gatekeeper
assessment, or push.

Options:
  --app PATH              MacDog.app path to inspect.
  --install-report PATH   verify_install_state.sh --report output to parse.
  --signing-report PATH   codesign -dvvv --entitlements - output to classify.
                        This checks only signature text; installed app checks
                        also validate the embedded provisioning profile.
  --allow-blocked         Return success while reporting widget-signing:blocked.
  --self-test             Validate ready, missing entitlement, and ad-hoc cases.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

active_app_from_report() {
  local report="$1"
  /usr/bin/awk -F ':' '$1 == "active-app" { print substr($0, index($0, ":") + 1); exit }' "$report"
}

classify_signing_text() {
  local signing="$1"
  local quiet_ready="${2:-0}"
  if ! /usr/bin/grep -q 'com.apple.security.application-groups' <<<"$signing"; then
    echo "widget-signing:blocked"
    echo "widget-signing-reason:Widget extension lacks App Group entitlement"
    return 1
  fi
  if ! /usr/bin/grep -q "$APP_GROUP_ID" <<<"$signing"; then
    echo "widget-signing:blocked"
    echo "widget-signing-reason:Widget extension App Group entitlement does not include $APP_GROUP_ID"
    return 1
  fi
  if /usr/bin/grep -q 'Signature=adhoc' <<<"$signing" || /usr/bin/grep -q 'TeamIdentifier=not set' <<<"$signing"; then
    echo "widget-signing:blocked"
    echo "widget-signing-reason:Widget extension is ad-hoc signed; App Group UI verification requires a development/distribution signed build with provisioning"
    return 1
  fi

  if [[ "$quiet_ready" != "1" ]]; then
    echo "widget-signing:ready"
    echo "widget-signing-reason:Widget extension has App Group entitlement and non-ad-hoc team signature"
  fi
  return 0
}

decode_profile() {
  local profile="$1"
  /usr/bin/openssl smime -inform DER -verify -noverify -in "$profile" 2>/dev/null || true
}

profile_has_app_group() {
  local profile_text="$1"
  /usr/bin/grep -q 'com.apple.security.application-groups' <<<"$profile_text" &&
    /usr/bin/grep -q "$APP_GROUP_ID" <<<"$profile_text"
}

classify_installed_app() {
  local app_path="$1"
  [[ -n "$app_path" ]] || die "installed app path unavailable"

  local appex_path="$app_path/Contents/PlugIns/MacDogWidgetExtension.appex"
  if [[ ! -d "$appex_path" ]]; then
    echo "widget-signing:blocked"
    echo "widget-signing-reason:installed widget extension missing: $appex_path"
    return 1
  fi

  local signing
  signing="$(/usr/bin/codesign -dvvv --entitlements - "$appex_path" 2>&1 || true)"
  if ! classify_signing_text "$signing" 1; then
    return 1
  fi

  local profile="$appex_path/Contents/embedded.provisionprofile"
  if [[ ! -f "$profile" ]]; then
    echo "widget-signing:blocked"
    echo "widget-signing-reason:Widget extension is missing embedded provisioning profile with $APP_GROUP_ID"
    return 1
  fi

  local profile_text
  profile_text="$(decode_profile "$profile")"
  if [[ -z "$profile_text" ]]; then
    echo "widget-signing:blocked"
    echo "widget-signing-reason:Widget extension embedded provisioning profile could not be decoded"
    return 1
  fi
  if ! profile_has_app_group "$profile_text"; then
    echo "widget-signing:blocked"
    echo "widget-signing-reason:Widget extension embedded provisioning profile does not grant $APP_GROUP_ID"
    return 1
  fi

  echo "widget-signing:ready"
  echo "widget-signing-reason:Widget extension has App Group entitlement, non-ad-hoc team signature, and embedded provisioning profile grants $APP_GROUP_ID"
  return 0
}

run_check() {
  local status=0
  if [[ -n "$SIGNING_REPORT" ]]; then
    require_file "$SIGNING_REPORT"
    classify_signing_text "$(/bin/cat "$SIGNING_REPORT")" || status=$?
  else
    local app_path="$APP_PATH"
    if [[ -z "$app_path" ]]; then
      local temp_report=""
      if [[ -n "$INSTALL_REPORT" ]]; then
        require_file "$INSTALL_REPORT"
        temp_report="$INSTALL_REPORT"
      else
        temp_report="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-widget-signing-install.XXXXXX")"
        "$ROOT_DIR/script/verify_install_state.sh" --report >"$temp_report"
      fi
      app_path="$(active_app_from_report "$temp_report")"
    fi
    classify_installed_app "$app_path" || status=$?
  fi

  if [[ "$status" -ne 0 && "$ALLOW_BLOCKED" == "1" ]]; then
    return 0
  fi
  return "$status"
}

require_output() {
  local pattern="$1"
  local file="$2"
  local description="$3"
  /usr/bin/grep -Eq -- "$pattern" "$file" || die "self-test missing $description"
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-widget-signing.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  cat >"$temp_dir/ready.txt" <<READY
Signature size=9000
TeamIdentifier=2N2CUNAZ3S
<key>com.apple.security.application-groups</key>
<array><string>$APP_GROUP_ID</string></array>
READY
  cat >"$temp_dir/adhoc.txt" <<ADHOC
Signature=adhoc
TeamIdentifier=not set
<key>com.apple.security.application-groups</key>
<array><string>$APP_GROUP_ID</string></array>
ADHOC
  cat >"$temp_dir/missing.txt" <<MISSING
Signature size=9000
TeamIdentifier=2N2CUNAZ3S
MISSING

  "$0" --signing-report "$temp_dir/ready.txt" >"$temp_dir/ready.out"
  require_output '^widget-signing:ready$' "$temp_dir/ready.out" "ready state"

  "$0" --signing-report "$temp_dir/adhoc.txt" --allow-blocked >"$temp_dir/adhoc.out"
  require_output '^widget-signing:blocked$' "$temp_dir/adhoc.out" "ad-hoc blocked state"
  require_output 'ad-hoc signed' "$temp_dir/adhoc.out" "ad-hoc reason"

  "$0" --signing-report "$temp_dir/missing.txt" --allow-blocked >"$temp_dir/missing.out"
  require_output '^widget-signing:blocked$' "$temp_dir/missing.out" "missing entitlement blocked state"
  require_output 'lacks App Group entitlement' "$temp_dir/missing.out" "missing entitlement reason"

  cat >"$temp_dir/profile-ready.txt" <<PROFILE_READY
<key>com.apple.security.application-groups</key>
<array><string>$APP_GROUP_ID</string></array>
PROFILE_READY
  cat >"$temp_dir/profile-missing.txt" <<PROFILE_MISSING
<key>com.apple.developer.team-identifier</key>
<string>2N2CUNAZ3S</string>
PROFILE_MISSING
  profile_has_app_group "$(/bin/cat "$temp_dir/profile-ready.txt")" ||
    die "profile App Group check unexpectedly rejected ready profile text"
  if profile_has_app_group "$(/bin/cat "$temp_dir/profile-missing.txt")"; then
    die "profile App Group check unexpectedly accepted missing profile text"
  fi

  if "$0" --signing-report "$temp_dir/adhoc.txt" >/dev/null 2>&1; then
    die "ad-hoc signing unexpectedly passed without --allow-blocked"
  fi

  echo "Widget App Group signing self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      shift
      [[ $# -gt 0 ]] || die "--app requires a path"
      APP_PATH="$1"
      ;;
    --install-report)
      shift
      [[ $# -gt 0 ]] || die "--install-report requires a path"
      INSTALL_REPORT="$1"
      ;;
    --signing-report)
      shift
      [[ $# -gt 0 ]] || die "--signing-report requires a path"
      SIGNING_REPORT="$1"
      ;;
    --allow-blocked) ALLOW_BLOCKED=1 ;;
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

if [[ "$SELF_TEST" == "1" ]]; then
  run_self_test
  exit 0
fi

run_check
