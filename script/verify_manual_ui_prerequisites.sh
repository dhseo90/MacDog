#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOW_STALE_INSTALLED=0
WITH_WIDGET=0

usage() {
  cat <<USAGE
usage: $0 [--allow-stale-installed] [--with-widget]

Read-only preflight before manual UI clicking.
Default mode fails when the installed app does not match dist/MacDog.app.
This script does not install, uninstall, launch the app, or change SleepDisabled.
Widget checks are skipped by default because WidgetKit is opt-in. With
--with-widget, widget cache fixture checks run in self-test mode and do not
touch live cache.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-stale-installed) ALLOW_STALE_INSTALLED=1 ;;
    --with-widget) WITH_WIDGET=1 ;;
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

echo "==> Verifying manual UI prerequisites"
echo "This preflight is read-only: no app launch, no install, no pmset changes."

echo "==> Checking generated app bundle"
./script/verify_app_bundle.sh >/dev/null

echo "==> Checking character asset linkage"
./script/verify_character_profile.sh >/dev/null

echo "==> Checking app privacy boundaries"
./script/verify_app_privacy_boundaries.sh >/dev/null

if [[ "$WITH_WIDGET" == "1" ]]; then
  echo "==> Checking opt-in WidgetKit source readiness"
  ./script/verify_widget_readiness.sh --expect-bundled >/dev/null

  echo "==> Checking WidgetKit cache fixture writer"
  ./script/write_widget_cache_fixture.sh --self-test >/dev/null
else
  echo "==> Skipping WidgetKit preflight"
  echo "WidgetKit is opt-in and not part of the default manual UI gate."
fi

echo "==> Checking helper UI/install preflight"
./script/verify_privileged_helper_preflight.sh >/dev/null

echo "==> Checking Shortcuts fallback availability without changes"
./script/verify_shortcuts_charge_limit.sh --allow-unavailable >/dev/null

echo "==> Checking installed app freshness"
if [[ "$ALLOW_STALE_INSTALLED" == "1" ]]; then
  install_state="$(./script/verify_install_state.sh --report)"
  printf '%s\n' "$install_state"
  if printf '%s\n' "$install_state" | /usr/bin/grep -q '^app-freshness:differs-from-dist '; then
    echo "manual-ui-prerequisites:warning installed app differs from dist/MacDog.app"
    ./script/verify_install_state.sh --explain-current-dist
    echo "Manual UI clicking must reinstall MacDog before verification."
  fi
else
  ./script/verify_install_state.sh --expect-current-dist
fi

echo "Manual UI prerequisites ok"
