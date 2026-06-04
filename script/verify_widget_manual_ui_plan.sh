#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOW_STALE_INSTALLED=0
SKIP_PREFLIGHT=0
SELF_TEST=0
APP_GROUP_ID="group.com.dhseo.macdog.MacDog"

usage() {
  cat <<USAGE
usage: $0 [--allow-stale-installed] [--skip-preflight] [--self-test]

Print the optional WidgetKit manual UI verification plan.
Default mode runs read-only prerequisites, prints dry-run fixture targets, and
then prints the human UI checklist. It does not launch apps, install anything,
write shared widget cache, change SleepDisabled, codesign, notarize, or push.

Options:
  --allow-stale-installed  Let prerequisite output warn instead of failing when
                           the installed app differs from dist/MacDog.app.
  --skip-preflight         Print only the plan and fixture dry-runs.
  --self-test              Validate this plan script without touching live cache.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_text() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if /usr/bin/grep -Eq -- "$pattern" "$file"; then
    return 0
  fi

  die "self-test missing plan text: $description"
}

shared_cache_path() {
  printf '%s\n' "$HOME/Library/Group Containers/$APP_GROUP_ID/usage.json"
}

run_preflight() {
  echo "==> Running read-only manual UI prerequisites"
  if [[ "$ALLOW_STALE_INSTALLED" == "1" ]]; then
    ./script/verify_manual_ui_prerequisites.sh --allow-stale-installed --with-widget
  else
    ./script/verify_manual_ui_prerequisites.sh --with-widget
  fi

  echo "==> Checking WidgetKit App Group signing readiness"
  local signing_output
  signing_output="$(./script/verify_widget_app_group_signing.sh --allow-blocked)"
  printf '%s\n' "$signing_output"
  if /usr/bin/grep -q '^widget-signing:blocked$' <<<"$signing_output"; then
    local reason
    reason="$(/usr/bin/awk -F ':' '$1 == "widget-signing-reason" { print substr($0, index($0, ":") + 1); exit }' <<<"$signing_output")"
    die "$reason"
  fi
}

print_fixture_dry_runs() {
  echo "==> Widget shared cache fixture dry-runs"
  echo "Target shared cache: $(shared_cache_path)"
  for state in updated stale error; do
    ./script/write_widget_cache_fixture.sh --state "$state" --shared-cache --dry-run
  done
}

print_plan() {
  cat <<PLAN
==> WidgetKit manual UI checklist
Scope: optional WidgetKit build, widget gallery addition, widget click deep link, stale/error presentation.

Preflight evidence:
- Run: ./script/verify_widget_manual_ui_plan.sh
- Confirm the read-only prerequisite gate passes before any GUI clicking.
- Confirm MacDog was built and installed with --with-widget; default release builds intentionally omit WidgetKit.
- If it reports an installed app freshness mismatch, reinstall MacDog first, then rerun the preflight.
- If it reports ad-hoc Widget extension signing, build/install a development or distribution signed app with a provisioning profile that grants group.com.dhseo.macdog.MacDog before judging shared cache UI.

Manual UI sequence:
1. Open the macOS widget gallery and add the MacDog widget.
2. Add both the small and medium MacDogStatusWidget families when available.
3. Confirm the widget shows Codex usage from the shared cache and does not show a blank or unrelated fallback.
4. Click the widget and confirm macdog://open brings MacDog forward and opens the usage popover.
5. Stage the updated fixture only during manual UI verification:
   ./script/write_widget_cache_fixture.sh --state updated --shared-cache
6. Refresh the widget surface or wait for WidgetKit to reload, then confirm the widget says 갱신됨.
7. Stage the stale fixture only during manual UI verification:
   ./script/write_widget_cache_fixture.sh --state stale --shared-cache
8. Refresh the widget surface or wait for WidgetKit to reload, then confirm the widget says 오래된 캐시.
9. Stage the error fixture only during manual UI verification:
   ./script/write_widget_cache_fixture.sh --state error --shared-cache
10. Refresh the widget surface or wait for WidgetKit to reload, then confirm the widget says 오류: manual widget fixture error.

Completion evidence to record:
- Installed app freshness command/result.
- Widget family checked: small, medium, or both.
- For each fixture state: updated, stale, error, record whether the actual macOS widget UI matched the expected copy.
- Deep link result: whether the widget click opened MacDog through macdog://open.
- UI confirmation status must remain 미수행 unless the actual macOS widget surface was observed.

Safety boundary:
- This plan does not complete the manual UI check by itself.
- The fixture commands above write the live shared widget cache only when a user deliberately runs them.
- Do not run signing, notarization, install, LaunchAgent, or GUI automation from this script.
PLAN
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-widget-manual-plan.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local output_file="$temp_dir/plan.txt"
  "$0" --skip-preflight >"$output_file"

  require_text 'WidgetKit manual UI checklist' "$output_file" "plan heading"
  require_text 'optional WidgetKit build' "$output_file" "optional WidgetKit scope"
  require_text 'macOS widget gallery' "$output_file" "widget gallery step"
  require_text 'MacDogStatusWidget' "$output_file" "widget kind"
  require_text 'macdog://open' "$output_file" "deep link step"
  require_text 'ad-hoc Widget extension signing' "$output_file" "App Group signing preflight"
  require_text '--state updated --shared-cache' "$output_file" "updated fixture step"
  require_text '--state stale --shared-cache' "$output_file" "stale fixture step"
  require_text '--state error --shared-cache' "$output_file" "error fixture step"
  require_text 'does not complete the manual UI check by itself' "$output_file" "manual evidence boundary"

  for state in updated stale error; do
    local dry_run_file="$temp_dir/$state.txt"
    ./script/write_widget_cache_fixture.sh --state "$state" --cache-path "$temp_dir/$state/usage.json" --dry-run >"$dry_run_file"
    require_text "widget-cache-fixture:dry-run state=$state" "$dry_run_file" "$state dry-run"
  done

  echo "Widget manual UI plan self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-stale-installed) ALLOW_STALE_INSTALLED=1 ;;
    --skip-preflight) SKIP_PREFLIGHT=1 ;;
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
  run_self_test
  exit 0
fi

if [[ "$SKIP_PREFLIGHT" != "1" ]]; then
  run_preflight
fi

print_fixture_dry_runs
print_plan
