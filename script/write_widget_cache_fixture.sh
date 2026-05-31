#!/usr/bin/env bash
set -euo pipefail

STATE="updated"
CACHE_PATH=""
USE_SHARED_CACHE=0
DRY_RUN=0
SELF_TEST=0
APP_GROUP_ID="group.com.dhseo.macdog.MacDog"
SENSITIVE_PATTERN='access[_-]?token|refresh[_-]?token|session[_-]?id|id[_-]?token|auth[_-]?token|api[_-]?key|client[_-]?secret|authorization|cookie|bearer[[:space:]]+'

usage() {
  cat <<USAGE
usage: $0 --state updated|stale|error (--cache-path PATH|--shared-cache) [--dry-run]
       $0 --self-test

Write a synthetic WidgetKit usage cache snapshot for manual widget UI checks.
This does not read Codex auth files, call Codex app-server, launch apps, or
change system settings.

Options:
  --state STATE       Fixture state: updated, stale, or error.
  --cache-path PATH   Write the fixture to PATH.
  --shared-cache      Write to the MacDog WidgetKit shared cache fallback path.
  --dry-run           Print the target path and fixture state without writing.
  --self-test         Write fixtures to a temporary directory and validate JSON.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

shared_cache_path() {
  printf '%s\n' "$HOME/Library/Group Containers/$APP_GROUP_ID/usage.json"
}

write_fixture() {
  local state="$1"
  local cache_path="$2"
  local dry_run="$3"

  case "$state" in
    updated|stale|error) ;;
    *) die "--state requires updated, stale, or error" ;;
  esac

  if [[ "$dry_run" == "1" ]]; then
    echo "widget-cache-fixture:dry-run state=$state path=$cache_path"
    return 0
  fi

  /usr/bin/ruby -rjson -rfileutils -e '
    state = ARGV.fetch(0)
    path = ARGV.fetch(1)
    now = Time.now.to_i
    cached_at = state == "stale" ? now - 720 : now
    stale_after = state == "stale" ? 60 : 360

    five_hour_used = 24.0
    weekly_used = state == "error" ? 91.0 : 82.0
    credits = { "hasCredits" => false, "unlimited" => false, "balance" => "0" }

    five_hour = {
      "kind" => "fiveHour",
      "usedPercent" => five_hour_used,
      "remainingPercent" => 100.0 - five_hour_used,
      "windowDurationMins" => 300,
      "resetsAt" => now + 7_200
    }
    weekly = {
      "kind" => "weekly",
      "usedPercent" => weekly_used,
      "remainingPercent" => 100.0 - weekly_used,
      "windowDurationMins" => 10_080,
      "resetsAt" => now + 172_800
    }
    limit = {
      "limitId" => "codex",
      "limitName" => nil,
      "primary" => five_hour,
      "secondary" => weekly,
      "credits" => credits,
      "planType" => "pro",
      "rateLimitReachedType" => nil
    }
    report = {
      "generatedAt" => cached_at,
      "source" => "manual-widget-fixture",
      "planType" => "pro",
      "credits" => credits,
      "rateLimitReachedType" => nil,
      "limits" => { "codex" => limit }
    }
    snapshot = {
      "schemaVersion" => 1,
      "cachedAt" => cached_at,
      "staleAfterSeconds" => stale_after,
      "report" => report,
      "error" => state == "error" ? {
        "message" => "manual widget fixture error",
        "recordedAt" => now
      } : nil
    }

    directory = File.dirname(path)
    FileUtils.mkdir_p(directory)
    temp_path = "#{path}.tmp.#{$$}"
    File.write(temp_path, JSON.pretty_generate(snapshot) + "\n")
    File.rename(temp_path, path)
  ' "$state" "$cache_path"

  if /usr/bin/grep -Eiq "$SENSITIVE_PATTERN" "$cache_path"; then
    die "sensitive cache/session material pattern found in fixture: $cache_path"
  fi

  echo "widget-cache-fixture:wrote state=$state path=$cache_path"
}

assert_fixture() {
  local path="$1"
  local state="$2"
  /usr/bin/ruby -rjson -e '
    state = ARGV.fetch(0)
    path = ARGV.fetch(1)
    object = JSON.parse(File.read(path))
    raise "schema mismatch" unless object.fetch("schemaVersion") == 1
    raise "missing codex limit" unless object.dig("report", "limits", "codex")
    error = object["error"]
    case state
    when "updated"
      raise "updated fixture has error" unless error.nil?
      raise "updated fixture should not be stale by construction" unless object.fetch("staleAfterSeconds") == 360
    when "stale"
      raise "stale fixture has error" unless error.nil?
      raise "stale fixture stale window mismatch" unless object.fetch("staleAfterSeconds") == 60
      raise "stale fixture cachedAt is not old enough" unless Time.now.to_i - object.fetch("cachedAt") > 60
    when "error"
      raise "error fixture missing error" unless error && error.fetch("message").include?("manual widget fixture error")
    end
  ' "$state" "$path"
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-widget-fixture.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  for state in updated stale error; do
    local path="$temp_dir/$state/usage.json"
    write_fixture "$state" "$path" 0 >/dev/null
    assert_fixture "$path" "$state"
  done

  echo "Widget cache fixture writer self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state)
      shift
      [[ $# -gt 0 ]] || die "--state requires a value"
      STATE="$1"
      ;;
    --cache-path)
      shift
      [[ $# -gt 0 ]] || die "--cache-path requires a path"
      CACHE_PATH="$1"
      ;;
    --shared-cache) USE_SHARED_CACHE=1 ;;
    --dry-run) DRY_RUN=1 ;;
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

if [[ -n "$CACHE_PATH" && "$USE_SHARED_CACHE" == "1" ]]; then
  die "choose either --cache-path or --shared-cache, not both"
fi

if [[ "$USE_SHARED_CACHE" == "1" ]]; then
  CACHE_PATH="$(shared_cache_path)"
fi

[[ -n "$CACHE_PATH" ]] || die "provide --cache-path PATH or --shared-cache"
write_fixture "$STATE" "$CACHE_PATH" "$DRY_RUN"
